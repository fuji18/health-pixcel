# 開発ガイドライン (Development Guidelines)

本書は health-pixcel の実装規約と開発プロセスを定める。技術構成は `docs/architecture.md`、配置は `docs/repository-structure.md` を正とする。画面/UI を実装するときは `docs/ui-design-guidelines.md` も併せて参照する。

## 最重要ルール: 健康データを外に出さない

PRD の最重要要件。**他のすべての規約に優先する。**

| ルール | 具体的に禁止すること | 検査 |
|---|---|---|
| ログに出さない | 歩数・時刻・時間・`HealthDataPoint`・ドメインモデルを `print` / `debugPrint` / `log` / `developer.log` / 例外メッセージに渡す | `scripts/check-privacy.sh` + `avoid_print`(`print` のみ検出)+ レビュー + 実機での logcat 確認 |
| `toString()` を実装しない | ドメインモデル(`DailySteps` 等)に値を含む `toString()` を書く | レビュー |
| 外部へ送らない | `http` / `dio` 等の通信パッケージ、アナリティクス・クラッシュレポート SDK、`google_fonts` 等の実行時ダウンロードを追加する | 依存追加時の審査 + `scripts/check-release-permissions.sh` |
| 保存・共有しない(MVP) | ファイル書き出し、`shared_preferences` 等への健康データ保存、共有シート、クリップボードコピー | `scripts/check-privacy.sh` + レビュー |
| 権限を増やさない | `READ_STEPS` / `READ_SLEEP` 以外の権限をマニフェストに追加する(必要になったら PRD に理由を書いてから) | `scripts/check-release-permissions.sh`(許可リスト照合) |

```dart
// ❌ 悪い例: 値がログに残る
debugPrint('steps loaded: $steps');
throw StateError('invalid session ${session.start}-${session.end}');

// ✅ 良い例: 件数や種別だけを扱い、値は出さない
throw const HealthReadException(HealthErrorKind.readFailed);
```

デバッグ中に値を確認したいときは、**ブレークポイントで見る**。ログに出して後で消す運用はしない(消し忘れがそのまま事故になる)。

## コーディング規約

