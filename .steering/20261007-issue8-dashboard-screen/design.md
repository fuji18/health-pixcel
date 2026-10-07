# 設計: ダッシュボード画面(#8)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/functional-design.md`「画面・ウィジェット」「画面遷移図」「UI設計」「A4. 表示フォーマット」「テスト戦略 > ウィジェットテスト」と `docs/ui-design-guidelines.md` §3・§6・§7。**食い違ったら本ファイルを優先**する(差分は §0)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- `docs/` は変更しない(司令塔が行う)。コミットはしない(司令塔が行う)
- 作成・変更してよいのは次のファイルと本 steering の `tasklist.md` だけ。`pubspec.yaml` / `lib/domain/` / `lib/data/` / `lib/application/` / `lib/presentation/providers.dart` / `lib/presentation/dashboard/dashboard_{state,controller}.dart` / `test/fakes/` / `scripts/` は変更しない
  - 新規: `lib/presentation/dashboard/dashboard_screen.dart`
  - 新規: `lib/presentation/dashboard/widgets/status_message.dart`
  - 新規: `lib/presentation/dashboard/widgets/sleep_section.dart`
  - 新規: `lib/presentation/dashboard/widgets/steps_section.dart`
  - 新規: `test/presentation/dashboard/dashboard_screen_test.dart`
  - 変更: `lib/app.dart` / `lib/main.dart` / `test/app_test.dart`
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)。Riverpod 3.4.3 のソースは `~/.pub-cache/hosted/pub.dev/{riverpod,flutter_riverpod}-3.4.3/`
- import はすべて `package:health_pixcel/...`(相対 import 禁止)。健康データの値を `print` / `debugPrint` / `log` に渡さない
- 各公開要素に 1 行の `///` doc コメントを付ける(既存コードに合わせる)
- **色・文字サイズを直書きしない。** `lib/presentation/` 内で `Colors.` / `Color(` / `fontSize` / `FontWeight` を使わない。色は `Theme.of(context).colorScheme`、文字は `Theme.of(context).textTheme` から取る。`Color(` は `lib/app.dart` のシード色 1 箇所だけ
- 余白(`EdgeInsets` / `SizedBox` / `spacing` / `Divider.height`)はすべて 4 の倍数
- `build()` が 80 行を超えたらメソッドかウィジェットに切り出す

## 0. 設計判断の記録(司令塔が決定済み)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| 「詳しく見る」 | **#8 では出さない**(#9 で `PermissionRationaleScreen` と一緒に足す) | 遷移先の無いボタンを置かない |
| ローディングの判定 | `when()` を使わず、`async.isLoading` → `async.hasError` → `async.requireValue` の順に `if` で判定する | #7 の確認どおり `requestPermissions()` 中は前回値つきの `AsyncLoading`。`isLoading` を最初に見れば必ずローディング表示になり、`when()` の既定値に依存しない |
| セクションの依存 | `SleepSection` / `StepsSection` / `StatusMessage` は `StatelessWidget` で、Riverpod を読まない。操作はコールバックで受け取る | ウィジェットは表示だけ(機能設計書)。スナックバーは画面が出す |
| 文言の分割 | `StatusMessage` は「見出し + 説明」。機能設計書の 1 文の案内は §3 の表のとおり見出しと説明に分ける | `StatusMessage` の責務(見出し + 説明 + 操作ボタン) |
| ボタンの種類 | `StatusMessage` の操作の 1 つ目を `FilledButton`、2 つ目以降を `OutlinedButton` | アクセント 1 色(§3.3)。主操作を 1 つに絞る |
| テーマ | シード色 `Color(0xFF2E7D80)`(落ち着いた青緑)。`ColorScheme.fromSeed` でライト/ダーク。`themeMode` は既定(システム追従)。`TextTheme` は Material 3 の既定を使う | `ui-design-guidelines.md` §7。依存を増やさない |
| ThemeData の置き場所 | `lib/app.dart`(§7 の `lib/presentation/app.dart` は誤記。司令塔が docs を直す) | 実在するファイル |
| 最初の画面 | `HealthPixcelApp` の `home` は常に `DashboardScreen`。起動理由による出し分けは #9 | スコープ外 |
| 数字の桁揃え | 時刻・時間・歩数の `Text` は `textTheme.bodyLarge` に `fontFeatures: const [FontFeature.tabularFigures()]` を足した style を使う | 数字が主役の一覧(§7)。サイズや色は変えない |

