# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

既存のレイヤードアーキテクチャに「目標値」の縦の線を 1 本足す。ダッシュボードは目標値を**読まない**(読むのは #23)。

```
presentation/goals/goal_settings_screen.dart ─┐
presentation/goals/goals_controller.dart ─────┼→ data/goal_repository.dart(抽象)
presentation/providers.dart(DI の合成)────────┘        ↑ 実装
                                         data/shared_preferences_goal_repository.dart → shared_preferences
domain/models/goals.dart / domain/goal_input.dart(純 Dart。入力の解析と検証)
```

依存の向きは `architecture.md` の規則どおり(presentation → data は抽象のみ。実装クラスの参照は `providers.dart` だけ)。

## 決定事項(Issue の「着手時に design.md で決める」)

| 項目 | 決定 |
|---|---|
| 歩数の入力範囲 | **1,000〜100,000 歩**(整数。両端を含む) |
| 睡眠時間の入力範囲 | **3 時間 0 分〜12 時間 0 分**(合計分で 180〜720。両端を含む) |
| 睡眠時間の入力 UI | 「時間」「分」の 2 つの数値入力欄を横に並べる |
| 未設定の扱い | 入力欄を空欄にして保存すると「目標なし」(保存済みの値を削除) |
| ダッシュボードからの導線 | AppBar の `actions` に `IconButton(Icons.flag_outlined, tooltip: '目標の設定')`。ダッシュボードの全状態(読み込み中を含む)で常に表示 |
| `shared_preferences` の API | `SharedPreferencesAsync`(キャッシュを持たない非同期 API。公式が新規コードに推奨。Android は DataStore で保存) |

## コンポーネント設計

### 1. `lib/domain/models/goals.dart`(新規)

```dart
/// ユーザーが設定した目標値(機能設計書「Goals」)。null は目標なし。
class Goals {
  const Goals({this.steps, this.sleepMinutes});

  /// 1 日の歩数の目標。null は目標なし。
  final int? steps;

  /// 1 日の睡眠時間の目標(分)。null は目標なし。
  final int? sleepMinutes;

  @override
  bool operator ==(Object other) =>
      other is Goals && other.steps == steps && other.sleepMinutes == sleepMinutes;

  @override
  int get hashCode => Object.hash(steps, sleepMinutes);
}
```

- `toString()` は実装しない(`check-privacy.sh` が `lib/domain/` の `toString()` を禁止している)

### 2. `lib/domain/goal_input.dart`(新規。純関数)

範囲の定数と、入力文字列の解析・検証。UI 文言(エラーメッセージ)もここで返す(`formatters.dart` と同じく表示用の文字列をドメインで決める既存方針に合わせる)。

```dart
/// 歩数の目標の下限・上限(両端を含む)。
const minStepsGoal = 1000;
const maxStepsGoal = 100000;

/// 睡眠時間の目標の下限・上限(分。両端を含む)。
const minSleepGoalMinutes = 180;
const maxSleepGoalMinutes = 720;

/// 入力の正規化: 前後の空白を除き、全角数字 `０-９` を半角に変換し、半角 `,` と全角 `，` を取り除く。
String _normalize(String input);

/// 歩数の入力を解析する。
/// - 正規化後が空 → (value: null, error: null)(目標なし)
/// - 正規化後が `^[0-9]+$` に一致しない → (value: null, error: '数字で入力してください')
/// - int.parse した値が範囲外 → (value: null, error: '1,000〜100,000 歩の範囲で入力してください')
///   (桁数が多すぎて int.tryParse が null になる場合も範囲外として扱う)
/// - それ以外 → (value: 値, error: null)
({int? value, String? error}) parseStepsGoal(String input);

/// 睡眠時間の入力(時間・分)を解析する。戻り値の minutes は合計分。
/// 判定順(最初に当たったものだけを返す。エラーが 1 つでもあれば minutes は null):
/// 1. 時間・分とも正規化後が空 → (minutes: null, hoursError: null, minutesError: null)(目標なし)
/// 2. 時間が空でなく `^[0-9]+$` に一致しない → hoursError: '数字で入力してください'
///    分が空でなく `^[0-9]+$` に一致しない → minutesError: '数字で入力してください'
///    (2 は時間・分の両方を判定し、両方のエラーを同時に返してよい)
/// 3. 時間が空で分だけ入力 → hoursError: '時間を入力してください'
/// 4. 分(空なら 0)が 60 以上 → minutesError: '0〜59 分で入力してください'
/// 5. 合計分 = 時間 * 60 + 分 が 180〜720 の範囲外 → hoursError: '3〜12 時間の範囲で入力してください'
///    (時間の桁数が多すぎて int.tryParse が null になる場合も 5 と同じエラー)
/// 6. それ以外 → (minutes: 合計分, hoursError: null, minutesError: null)
({int? minutes, String? hoursError, String? minutesError}) parseSleepGoal(
  String hours,
  String minutes,
);
```

- 例: `parseSleepGoal('7', '')` → 420 / `parseSleepGoal('7', '30')` → 450 / `parseSleepGoal('12', '1')` → 範囲外 / `parseSleepGoal('', '30')` → 時間を入力してください / `parseStepsGoal('８，０００')` → 8000

### 3. `lib/data/goal_repository.dart`(新規。抽象)

```dart
import 'package:health_pixcel/domain/models/goals.dart';

/// 目標値の保存先(データ層の抽象)。上位層はこの型にだけ依存する。
abstract interface class GoalRepository {
  /// 保存済みの目標値。未保存の項目は null。失敗時は [GoalStorageException] を投げる。
  Future<Goals> load();

  /// 目標値を保存する。null の項目は保存済みの値を削除する。
  /// 失敗時は [GoalStorageException] を投げる。
  Future<void> save(Goals goals);
}

/// 目標値の読み書きの失敗。元の例外の内容は持たない。
class GoalStorageException implements Exception {
  const GoalStorageException();
}
```

### 4. `lib/data/shared_preferences_goal_repository.dart`(新規。Android 実装)

- **`package:shared_preferences/` を import するのはこのファイルの 1 行だけ。** 行末に `// privacy-check: allow(目標値の保存。健康データは保存しない)` を付ける(`dart format` 後も同じ行に残ること。import 文は 80 桁を超えても改行されない)
  ```dart
  import 'package:shared_preferences/shared_preferences.dart'; // privacy-check: allow(目標値の保存。健康データは保存しない)
  ```
- キー: `goal.steps`(int)/ `goal.sleep_minutes`(int)。ファイル内の `const` で定義する
- `SharedPreferencesAsync` は**最初の使用時に生成する**(`SharedPreferencesAsync? _prefs;` + `SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();`)。コンストラクタで生成しない(テストで platform を差し替える前にプロバイダーが生成されても落ちないように)
- `load()`:
  - `getInt` で 2 つ読む(`Future.wait` で並行でよい)
  - 読んだ値が範囲外(`minStepsGoal`〜`maxStepsGoal` / `minSleepGoalMinutes`〜`maxSleepGoalMinutes` の外)なら null として扱う
  - 例外(`Exception`)は捕捉して `const GoalStorageException()` を投げる(`on Exception catch (_)`)。元の例外は捨てる
- `save(goals)`: 各項目が null なら `remove(key)`、値があれば `setInt(key, value)`。例外の扱いは `load()` と同じ
- 範囲の検証は `save` では行わない(呼び出し側が `goal_input.dart` で検証済み)
- `lib/domain/goal_input.dart` の定数を import してよい(data → domain は許可)

### 5. `lib/presentation/providers.dart`(変更)

```dart
/// 目標値の保存先。テストでフェイクに差し替える。
final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => SharedPreferencesGoalRepository(),
);
```

### 6. `lib/presentation/goals/goals_controller.dart`(新規)

```dart
/// 目標値の状態。build() で読み込み、save() で保存して状態を置き換える。
final goalsControllerProvider = AsyncNotifierProvider<GoalsController, Goals>(
  GoalsController.new,
);

class GoalsController extends AsyncNotifier<Goals> {
  @override
  Future<Goals> build() async {
    try {
      return await ref.read(goalRepositoryProvider).load();
    } on GoalStorageException {
      return const Goals(); // 読めないときは目標なしとして扱う(画面は入力できる状態にする)
    }
  }

  /// 保存する。成功なら true、GoalStorageException なら false(状態は変えない)。
  Future<bool> save(Goals goals) async {
    try {
      await ref.read(goalRepositoryProvider).save(goals);
    } on GoalStorageException {
      return false;
    }
    state = AsyncData(goals);
    return true;
  }
}
```

- 既存の `dashboardControllerProvider` と同じく `AsyncNotifierProvider`(autoDispose にしない)。#23 がダッシュボードから同じプロバイダーを読む前提

### 7. `lib/presentation/goals/goal_settings_screen.dart`(新規)

`ConsumerStatefulWidget`。`TextEditingController` 3 つ(歩数・時間・分)と、エラー文言 3 つ(`String?`)を State に持つ。`Form` は使わず、`TextField` の `InputDecoration.errorText` にエラーを渡す。

**レイアウト**(`Scaffold`):
- `AppBar(title: const Text('目標の設定'))`
- 読み込み中(`ref.watch(goalsControllerProvider)` が `isLoading` かつ値なし): `Center(child: CircularProgressIndicator(semanticsLabel: '読み込み中'))`
- 読み込み後: `ListView(padding: const EdgeInsets.all(16), children: [...])`
  1. `Text('歩数', style: textTheme.titleMedium)`、`SizedBox(height: 8)`
  2. 歩数の `TextField`(key: `const Key('stepsGoalField')`)
     - `keyboardType: TextInputType.number`、`textInputAction: TextInputAction.next`
     - `decoration: InputDecoration(labelText: '1 日の歩数', suffixText: '歩', helperText: '1,000〜100,000 歩。空欄にすると目標なし', errorText: _stepsError, border: const OutlineInputBorder())`
  3. `SizedBox(height: 24)`、`Text('睡眠時間', style: textTheme.titleMedium)`、`SizedBox(height: 8)`
  4. `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(時間), SizedBox(width: 12), Expanded(分)])`
     - 時間(key: `const Key('sleepHoursField')`): `labelText: '時間'`、`suffixText: '時間'`、`errorText: _hoursError`、`errorMaxLines: 2`、`OutlineInputBorder`、`keyboardType: TextInputType.number`、`textInputAction: TextInputAction.next`
     - 分(key: `const Key('sleepMinutesField')`): `labelText: '分'`、`suffixText: '分'`、`errorText: _minutesError`、`errorMaxLines: 2`、`OutlineInputBorder`、`keyboardType: TextInputType.number`、`textInputAction: TextInputAction.done`
  5. `SizedBox(height: 8)`、`Text('3〜12 時間。空欄にすると目標なし', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant))`
  6. `SizedBox(height: 32)`、`FilledButton(onPressed: _saving ? null : _save, child: const Text('保存'))`(全幅: `SizedBox(width: double.infinity, child: ...)`)
- 入力欄に `inputFormatters` は付けない(非数値を入力されたときに理由を表示するのが受け入れ条件のため)

**初期値**: 最初に `AsyncData` を受け取ったとき 1 回だけ、コントローラーに値を入れる(`bool _initialized` で管理。以降の再ビルドで上書きしない)。
- 歩数: `goals.steps?.toString() ?? ''`(3 桁区切りなし)
- 睡眠: `sleepMinutes` が null なら時間・分とも `''`、値があれば 時間 = `sleepMinutes ~/ 60` の文字列、分 = `sleepMinutes % 60` の文字列(0 でも `'0'`)
- 初期化は `build()` の中で `ref.watch` した値を見て、`_initialized == false` のときだけ代入する(`setState` は呼ばない。コントローラーの `text` 代入のみ)

**エラーの消去**: 各 `TextField` の `onChanged` で、その欄のエラーが非 null なら `setState` で null にする(睡眠は時間・分どちらを編集しても `_hoursError` と `_minutesError` の両方を消す)。

**保存(`_save`)**:
1. `parseStepsGoal` / `parseSleepGoal` を呼び、3 つのエラーを `setState` で反映する
2. エラーが 1 つでもあれば終了(保存しない)
3. `setState(() => _saving = true)` → `final ok = await ref.read(goalsControllerProvider.notifier).save(Goals(steps: ..., sleepMinutes: ...))` → `if (!mounted) return;` → `setState(() => _saving = false)`
4. `ok == true`: `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目標を保存しました')))` を出してから `Navigator.of(context).pop()`(SnackBar はダッシュボード側の Scaffold に表示される。`ScaffoldMessenger` は MaterialApp に 1 つ)
5. `ok == false`: `SnackBar(content: Text('保存できませんでした'))` を出し、画面に留まる

### 8. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- `AppBar` に `actions: [IconButton(icon: const Icon(Icons.flag_outlined), tooltip: '目標の設定', onPressed: _openGoalSettings)]`
- `void _openGoalSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoalSettingsScreen()));`(既存の `_openRationale` と同じ形)
- 保存後にダッシュボードの再読み込みはしない(#22 のダッシュボードは目標値を表示しない)

### 9. `scripts/check-layer-imports.sh`(変更)

- 既存の「`health_connect_repository.dart` / `platform_channels.dart` は `lib/data/` と `lib/presentation/providers.dart` 以外から import できません」の規則に `shared_preferences_goal_repository` を加える:
  - ラベル: `'health_connect_repository.dart / platform_channels.dart / shared_preferences_goal_repository.dart は lib/data/ と lib/presentation/providers.dart 以外から import できません'`
  - 正規表現の選択肢: `(health_connect_repository|platform_channels|shared_preferences_goal_repository)`
- `scripts/check-privacy.sh` は**変更しない**(「保存」規則は維持し、allow コメントで 1 行だけ除外する)

## データフロー

### 目標を設定する
```
1. ダッシュボードの AppBar の旗アイコン → GoalSettingsScreen を push
2. goalsControllerProvider.build() → GoalRepository.load() → 入力欄に初期値
3. 入力して「保存」→ parseStepsGoal / parseSleepGoal
   - エラーあり → 入力欄の下に理由を表示(保存しない)
   - エラーなし → GoalsController.save() → GoalRepository.save()
4. 成功 → SnackBar「目標を保存しました」+ pop / 失敗 → SnackBar「保存できませんでした」
```

## エラーハンドリング戦略

- データ層: `Exception` を `GoalStorageException`(内容なし)に変換する。ログは出さない(プライバシー規則)
- 読み込み失敗: 目標なしとして画面を表示する(入力して保存し直せる)
- 保存失敗: SnackBar で伝え、入力内容は画面に残す

## テスト戦略

### ユニットテスト
- `test/domain/goal_input_test.dart`(新規)
  - `parseStepsGoal`: 空文字・空白のみ → 目標なし / `'8000'` / `'8,000'` / `'８０００'` / `'８，０００'` → 8000 / `'1000'`・`'100000'`(境界内)/ `'999'`・`'100001'`(範囲外)/ `'abc'`・`'8000.5'`・`'-100'` → 数字で入力 / `'99999999999999999999999'` → 範囲外
  - `parseSleepGoal`: `('', '')` → 目標なし / `('7', '')` → 420 / `('7', '30')` → 450 / `('3', '0')` → 180 / `('12', '0')` → 720 / `('2', '59')` → 範囲外 / `('12', '1')` → 範囲外 / `('', '30')` → 時間を入力 / `('7', '60')` → 0〜59 分 / `('a', 'b')` → 両方に数字で入力 / `('７', '３０')` → 450
- `test/data/shared_preferences_goal_repository_test.dart`(新規)
  - `setUp` で `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();`
  - 未保存 → `Goals()` / 保存 → **新しいインスタンス**で `load` して同じ値(再起動の代わり)/ null で保存すると削除される / 片方だけ保存 / 範囲外の値が保存されていたら null(`InMemorySharedPreferencesAsync.withData({'goal.steps': 5})` で検証)
  - import: `package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart` と `package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart`
- `test/presentation/goals/goals_controller_test.dart`(新規): 読み込み成功 / 読み込み失敗 → `Goals()` / 保存成功で状態が置き換わる / 保存失敗で false・状態不変。`ProviderContainer` で `goalRepositoryProvider` をフェイクに差し替え、`container.listen` で購読しておく(既存の dashboard_controller_test と同じ流儀)

### ウィジェットテスト
- `test/presentation/goals/goal_settings_screen_test.dart`(新規)。`ProviderScope(overrides: [goalRepositoryProvider.overrideWithValue(fake)], retry: (_, _) => null, child: MaterialApp(home: ...))`。pop を確かめるテストは、ホームにボタン付きの土台画面を置いて push する
  - 保存済みの値が入力欄に入る(8000 / 7 / 30)、未保存なら空
  - `'abc'` で保存 → 「数字で入力してください」が表示され、`fake.saveCalls == 0`
  - `'500'` で保存 → 範囲外の文言が表示され、保存されない
  - 分 `'60'` → 「0〜59 分で入力してください」
  - 正しい値で保存 → `fake.saved == Goals(steps: 8000, sleepMinutes: 450)`、SnackBar「目標を保存しました」、画面が閉じる
  - 全部空欄で保存 → `Goals()` で保存される
  - 保存失敗(`fake.saveError = const GoalStorageException()`)→ 「保存できませんでした」、画面に留まる
  - エラー表示後に入力するとエラーが消える
- `test/presentation/dashboard/dashboard_screen_test.dart`(追記): 旗アイコン(tooltip `目標の設定`)をタップすると `GoalSettingsScreen` が表示される(`goalRepositoryProvider` を `FakeGoalRepository` に差し替える)

### フェイク
- `test/fakes/fake_goal_repository.dart`(新規): `Goals stored = const Goals();` / `Exception? loadError;` / `Exception? saveError;` / `Goals? saved;`(最後に保存した値)/ `int saveCalls = 0;`。`load` は `loadError` があれば投げ、なければ `stored`。`save` は `saveCalls++` → `saveError` があれば投げる → `saved = goals; stored = goals;`

## 依存ライブラリ

```yaml
dependencies:
  shared_preferences: ^2.5.6
dev_dependencies:
  shared_preferences_platform_interface: ^2.4.2   # テストの InMemorySharedPreferencesAsync のため
```

- 追加は `flutter pub add shared_preferences:^2.5.6` と `flutter pub add dev:shared_preferences_platform_interface:^2.4.2` で行う
- 司令塔が確認済み(2026-10-11、pub cache の実ソース): `shared_preferences` 2.5.6 の依存は `shared_preferences_{android,foundation,linux,platform_interface,web,windows}` のみ。`shared_preferences_android` 2.4.28 の Gradle 依存は `androidx.datastore:datastore` / `datastore-preferences` / `androidx.preference` のみで、マニフェストに権限なし、通信・解析コードなし。`shared_preferences_platform_interface` の依存は `plugin_platform_interface` のみ
- **Android でビルドされるプラグインの確認**: `flutter pub get` 後の `.flutter-plugins-dependencies`(JSON)の `plugins.android` の `name` 一覧を追加前後で比べる(`jq -r '.plugins.android[].name' .flutter-plugins-dependencies | sort`)。**増えたのが `shared_preferences_android` だけなら続行、それ以外が増えていたら停止して報告する**
- `pubspec.lock` には Linux / Windows 実装の推移的依存(`path_provider_linux` / `path_provider_windows` / `path_provider_platform_interface` / `xdg_directories` / `ffi` / `file` / `platform` 等)が増えることがあるが、Android の APK には入らないため許容する(PR 本文で司令塔が説明する)。増えたパッケージ名は tasklist の振り返りに列挙する

## ディレクトリ構造

```
lib/domain/models/goals.dart                         (新規)
lib/domain/goal_input.dart                           (新規)
lib/data/goal_repository.dart                        (新規)
lib/data/shared_preferences_goal_repository.dart     (新規)
lib/presentation/providers.dart                      (変更)
lib/presentation/goals/goals_controller.dart         (新規)
lib/presentation/goals/goal_settings_screen.dart     (新規)
lib/presentation/dashboard/dashboard_screen.dart     (変更)
scripts/check-layer-imports.sh                       (変更)
test/fakes/fake_goal_repository.dart                 (新規)
test/domain/goal_input_test.dart                     (新規)
test/data/shared_preferences_goal_repository_test.dart (新規)
test/presentation/goals/goals_controller_test.dart   (新規)
test/presentation/goals/goal_settings_screen_test.dart (新規)
test/presentation/dashboard/dashboard_screen_test.dart (変更)
```

## ドキュメント更新(実装者が行う)

- `docs/functional-design.md`
  - 「データモデル定義」に「エンティティ: Goals(目標値)」を追加(フィールド・null の意味・範囲)
  - 「コンポーネント設計」に `GoalRepository`(抽象)/ `SharedPreferencesGoalRepository` / `GoalsController` を追加(インターフェースと責務。本 design.md の 3・4・6 を要約)
  - 「画面・ウィジェット」付近に `GoalSettingsScreen` の内容(入力欄・範囲・エラー文言・保存後の動き)を追加
  - 「画面遷移図」の説明文に「AppBar の旗アイコンから `GoalSettingsScreen` を開く」を追記(図の状態機械は変えない)
  - 「ファイル構造」の「MVP では…アプリが書き出すファイルはない」に、P1 で目標値 2 つを `shared_preferences` に保存する旨を追記
- `docs/architecture.md`
  - 「状態管理(Riverpod)」の表に `goalRepositoryProvider` / `goalsControllerProvider` を追加
  - 「入力検証」の「ユーザーの入力項目はない(MVP)」を、目標値の入力と範囲(`goal_input.dart`)を書いた形に更新
- `docs/repository-structure.md`
  - 「保存データの導入」行の `*_store.dart` を `goal_repository.dart`(抽象)+ `shared_preferences_goal_repository.dart`(実装)に合わせる
  - `check-layer-imports.sh` の仕様に `shared_preferences_goal_repository.dart` を追記
  - `check-privacy.sh` の仕様の「保存」項目の括弧書きを「P1 の目標値の保存は `shared_preferences_goal_repository.dart` の import 行だけ allow で除外する」に更新
  - `lib/` のディレクトリツリーがあれば新規ファイルを追記

## 実装の順序

1. 依存の追加 → 2. ドメイン(goals / goal_input + テスト)→ 3. データ層(抽象・実装・フェイク + テスト)→ 4. プロバイダー・コントローラー(+ テスト)→ 5. 画面と導線(+ テスト)→ 6. 検査スクリプト → 7. docs

## セキュリティ考慮事項

- 保存するのは目標値 2 つ(int)だけ。健康データは保存しない
- `android:allowBackup="false"` は設定済みのため、クラウドバックアップの対象外
- `AndroidManifest.xml` と権限の許可リストは変えない(`shared_preferences_android` は権限を追加しない。CI の権限検査で確認)

## パフォーマンス考慮事項

- 読み書きは画面を開いたとき・保存したときの各 1 回だけ。ダッシュボードの起動時間に影響しない(ダッシュボードは読まない)

## 将来の拡張性

- #23 はダッシュボードから `goalsControllerProvider` を watch して達成状況を出す