基本は [Effective Dart](https://dart.dev/effective-dart) と `flutter_lints` に従う。以下はプロジェクト固有の補足。

### 命名規則

```dart
// ✅ 良い例
final dailySleeps = assignSleepToDays(range, sessions);
Future<int?> readTotalSteps(DateTime start, DateTime end);
bool get hasRecord => sessions.isNotEmpty;
const sleepQueryLookbackDays = 1;

// ❌ 悪い例
final data = assign(r, s);
Future<int?> get(DateTime a, DateTime b);
bool get record => sessions.isNotEmpty;
const SLEEP_LOOKBACK = 1;   // Dart では定数も lowerCamelCase
```

| 対象 | 規則 | 例 |
|---|---|---|
| 変数・関数・定数 | `lowerCamelCase`。関数は動詞で始める | `buildDateRange`、`sleepQueryLookbackDays` |
| Boolean | `is` / `has` / `can` で始める | `isToday`、`hasRecord` |
| クラス・enum・typedef | `UpperCamelCase` | `DailySleep`、`HealthAvailability` |
| 抽象インターフェース | 接頭辞・接尾辞を付けない(`I` を付けない) | `HealthRepository` |
| 実装クラス | 実装手段を前に付ける | `HealthConnectRepository`、`FakeHealthRepository` |
| ファイル | `snake_case.dart` | `daily_sleep.dart` |
| private | 先頭に `_` | `_repository` |

**用語の統一**: コード上の名前は `docs/glossary.md` の英語名に合わせる(例: 睡眠の帰属日 = `date`、就寝 = `start`、起床 = `end`)。

### 型とモデル

- ドメインモデルは**不変**にする(フィールドはすべて `final`、コンストラクタは `const` にできるものは `const`)
- 「記録なし」は `null` または空リストで表す。`-1` や `0` などの番兵値を使わない
- 状態の分岐は `sealed class` + `switch` 式で書き、`default` / `_` で握りつぶさない(状態を追加したときにコンパイラが漏れを指摘するようにする)

```dart
// ✅ 良い例: 網羅性をコンパイラが検査する
Widget build(BuildContext context) => switch (result) {
  MetricLoaded(:final days) => _DayList(days: days),
  MetricPermissionDenied() => const _PermissionPrompt(),
  MetricFailed() => const _ErrorMessage(),
};

// ❌ 悪い例: 状態を追加しても気付けない
if (result is MetricLoaded) { ... } else { return const SizedBox(); }
```

- 日付は**ローカル時刻の `DateTime`** で扱う。ヘルスコネクトから受け取った値は `HealthConnectRepository` で `toLocal()` してから上位層に渡す
- 日の加減算は `DateTime(y, m, d ± n)` で行い、`add(Duration(days: n))` は使わない(夏時間で 00:00 からずれる。機能設計書 A1)
- `dynamic` と `!`(null 断言)は使わない。やむを得ず使う場合は理由をコメントで書く

### 時刻への依存

- `DateTime.now()` を直接呼んでよいのは `clockProvider` の既定値だけ。その他のコードは注入された時計(`DateTime Function()`)を使う(テストで「今日」を固定するため)

### コードフォーマット

- `dart format` に従う(インデント 2 スペース・行長 80 文字が既定。設定は変えない)
- 引数が複数行になる場合は末尾カンマを付ける(`dart format` が縦に展開する)

### analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:                         # Flutter ツールが pub get 時に自動で追記する(Dart コードは無い)
    - build/**
    - android/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - avoid_print                  # 健康データのログ出力防止(flutter_lints に含まれるが明示する)
    - always_use_package_imports   # レイヤー検査を grep で行うため相対 import を禁止
    - prefer_final_locals
    - prefer_const_constructors
    - unawaited_futures            # Future の握りつぶし防止
    - avoid_dynamic_calls
```

### コメント規約

- 公開 API(他のレイヤーから呼ばれるクラス・関数)には `///` のドキュメントコメントを書く。**何を返すか・null の意味・例外**を書く
- インラインコメントは「なぜ」を書く。仕様の根拠は機能設計書の節番号を添える

```dart
/// [start, end) の歩数合計を返す。
///
/// 記録がない区間では `null` を返す(0 も記録なしとして扱う。機能設計書 A2)。
/// 読み取りに失敗した場合は [HealthReadException] を投げる。
Future<int?> readTotalSteps(DateTime start, DateTime end);

// 最古の日に起床したセッションは前日夜に始まるため、1 日前から読む(機能設計書 A3)
final queryStart = DateTime(oldest.year, oldest.month, oldest.day - 1);
```

### エラーハンドリング

| 層 | 方針 |
|---|---|
| データ層 | `health` の例外(`UnsupportedError` / `HealthException` / その他)を捕捉し、`HealthReadException(kind)` に変換して投げ直す。元の例外のメッセージは保持しない・出力しない |
| アプリケーション層 | `HealthReadException` を `MetricFailed(kind)` に変換する。歩数と睡眠は独立に処理し、片方の失敗でもう片方を止めない |
| プレゼンテーション層 | `DashboardController._fetch()` の最上位で想定外の例外も捕捉し、`MetricFailed` として表示する。`AsyncError` を画面に出さない |

```dart
// ✅ データ層: プラグインの例外型を上位に漏らさない
try {
  final steps = await _health.getTotalStepsInInterval(start, end);
  // 0 も記録なしとして扱う(機能設計書 A2)
  return (steps == null || steps == 0) ? null : steps;
} on UnsupportedError {
  throw const HealthReadException(HealthErrorKind.unavailable);
} catch (_) {
  throw const HealthReadException(HealthErrorKind.readFailed);
}
```

- `catch (_) {}` で黙って握りつぶさない。捕捉したら必ず状態(`MetricFailed` 等)に反映する
- `unawaited` にする Future は、失敗しても画面状態に影響しないものに限る

### Flutter / Riverpod

- ウィジェットは `StatelessWidget` / `ConsumerWidget` を基本とし、ロジックを持たせない(表示と操作の受け渡しだけ)
- ウィジェットでは、状態の購読は `ref.watch`、操作の呼び出しは `ref.read(...notifier)`。ウィジェットの `build()` の中で `ref.read` しない
- Notifier(`DashboardController`)の中では、リポジトリ・サービスを各メソッド内で `ref.read` して取得する(不変の依存のため `watch` しない。機能設計書「DashboardController」)
- プロバイダーは `lib/presentation/providers.dart` と各コントローラーのファイルにだけ定義する
- テキストは画面上の固定文言のみ。文言は機能設計書「状態別の表示」と一致させる(MVP では多言語化しない。日本語固定)

### Kotlin(MainActivity)

- 書くのは `architecture.md` で定義した MethodChannel 1 本と初期ルートのオーバーライドだけ。ロジックを Kotlin 側に増やさない
- 失敗時は例外を Dart に投げず、`false` / `null` を返す

## Git 運用ルール

### ブランチ戦略(GitHub Flow)

**機械可読な単一ソース**: ベースブランチ・許可接頭辞・保護ブランチは `.claude/branch-policy.json` に定義する。この節は人間向けの説明であり、**hook・CI・スラッシュコマンドが参照する値はポリシーファイルが正**。変更するときは両方を同時に更新する。

現在の設定:
- ベースブランチ: `main`(保護ブランチ。直接コミット禁止)
- 作業ブランチの接頭辞: `feature/` `fix/` `release/` `hotfix/` `claude/` `dependabot/`

**ブランチ種別**:
- `main`: 常にリリースビルドが通る状態
- `feature/[内容]`: 新機能・リファクタリング・ドキュメント更新(例: `feature/weekly-steps-list`)
- `fix/[内容]`: バグ修正(例: `fix/sleep-day-assignment`)
- `claude/[自動生成名]`: Claude Code のアプリ/web リモートセッションが生成するブランチ。`feature/*` と同格に扱い、**リネームしない**
- `dependabot/*`: 依存更新の自動 PR

```
main
  ├─ feature/weekly-steps-list
  ├─ fix/sleep-day-assignment
  └─ claude/xxx-yyy  (リモートセッション生成)
```

個人開発のため `develop` 統合ブランチは置かない。1 チケット = 1 ブランチ = 1 PR。

### コミットメッセージ規約(Conventional Commits)

```
<type>(<scope>): <subject>

<body>

<footer>
```

**type**: `feat` / `fix` / `docs` / `style` / `refactor` / `test` / `chore` / `build`(Gradle・マニフェスト・依存)/ `ci`

**scope**: `domain` / `application` / `data` / `ui` / `android` / `deps` / `docs` / `harness`

**例**:
```
feat(domain): 睡眠セッションの起床日への振り分けを追加

日付をまたぐ睡眠を起床日に帰属させる assignSleepToDays を実装した。
同一の開始・終了時刻を持つセッションは 1 件にまとめる。

Closes #5
```

- subject は日本語・体言止めか「〜を追加」形式、50 文字以内
- **コミットメッセージにも健康データの実値を書かない**(実機確認の結果を書く場合は「一致した」「差異あり」まで)

### プルリクエストプロセス

**作成前のチェック**:
- [ ] `flutter analyze` がエラー・警告なし
- [ ] `dart format --output=none --set-exit-if-changed .` が差分なし
- [ ] `flutter test` が全件パス
- [ ] `bash scripts/check-layer-imports.sh` がパス
- [ ] `bash scripts/check-privacy.sh` がパス
- [ ] マニフェスト・依存・Gradle を変えた場合: `flutter build apk --release` → `bash scripts/check-release-permissions.sh` がパス
- [ ] `.steering/*/tasklist.md` の未完了項目がない(残る場合は PR 本文に明記)

**PR テンプレート**: `.github/pull_request_template.md` を使う(概要 / 関連 Issue / ステアリング / 検証)。UI を変えた場合はスクリーンショットを添える。**スクリーンショットは実データではなくテスト用の値で撮るか、数値を隠す**(健康データを GitHub に上げない)

**レビュープロセス**:
1. 実装中: `code-reviewer` サブエージェントによるレビュー(スペック整合を含む)
2. PR 作成時: CI(機械的検証)+ main 向け PR のオープン時に 1 回の自動レビュー
3. 指摘対応後、セルフマージ

## テスト戦略

### テストの種類と目標

| 種類 | 対象 | 実行 | 目標 |
|---|---|---|---|
| ユニットテスト | ドメイン層の関数、`WeeklySummaryService`、`DashboardController` | `flutter test` | ドメイン層・アプリケーション層のカバレッジ 90% 程度を目安(ゲートにはしない) |
| ウィジェットテスト | `DashboardScreen` の状態別表示 | `flutter test` | 機能設計書「状態別の表示」の全行を 1 ケース以上 |
| 実機確認 | ヘルスコネクトとの結合、HUAWEIヘルスケアとの数値の一致 | 手動(Pixel 10) | 機能設計書「実機確認」の全項目。リリース前と依存のメジャー更新時 |

`HealthConnectRepository` のテストは変換規則(記録なし・不正セッションの破棄・例外の変換)に限る。フェイクの `Health` を注入して検証し、プラグインとヘルスコネクトの実際の挙動は実機確認で担保する(`architecture.md`「テスト戦略」)。変換ロジック(`HealthDataPoint` → `SleepSession`)は小さく保ち、判定ロジックはドメイン層に置く。

### テストの書き方

- **テスト名は日本語で「条件 → 期待結果」**を書く
- Arrange / Act / Assert を空行で区切る
- 「今日」は必ず固定する(`clockProvider` の override または関数の引数)。実行日によって結果が変わるテストを書かない
- テストデータの数値は架空の値を使う(本人の実データをテストに貼らない)
- 日付フォーマットを含むテストは `setUpAll(() => initializeDateFormatting('ja'))` を呼ぶ。期待値の曜日は実際の暦どおりに書く(2026-10-06 は火曜日)

```dart
group('assignSleepToDays', () {
  test('日付をまたぐ睡眠は起床日に振り分けられる', () {
    final range = buildDateRange(DateTime(2026, 10, 6, 9));
    final session = SleepSession(
      start: DateTime(2026, 10, 5, 23, 30),
      end: DateTime(2026, 10, 6, 6, 30),
    );

    final days = assignSleepToDays(range, [session]);

    expect(days.first.date, DateTime(2026, 10, 6));
    expect(days.first.sessions, [session]);
    expect(days[1].hasRecord, isFalse);
  });
});
```

### モック・フェイク

- `HealthRepository` は `test/fakes/fake_health_repository.dart` の**手書きフェイク**で置き換える(呼び出しごとに返す値・投げる例外を設定できるようにする)。モック生成パッケージ(`mockito` / `mocktail`)は MVP では入れない
- ドメイン層は本物を使う(フェイクにしない)
- Riverpod のテストは `ProviderContainer(overrides: [...])`、ウィジェットテストは `ProviderScope(overrides: [...])` で注入する

## コードレビュー基準

### レビューポイント

**プライバシー(最優先)**:
- [ ] 健康データの値がログ・例外メッセージ・`toString()` に出ていないか
- [ ] 新しい依存・権限・ファイル書き出しが追加されていないか(追加されているなら PRD / architecture.md の根拠があるか)

**仕様との整合**:
- [ ] 機能設計書の定義(日付の区切り・睡眠の帰属日・記録なしの扱い・表示形式)と一致しているか
- [ ] 状態別の表示の文言が機能設計書と一致しているか

**設計**:
- [ ] レイヤーの依存ルールを守っているか(`health` は `lib/data/` だけ、`domain` は純 Dart)
- [ ] 書き込み元(`sourceName` / `sourceId`)による分岐がないか
- [ ] `sealed class` の `switch` に `default` で握りつぶす分岐がないか

**テスト**:
- [ ] 日付境界(月またぎ・年またぎ・日付をまたぐ睡眠)のケースがあるか
- [ ] 「今日」が固定されているか

**UI**:
- [ ] `docs/ui-design-guidelines.md` §6 のチェックリスト

### レビューコメントの優先度

- `[必須]`: 修正必須(プライバシー違反・仕様不一致・バグ)
- `[推奨]`: 修正推奨
- `[提案]`: 検討してほしい
- `[質問]`: 理解のための質問

## 品質の自動化

| 層 | 内容 | 担当 |
|---|---|---|
| 編集時 | `dart format` | エディタ / lint-staged(`*.dart` → `dart format`。コミットするシェルの PATH に `dart` があることが前提) |
| コミット時 | 保護ブランチ検査・secretlint・lint-staged | `.husky/`(ハーネス) |
| 検収時 | analyze + format 検査 + test + レイヤー検査 + プライバシー検査 | `/check`(`test-runner`) |
| PR 時 | 上記 + リリースビルド + 権限検査 | CI(`ci.yml`。Flutter 用への置き換えは `/kickoff` フェーズ1) |

CI(GitHub Actions、ubuntu)では Flutter をセットアップして次を実行する:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
flutter build apk --release
bash scripts/check-release-permissions.sh
```

## 開発環境セットアップ

### 必要なツール

| ツール | バージョン | 入手方法 |
|--------|-----------|-----------------|
| Flutter SDK | 3.47.x stable | https://docs.flutter.dev/get-started/install/windows |
| Android Studio | 最新 stable | 公式サイト(Android SDK・JDK 17 を同梱) |
| Git for Windows | 最新 | 公式サイト(Git Bash で `scripts/*.sh` を実行する) |
| Node.js | v24 | ハーネス(husky / secretlint)用。アプリには不要 |
| devcontainer | — | Claude Code の実行環境。Flutter SDK は `post_create.sh` が導入する(Android SDK は入れない) |
| Pixel 10 | Android 16 以降 | 開発者オプションで USB デバッグを有効化 |

### セットアップ手順

```bash
# 1. リポジトリのクローン
git clone [URL]
cd health-pixcel

# 2. ハーネスの依存(git hook の有効化)
npm ci

# 3. Flutter の依存(pubspec.yaml は最初の実装チケットで生成される。生成前はこの手順を飛ばす。
#    生成手順は repository-structure.md「Flutter プロジェクトの生成手順」)
flutter pub get

# 4. 環境確認(Android toolchain と接続端末)
flutter doctor
flutter devices

# 5. 実機で起動(デバッグビルド)
flutter run
```

### 実機確認の準備

1. Pixel 10 に Health Sync をインストールし、HUAWEIヘルスケア → ヘルスコネクトへの歩数・睡眠の同期を有効にする
2. ヘルスコネクトのアプリで、Health Sync からのデータが入っていることを確認する
3. リリースビルドの確認は `flutter build apk --release` → `flutter install --release`(個人利用のため、署名はデバッグ鍵のままでよい。署名鍵を作る場合はリポジトリに含めない)

### リリースビルドの権限検査

```bash
flutter build apk --release
bash scripts/check-release-permissions.sh   # exit 0 なら OK(INTERNET なし・許可リスト外の権限なし)
```

加えて、リリース前に Android Studio の **Build > Analyze APK** で `build/app/outputs/flutter-apk/app-release.apk` を開き、`AndroidManifest.xml` に `android.permission.INTERNET` が無いことを目視で確認する。