## 1. `lib/presentation/dashboard/widgets/status_message.dart`

```dart
/// StatusMessage の操作ボタン 1 つぶん。
class StatusAction {
  const StatusAction(this.label, this.onPressed);
  /// ボタンの文言。
  final String label;
  /// 押したときの処理。
  final VoidCallback onPressed;
}

/// 案内・エラーの共通表示(見出し + 説明 + 操作ボタン)。
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.title, this.body, this.actions = const []});
  final String title;
  final String? body;
  final List<StatusAction> actions;
}
```

`build()`:
- `Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min)`
- `Text(title, style: textTheme.titleMedium)`
- `body` が非 null → `SizedBox(height: 4)` + `Text(body, style: textTheme.bodyLarge)`
- `actions` が空でない → `SizedBox(height: 16)` + `Wrap(spacing: 8, runSpacing: 8, children: [...])`。`actions[0]` は `FilledButton(onPressed:, child: Text(label))`、それ以降は `OutlinedButton(...)`
- 背景・枠・アイコンは付けない

## 2. `lib/presentation/dashboard/widgets/sleep_section.dart` / `steps_section.dart`

### 2.1 共通のコンストラクタ

```dart
/// 睡眠セクション。7 行の一覧・未許可の案内・エラー表示のいずれかを描画する。
class SleepSection extends StatelessWidget {
  const SleepSection({
    super.key,
    required this.result,          // MetricResult<DailySleep>(StepsSection は MetricResult<DailySteps>)
    required this.today,           // DateRange.today(「今日」「昨日」の判定)
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });
  final MetricResult<DailySleep> result;
  final DateTime today;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
}
```

### 2.2 `build()` の構成(両セクション共通)

`Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min)`:

1. 見出し `Text('睡眠', style: textTheme.titleMedium)`(歩数は `'歩数'`)
2. `SizedBox(height: 8)`
3. `switch (result)`:
   - `MetricLoaded(:final days)` → `days` の順(新しい順。並べ替えない)に 1 日 1 行。**記録なしの日も行を出す**(7 行)
   - `MetricPermissionDenied()` → `StatusMessage(title: '睡眠の権限が許可されていません', actions: [StatusAction('権限を許可する', onRequestPermission), StatusAction('ヘルスコネクトの設定を開く', onOpenSettings)])`(歩数は `'歩数の権限が許可されていません'`)
   - `MetricFailed()` → `StatusMessage(title: 'データを読み込めませんでした', actions: [StatusAction('再読み込み', onRetry)])`

スタイル(`final theme = Theme.of(context);`):
- `label` = `textTheme.bodyLarge`
- `numeric` = `textTheme.bodyLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])`
- `muted` = `textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)`(「記録なし」「(途中)」)

### 2.3 睡眠の 1 行

```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(formatDayLabel(day.date, today: today), style: label)),
      if (!day.hasRecord)
        Text('記録なし', style: muted)
      else ...[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in day.sessions)
              Text('${formatTime(s.start)}→${formatTime(s.end)}', style: numeric),
          ],
        ),
        const SizedBox(width: 16),
        Text(formatDuration(day.total), style: numeric),   // 日別合計。1 行目の高さに並ぶ
      ],
    ],
  ),
)
```

### 2.4 歩数の 1 行

```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Expanded(child: Text(formatDayLabel(day.date, today: today), style: label)),
      if (day.steps == null)
        Text('記録なし', style: muted)
      else ...[
        Text(formatSteps(day.steps!), style: numeric),
        if (day.isToday) ...[const SizedBox(width: 4), Text('(途中)', style: muted)],
      ],
    ],
  ),
)
```

今日が記録なしのときは「記録なし」だけ(「(途中)」は付けない)。整形関数は `package:health_pixcel/domain/formatters.dart` のものを使う(新たに書かない)。

## 3. `lib/presentation/dashboard/dashboard_screen.dart`

```dart
/// 唯一の画面。DashboardState に応じて表示を出し分ける。
class DashboardScreen extends ConsumerStatefulWidget { const DashboardScreen({super.key}); ... }

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final AppLifecycleListener _lifecycle;

  DashboardController get _controller => ref.read(dashboardControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _controller.onResumed());
  }

  @override
  void dispose() { _lifecycle.dispose(); super.dispose(); }
}
```

### 3.1 `build()`

```dart
final async = ref.watch(dashboardControllerProvider);
return Scaffold(
  appBar: AppBar(title: const Text('health-pixcel')),
  body: _buildBody(async),
);
```

`_buildBody(AsyncValue<DashboardState> async)`:
1. `async.isLoading` → `const Center(child: CircularProgressIndicator(semanticsLabel: '読み込み中'))`(`RefreshIndicator` で包まない)
2. それ以外は次の `children` を `RefreshIndicator(onRefresh: () => _controller.refresh(), child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: children))` に入れる(**全状態で引っぱって更新できる**)
   - `async.hasError` → `[StatusMessage(title: 'データを読み込めませんでした', actions: [StatusAction('再読み込み', _retry)])]`
   - それ以外は `switch (async.requireValue)` で下表

| 状態 | children |
| --- | --- |
| `DashboardUnavailable(availability: notInstalled)` | `StatusMessage(title: 'ヘルスコネクトを利用できません', body: 'Play ストアでヘルスコネクトの状態を確認してください', actions: [StatusAction('Play ストアを開く', _openStore)])` |
| `DashboardUnavailable(availability: updateRequired)` | `StatusMessage(title: 'ヘルスコネクトの更新が必要です', actions: [StatusAction('ヘルスコネクトを更新する', _openStore)])` |
| `DashboardUnavailable(availability: available)` | 発生しない。`notInstalled` と同じ表示にする(`switch` を網羅させるため) |
| `DashboardNeedsPermission()` | `StatusMessage(title: '歩数と睡眠を表示するには、ヘルスコネクトの読み取り権限が必要です', body: 'データの読み取りのみ行い、端末の外には送信しません', actions: [StatusAction('権限を許可する', _requestPermissions), StatusAction('ヘルスコネクトの設定を開く', _openSettings)])` |
| `DashboardReady()` | 下記 |

`DashboardReady` の children(順序固定 = **睡眠が上・歩数が下**):
1. `isAllEmpty` のときだけ: `StatusMessage(title: 'ヘルスコネクトにデータがありません', body: 'Health Sync の同期設定を確認してください', actions: [StatusAction('再読み込み', _retry)])` + `const SizedBox(height: 24)`
2. `SleepSection(result: state.sleep, today: state.range.today, onRequestPermission: _requestPermissions, onOpenSettings: _openSettings, onRetry: _retry)`
3. `const Divider(height: 32)`
4. `StepsSection(result: state.steps, today: state.range.today, ...同じコールバック)`

### 3.2 操作ハンドラ(すべて `_DashboardScreenState` の private メソッド)

```dart
void _retry() => _controller.refresh();
void _requestPermissions() => _controller.requestPermissions();

Future<void> _openSettings() async {
  final opened = await _controller.openSettings();
  if (!opened && mounted) _showSnackBar('ヘルスコネクトを開けませんでした');
}

Future<void> _openStore() async {
  final opened = await _controller.openStore();
  if (!opened && mounted) _showSnackBar('Play ストアを開けませんでした');
}

void _showSnackBar(String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
```

`StatusAction` / セクションのコールバック型は `VoidCallback`。`Future` を返すメソッドを渡すときは `() => _openSettings()` の形でよい(`flutter analyze` が通る書き方を選ぶ)。

## 4. `lib/app.dart`

```dart
/// 落ち着いた青緑(ui-design-guidelines.md §7)。アプリで唯一の色の直書き。
const _seedColor = Color(0xFF2E7D80);

ThemeData _buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness),
);

/// アプリのルート。起動理由による最初の画面の出し分けは #9 で足す。
class HealthPixcelApp extends StatelessWidget {
  ...
  build: MaterialApp(
    title: 'health-pixcel',
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    home: const DashboardScreen(),
  );
}
```

## 5. `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');   // package:intl/date_symbol_data_local.dart
  runApp(const ProviderScope(child: HealthPixcelApp()));
}
```

## 6. テスト

### 6.1 共通の準備(`dashboard_screen_test.dart`)

- `setUpAll(() => initializeDateFormatting('ja'))`
- 固定時計 `now = DateTime(2026, 10, 6, 10, 30)`(今日 = 10/6 火。範囲は 10/6〜9/30)。曜日は実際の暦どおり(10/6 火、10/5 月、10/4 日、10/3 土、10/2 金、10/1 木、9/30 水)
- `late FakeHealthRepository fake;` を `setUp` で作る(`test/fakes/fake_health_repository.dart`。既定は利用可能・両方許可・データなし)
- ヘルパー:

```dart
Future<void> pumpScreen(WidgetTester tester, {List overrides = const []}) async {
  tester.view.physicalSize = const Size(800, 2400);   // ListView が全行を構築するよう縦長にする
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      healthRepositoryProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
      ...overrides,
    ],
    retry: (_, _) => null,   // Riverpod 3 の自動リトライを止める(AsyncError のテストでタイマーが残らないように)
    child: const MaterialApp(home: DashboardScreen()),
  ));
}
```

`overrides` の要素型は Riverpod 3.4.3 の `ProviderScope.overrides` の型に合わせる。ローディング中のテスト以外は `pumpScreen` の後に `await tester.pumpAndSettle()` する(`CircularProgressIndicator` 表示中に `pumpAndSettle` するとタイムアウトするので、ローディングのテストでは `pump()` を使う)。

### 6.2 ケース(すべて必須)

| # | 準備 | 期待 |
| --- | --- | --- |
| 1 | `fake.permissionsGate = Completer()` → `pumpScreen` → `pump()` | `CircularProgressIndicator` が 1 つ。`gate.complete()` → `pumpAndSettle()` で `'睡眠'` が出る |
| 2 | `fake.availability = notInstalled` | `'ヘルスコネクトを利用できません'` / `'Play ストアでヘルスコネクトの状態を確認してください'` / ボタン `'Play ストアを開く'`。タップで `fake.openStoreCalls == 1`、スナックバーは出ない |
| 3 | `notInstalled` + `fake.openStoreResult = false` | `'Play ストアを開く'` をタップ → `pump()` → `'Play ストアを開けませんでした'` が出る |
| 4 | `fake.availability = updateRequired` | `'ヘルスコネクトの更新が必要です'` / ボタン `'ヘルスコネクトを更新する'`。タップで `openStoreCalls == 1` |
| 5 | 両方 `denied` | 案内の見出しと説明の 2 文 / `'権限を許可する'` / `'ヘルスコネクトの設定を開く'`。`'詳しく見る'` が無い |
| 6 | 両方 `denied` + `permissionsAfterRequest = 両方 granted` | `'権限を許可する'` タップ → `pumpAndSettle()` → `'睡眠'` と `'歩数'` の見出しが出る(再起動不要。F1)。`requestPermissionsCalls == 1` |
| 7 | 両方 `denied` + `openSettingsResult = false` | `'ヘルスコネクトの設定を開く'` タップ → `pump()` → `'ヘルスコネクトを開けませんでした'`。`openSettingsCalls == 1` |
| 8 | 両方許可。`steps[10/6] = 3210`、`steps[10/5] = 8432`。`sleepSessions = [10/5 23:45→10/6 06:57, 10/5 00:10→10/5 07:20, 10/5 13:00→10/5 13:40]` | 下の「#8 の期待」 |
| 9 | `steps` 未許可・`sleep` 許可(データは #8 と同じ) | `'歩数の権限が許可されていません'` と、その下の `'権限を許可する'` / `'ヘルスコネクトの設定を開く'`。睡眠は 7 行(`'今日 10/6(火)'` が 1 つ = 睡眠側のみ) |
| 10 | 両方許可 + `fake.sleepError = HealthErrorKind.readFailed` | 睡眠セクションに `'データを読み込めませんでした'` + `'再読み込み'`。歩数は 7 行。`fake.sleepError = null` にして `'再読み込み'` をタップ → `pumpAndSettle()` → `'データを読み込めませんでした'` が消える |
| 11 | 両方許可・データなし(既定) | `'ヘルスコネクトにデータがありません'` / `'Health Sync の同期設定を確認してください'` / `'再読み込み'` が 1 つ。`'記録なし'` が 14 個 |
| 12 | `overrides: [dashboardControllerProvider.overrideWith(_FailingController.new)]`。`_FailingController extends DashboardController` は `build()` で `throw Exception('boom')` するだけ | `'データを読み込めませんでした'` + `'再読み込み'`。タップ → `pumpAndSettle()` → `'睡眠'` が出る(本物の `refresh()` が走る) |
| 13 | 両方許可。`checkAvailabilityCalls` を記録 | `tester.fling(find.byType(ListView), const Offset(0, 400), 1000)` → `pumpAndSettle()` → `checkAvailabilityCalls` が増えている |
| 14 | 両方許可で表示後、`fake.permissions = (steps: denied, sleep: granted)` | `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive)` → `(AppLifecycleState.resumed)` → `pumpAndSettle()` → `'歩数の権限が許可されていません'` が出る |
| 15 | 両方許可で表示後、何も変えずに #14 と同じ復帰 | `checkPermissionsCalls` が復帰の確認ぶん(1 回)しか増えない(再読み込みしない) |

「#8 の期待」:
- `'今日 10/6(火)'` / `'昨日 10/5(月)'` / `'10/4(日)'` / `'10/3(土)'` / `'10/2(金)'` / `'10/1(木)'` / `'9/30(水)'` がそれぞれ **2 つ**(睡眠・歩数の各 7 行。記録なしの日も省略されない)
- 睡眠: `'23:45→06:57'` / `'7時間12分'` / `'00:10→07:20'` / `'13:00→13:40'` / `'7時間50分'`(10/5 の合計)
- 歩数: `'3,210 歩'` / `'(途中)'` が 1 つ / `'8,432 歩'`
- `'記録なし'` が 10 個(睡眠 5 + 歩数 5)
- 並び: `'睡眠'` の dy < `'歩数'` の dy。`find.text('今日 10/6(火)').first` の dy < `find.text('昨日 10/5(月)').first` の dy(新しい日が上)
- `isAllEmpty` の案内(`'ヘルスコネクトにデータがありません'`)が無い

#14 で `AppLifecycleListener` が状態遷移の不正を assert で落とす場合は、`inactive` の前に `resumed` を送る・`hidden`/`paused` を挟むなど、Flutter の正しい遷移列に直してよい(判断待ちにしなくてよい)。

### 6.3 `test/app_test.dart`

既存のテストを次に置き換える: `setUpAll` で `initializeDateFormatting('ja')`。`ProviderScope(overrides: [healthRepositoryProvider.overrideWithValue(FakeHealthRepository()), clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 10, 30))], child: HealthPixcelApp())` を `pumpWidget` → `pumpAndSettle()` → `find.byType(DashboardScreen)` が 1 つ。さらに `tester.widget<MaterialApp>(find.byType(MaterialApp))` の `theme` / `darkTheme` が非 null で、それぞれの `colorScheme.brightness` が `light` / `dark`。

## 7. 完了条件

次をすべて通す(1 つでも落ちたら完了にしない):

```bash
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
grep -rnE 'Colors\.|Color\(|fontSize|FontWeight' lib/presentation/   # 出力が空であること
```

## 8. 検収指摘の対応(司令塔が決定済み)

`lib/presentation/dashboard/widgets/sleep_section.dart` / `steps_section.dart` と `test/presentation/dashboard/dashboard_screen_test.dart` だけを変更する。

1. **セクション見出し**: 見出しの `Text('睡眠' / '歩数', ...)` を `Semantics(header: true, child: ...)` で包む(TalkBack で見出しとして読ませる)
2. **1 日の行**: 睡眠・歩数の各行(§2.3 / §2.4 の `Padding`)を `MergeSemantics(child: ...)` で包む(日付と値を 1 つにまとめて読ませる)。見た目は変えない
3. **ケース 10**: 再読み込み後に `'データを読み込めませんでした'` が消えることに加え、`'睡眠'` セクションに行が出たこと(`find.text('今日 10/6(火)')` が `findsNWidgets(2)`)を確認する。データが必要なら #8 と同じ準備を入れてよい
4. **ケース 2**: スナックバーが出ないことの確認を、タップ → `pumpAndSettle()` の後に `find.byType(SnackBar)` が `findsNothing` で行う
5. **見出しのセマンティクス**のテストを 1 件足す(ケース 16): 両方許可で表示 → `tester.getSemantics(find.text('睡眠'))` が `SemanticsFlag.isHeader` を持つ(`matchesSemantics(isHeader: true, ...)` 等、Flutter 3.47 で通る書き方を選んでよい)。`SemanticsHandle` は `tester.ensureSemantics()` で取り、`dispose` する

完了条件は §7 と同じ。
