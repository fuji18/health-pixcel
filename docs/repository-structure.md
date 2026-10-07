# リポジトリ構造定義書 (Repository Structure Document)

本書は `docs/architecture.md` のレイヤー構成を、Flutter プロジェクトのディレクトリとファイルに落とし込む。Flutter アプリは**リポジトリのルート**に置く(`pubspec.yaml` がルートにある構成)。開発ハーネス(`.claude/` / `.husky/` / CI 等)と同居する。

## プロジェクト構造

```
health-pixcel/
├── lib/                          # アプリのソースコード(Dart)
│   ├── main.dart                 # エントリポイント(ProviderScope・initializeDateFormatting。health は import しない)
│   ├── app.dart                  # MaterialApp・テーマ・最初の画面の選択
│   ├── domain/                   # ドメイン層(純 Dart)
│   ├── application/              # アプリケーション層
│   ├── data/                     # データ層(health パッケージはここだけ)
│   └── presentation/             # プレゼンテーション層(画面・状態管理)
├── test/                         # テスト(lib/ と同じ構造)
├── android/                      # Android ネイティブ(Gradle・マニフェスト・Kotlin)
├── scripts/                      # アプリの検証スクリプト
├── docs/                         # 永続ドキュメント
├── .steering/                    # 作業単位の計画(履歴としてコミット)
├── pubspec.yaml                  # Flutter の依存定義
├── pubspec.lock                  # 依存のロック(コミットする)
├── analysis_options.yaml         # flutter analyze の設定
│
├── .claude/ .codex/ .husky/ .harness/ .github/ .devcontainer/   # 開発ハーネス(テンプレート由来)
├── AGENTS.md / CLAUDE.md / README.md
└── package.json / package-lock.json   # ハーネス用(husky・lint-staged・secretlint)。アプリには無関係
```

- `ios/` は P2(iOS 対応)着手時に `flutter create --platforms=ios .` で追加する。MVP では作らない(`web/` `windows/` 等その他のプラットフォームも作らない)
- テンプレート由来の Node.js アプリ用ファイル(`src/` / `tsconfig.json` / `vitest.config.ts` / `eslint.config.js`)は `/kickoff` フェーズ1(スタック整合)で削除する。`package.json` はハーネス(husky / lint-staged / secretlint)のために残し、アプリ用の `scripts` と TypeScript 系の devDependencies を整理する

## ディレクトリ詳細

### lib/domain/(ドメイン層)

**役割**: モデルと純粋関数。Flutter・`health`・Riverpod に依存しない

**配置ファイル**:
```
lib/domain/
├── models/
│   ├── date_range.dart           # DateRange
│   ├── daily_steps.dart          # DailySteps
│   ├── sleep_session.dart        # SleepSession
│   ├── daily_sleep.dart          # DailySleep
│   ├── metric_result.dart        # MetricResult / MetricLoaded / MetricPermissionDenied / MetricFailed
│   └── health_status.dart        # PermissionStatus / HealthAvailability / HealthErrorKind / LaunchAction
├── date_range_builder.dart       # buildDateRange / nextDay(機能設計書 A1)
├── sleep_assignment.dart         # assignSleepToDays(A3)
└── formatters.dart               # 日付・歩数・時刻・時間のフォーマット(A4)
```

**依存関係**:
- 依存可能: `dart:core`、`package:intl`、`lib/domain/` 内
- 依存禁止: `package:flutter/*`、`package:health/*`、`package:flutter_riverpod/*`、`lib/` の他のディレクトリ

### lib/application/(アプリケーション層)

**役割**: 7 日分の読み取りの並行実行と `MetricResult` への組み立て

**配置ファイル**:
```
lib/application/
└── weekly_summary_service.dart   # WeeklySummaryService
```

**依存関係**:
- 依存可能: `lib/domain/`、`lib/data/health_repository.dart`(抽象のみ)
- 依存禁止: `package:flutter/*`、`package:health/*`、`lib/data/health_connect_repository.dart`、`lib/presentation/`

### lib/data/(データ層)

**役割**: `HealthRepository` の抽象と Android 実装、MethodChannel のラッパー

**配置ファイル**:
```
lib/data/
├── health_repository.dart            # HealthRepository(抽象)/ HealthReadException
├── health_connect_repository.dart    # HealthConnectRepository(health パッケージで実装)
└── platform_channels.dart            # health_pixcel/health_connect_settings・health_pixcel/launch のラッパー
```

**依存関係**:
- 依存可能: `lib/domain/`、`package:health`、`package:flutter/services.dart`(MethodChannel)
- 依存禁止: `lib/application/`、`lib/presentation/`
- **`package:health` を import してよいのは `lib/data/` 配下だけ**

### lib/presentation/(プレゼンテーション層)

**役割**: 画面・ウィジェット・画面状態・Riverpod プロバイダー

**配置ファイル**:
```
lib/presentation/
├── providers.dart                    # clockProvider / healthRepositoryProvider / weeklySummaryServiceProvider / launchActionProvider
├── dashboard/
│   ├── dashboard_state.dart          # DashboardState と各サブクラス
│   ├── dashboard_controller.dart     # DashboardController(AsyncNotifier)と dashboardControllerProvider
│   ├── dashboard_screen.dart         # DashboardScreen
│   └── widgets/
│       ├── sleep_section.dart        # SleepSection
│       ├── steps_section.dart        # StepsSection
│       └── status_message.dart       # StatusMessage(案内・エラーの共通表示)
└── rationale/
    └── permission_rationale_screen.dart  # PermissionRationaleScreen
```

**依存関係**:
- 依存可能: `lib/domain/`、`lib/application/`、`lib/data/`(`providers.dart` が `HealthConnectRepository` を生成する箇所に限り実装クラスを参照してよい。それ以外は抽象のみ)、`package:flutter/*`、`package:flutter_riverpod`
- 依存禁止: `package:health/*`

### test/(テスト)

**役割**: ユニットテスト・ウィジェットテスト。`lib/` と同じ構造で配置する

**構造**:
```
test/
├── domain/
│   ├── date_range_builder_test.dart
│   ├── sleep_assignment_test.dart
│   └── formatters_test.dart
├── application/
│   └── weekly_summary_service_test.dart
├── presentation/
│   ├── dashboard/
│   │   ├── dashboard_state_test.dart       # isAllEmpty
│   │   ├── dashboard_controller_test.dart
│   │   └── dashboard_screen_test.dart
│   └── rationale/
│       └── permission_rationale_screen_test.dart
├── data/
│   └── health_connect_repository_test.dart  # フェイクの Health で変換規則を検証
├── app_test.dart                     # 起動理由による最初の画面の選択
└── fakes/
    └── fake_health_repository.dart   # テスト用の HealthRepository 実装(本番コードからは参照しない)
```

- `test/data/` は `HealthConnectRepository` の変換規則のテストだけを置く(フェイクの `Health` を注入する。プラグインとヘルスコネクトの実際の挙動は実機確認で担保する。`architecture.md`「テスト戦略」)
- 統合テスト(`integration_test/`)・E2E は MVP では置かない

### android/(Android ネイティブ)

**役割**: Gradle 設定・マニフェスト・Kotlin の MethodChannel 実装

**本プロジェクトで手を入れるファイル**:
```
android/
└── app/
    ├── build.gradle.kts                  # minSdk 34・applicationId
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml       # ヘルスコネクト権限・queries・利用目的の alias・allowBackup=false
        │   └── kotlin/io/github/fuji18/healthpixcel/
        │       └── MainActivity.kt       # FlutterFragmentActivity・MethodChannel 2 本
        ├── release/
        │   └── AndroidManifest.xml       # INTERNET 権限の除去(tools:node="remove")
        ├── debug/AndroidManifest.xml     # Flutter 生成のまま(変更しない)
        └── profile/AndroidManifest.xml   # Flutter 生成のまま(変更しない)
```

- アプリケーション ID / Kotlin パッケージ名 / `namespace`: `io.github.fuji18.healthpixcel`
- それ以外のファイル(Gradle Wrapper 等)は `flutter create` の生成物をそのまま使う

### Flutter プロジェクトの生成手順(最初の実装チケットで 1 回だけ行う)

リポジトリのディレクトリ名が `health-pixcel`(ハイフン)で Dart のパッケージ名に使えないため、名前を明示して生成する。

```bash
flutter create --project-name health_pixcel --org io.github.fuji18 --platforms=android .
```

- `--org io.github.fuji18` + `--project-name health_pixcel` の組み合わせでは、Android のパッケージが `io.github.fuji18.health_pixcel` で生成される。生成後に次を `io.github.fuji18.healthpixcel` に揃える:
  1. `android/app/build.gradle.kts` の `namespace` と `applicationId`
  2. `MainActivity.kt` の `package` 宣言
  3. `MainActivity.kt` の配置ディレクトリ(`kotlin/io/github/fuji18/health_pixcel/` → `kotlin/io/github/fuji18/healthpixcel/`)
- Dart のパッケージ名は `health_pixcel` のまま(`import 'package:health_pixcel/...'`)
- 生成された `lib/main.dart` / `test/widget_test.dart` のサンプルは削除して置き換える
- `flutter create .` は既存の `README.md` / `.gitignore` / `analysis_options.yaml` を上書きしうる。生成直後に `git status` / `git diff` で確認し、次の通り戻す:
  - `README.md`: `git checkout -- README.md` で元に戻す
  - `analysis_options.yaml`: `development-guidelines.md`「analysis_options.yaml」の内容で書き直す
  - `.gitignore`: 元の内容を `git checkout` で戻したうえで、Flutter 用の項目を統合する(下記)
- 生成された `.gitignore` の Flutter 用の項目は、既存の `.gitignore` に統合する(「除外設定」)

### scripts/(アプリの検証スクリプト)

**役割**: アプリ固有の機械検査。ハーネスの `.claude/scripts/` とは別(あちらはテンプレート所有)。プライバシー要件の判定実体のため、`scripts/` と `android/app/src/*/AndroidManifest.xml` は Codex への委託禁止領域とする(`/kickoff` フェーズ4 で `AGENTS.md` §4 のプロジェクト固有パスに登録する)

**配置ファイル**:
```
scripts/
├── check-release-permissions.sh   # リリース APK の権限を許可リストと照合
├── check-layer-imports.sh         # レイヤー間の import 禁止ルールを検査
└── check-privacy.sh               # lib/ 内のログ出力・ファイル入出力・共有の使用を検出
```

すべて POSIX シェルで書き、Git Bash(Windows)と ubuntu(CI)の両方で動かす。

**`check-release-permissions.sh` の仕様**:
- 前提: `flutter build apk --release` 実行済み
- 検査対象は**最終 APK**(`build/app/outputs/flutter-apk/app-release.apk`)。中間生成物のマニフェストは見ない(古い成果物や複数候補による取り違えを避けるため)
- APK が無ければ `exit 2`(「先にリリースビルドを実行してください」)
- 次のいずれかに APK より新しいファイルがあれば `exit 2`(「リリースビルドが古いため再ビルドしてください」): `lib/` / `android/app/src/` / `android/app/build.gradle.kts` / `android/build.gradle.kts` / `android/settings.gradle.kts` / `android/gradle.properties` / `pubspec.yaml` / `pubspec.lock`(`android/.gradle/` `android/local.properties` `build/` はビルド時に更新されるため比較しない)
- `aapt2 dump permissions <apk>` で権限一覧を得る。Android SDK の場所は次の順で解決する:
  1. 環境変数 `ANDROID_HOME`
  2. 環境変数 `ANDROID_SDK_ROOT`
  3. `android/local.properties` の `sdk.dir`(Windows では `C\:\\Users\\...` のように `:` とパス区切りがバックスラッシュでエスケープされているため、エスケープを外してから Git Bash では `cygpath -u` で変換する)
- SDK の `build-tools/` 配下でバージョン名が最も新しいディレクトリの `aapt2`(Windows では `aapt2.exe`)を使う。SDK または `aapt2` が見つからなければ、探した場所を出して `exit 2`
- 判定(`uses-permission` を許可リストと照合):
  - `android.permission.INTERNET` があれば `exit 1`(最重要。メッセージで明示する)
  - 許可リストにない権限があれば、その名前を出して `exit 1`
  - 許可リスト: `android.permission.health.READ_STEPS` / `android.permission.health.READ_SLEEP` / `io.github.fuji18.healthpixcel.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`(androidx が自動で付けるアプリ内部用の権限)
  - すべて許可リスト内なら `exit 0`
- 許可リストはスクリプト冒頭の配列で定義する。変更するときは PRD「セキュリティ・プライバシー」に理由を書いてから変える

**`check-layer-imports.sh` の仕様**(`grep` による検査。違反があれば該当行を出して `exit 1`):
- 外部パッケージ:
  - `package:health/` が `lib/data/` 以外に出現しない
  - `package:flutter/` `package:flutter_riverpod/` が `lib/domain/` に出現しない
  - `package:flutter/` `package:flutter_riverpod/` が `lib/application/` に出現しない
- アプリ内のレイヤー(`package:health_pixcel/<レイヤー>/`):
  - `lib/domain/` が `application/` `data/` `presentation/` を import しない
  - `lib/application/` が `presentation/` を import しない
  - `lib/data/` が `application/` `presentation/` を import しない
  - `health_connect_repository.dart` と `platform_channels.dart` の import が `lib/data/` と `lib/presentation/providers.dart` 以外に出現しない
- 相対 import(`import '../` / `import './`)が `lib/` に出現しない(`always_use_package_imports` と二重に検査する)

**`check-privacy.sh` の仕様**(`lib/` を `grep` で検査。違反があれば該当行を出して `exit 1`):
- ログ出力: `print(` / `debugPrint(` / `dart:developer` の import(`log()` / `Timeline` 等の入口)
- ファイル・入出力: `dart:io`(`lib/data/` の MethodChannel 実装でも使わない)/ `path_provider`
- 共有・クリップボード: `Clipboard` / `share_plus` / `Share.`
- 通信: `package:http/` / `package:dio/` / `HttpClient` / `WebSocket`
- 保存: `package:shared_preferences/` / `package:sqflite/` / `package:hive` / `package:isar`(MVP は保存しない。P1 で保存を導入するときにこの検査を見直す)
- ロガー: `package:logging/` / `package:logger/`
- `toString()` の実装: `lib/domain/` 内の `String toString()`
- 例外: どうしても必要な行は行末に `// privacy-check: allow(<理由>)` を書くと除外される。使ったら PR 本文で理由を説明する

### docs/(ドキュメント)

**配置ドキュメント**:
- `product-requirements.md`: プロダクト要求定義書
- `functional-design.md`: 機能設計書
- `architecture.md`: 技術仕様書
- `repository-structure.md`: リポジトリ構造定義書(本ドキュメント)
- `development-guidelines.md`: 開発ガイドライン
- `glossary.md`: 用語集
- `ui-design-guidelines.md` / `ui-design-request-template.md`: テンプレート同梱の UI 横断ガイド
- `ideas/`: 起点となったアイデアメモ
- `template-dev/`: テンプレート自体の開発記録(アプリ開発では参照しない)

## ファイル配置規則

### ソースファイル

| ファイル種別 | 配置先 | 命名規則 | 例 |
|------------|--------|---------|-----|
| ドメインモデル | `lib/domain/models/` | `snake_case.dart`(1 ファイル 1 モデル。関連する sealed 階層は同一ファイル) | `daily_sleep.dart` |
| ドメインの純粋関数 | `lib/domain/` | 処理内容を表す名詞句 | `sleep_assignment.dart` |
| サービス | `lib/application/` | `*_service.dart` | `weekly_summary_service.dart` |
| リポジトリ | `lib/data/` | `*_repository.dart` | `health_connect_repository.dart` |
| 画面 | `lib/presentation/<機能>/` | `*_screen.dart` | `dashboard_screen.dart` |
| 画面状態・コントローラー | `lib/presentation/<機能>/` | `*_state.dart` / `*_controller.dart` | `dashboard_controller.dart` |
| 画面専用ウィジェット | `lib/presentation/<機能>/widgets/` | ウィジェット名の snake_case | `sleep_section.dart` |
| Kotlin | `android/app/src/main/kotlin/io/github/fuji18/healthpixcel/` | `PascalCase.kt` | `MainActivity.kt` |

### テストファイル

| テスト種別 | 配置先 | 命名規則 | 例 |
|-----------|--------|---------|-----|
| ユニットテスト | `test/` 配下、`lib/` と同じ相対パス | `<対象ファイル名>_test.dart` | `test/domain/sleep_assignment_test.dart` |
| ウィジェットテスト | 同上 | `<画面ファイル名>_test.dart` | `test/presentation/dashboard/dashboard_screen_test.dart` |
| テスト用フェイク | `test/fakes/` | `fake_<対象>.dart` | `fake_health_repository.dart` |

### 設定ファイル

| ファイル | 配置先 | 内容 |
|---|---|---|
| `pubspec.yaml` | ルート | 依存(`health` / `flutter_riverpod` / `intl`)・`flutter_lints` |
| `analysis_options.yaml` | ルート | `include: package:flutter_lints/flutter.yaml` + 追加ルール(`development-guidelines.md`) |
| `package.json` | ルート | ハーネス用。`lint-staged` に `*.dart` → `dart format` を追加する |

## 命名規則

### ディレクトリ名
- **レイヤーディレクトリ**: 単数形・snake_case(`domain` / `application` / `data` / `presentation`)
- **機能ディレクトリ**(`presentation/` 配下): 機能名の snake_case(`dashboard` / `rationale`)

### ファイル名
- Dart: すべて `snake_case.dart`(Dart の公式スタイル。`flutter_lints` の `file_names` で検査される)
- クラス名は `PascalCase`、ファイル名はその snake_case(`DailySleep` → `daily_sleep.dart`)
- Kotlin: `PascalCase.kt`
- シェルスクリプト: `kebab-case.sh`

### テストファイル名
- `<対象ファイル名>_test.dart`(`flutter test` が `_test.dart` を自動検出する)

## 依存関係のルール

### レイヤー間の依存

```
presentation ──→ application ──→ domain
     │                │             ↑
     └──→ data(抽象)←┘             │
           data(実装)───────────────┘
```

**禁止される依存**:
- `domain` → 他のすべての層・Flutter・`health`(❌)
- `application` → `presentation` / `data` の実装クラス / Flutter / `health`(❌)
- `data` → `application` / `presentation`(❌)
- `presentation` → `health`(❌)

検査は `scripts/check-layer-imports.sh` で機械的に行う。

### インポートの書き方

- `lib/` 内の参照は**パッケージ import**(`import 'package:health_pixcel/domain/...';`)で統一する。相対 import は使わない(レイヤー検査の grep を単純に保つため)
- 循環 import を作らない。共通の型は `lib/domain/models/` に置く

## スケーリング戦略

### 機能の追加

| 規模 | 配置方針 | 例 |
|---|---|---|
| 既存画面への項目追加 | 既存ファイルに追加 | 歩数セクションに目標値の表示を追加 |
| 新しい画面 | `lib/presentation/<機能>/` を新設 | P1 のグラフ画面 → `lib/presentation/trends/` |
| 新しいデータ型 | `lib/domain/models/` にモデル追加 + `HealthRepository` にメソッド追加 | P1 の心拍 → `daily_heart_rate.dart` |
| 保存データの導入 | `lib/data/` に `*_store.dart` を追加(方式は P1 着手時に `architecture.md` で決める) | P1 の目標設定 |
| iOS 対応 | `lib/data/apple_health_repository.dart` + `ios/` | P2 |

### ファイルサイズの管理
- 1 ファイル 300 行以下を目安とし、超えたら責務で分割する
- ウィジェットの `build()` が 80 行を超えたら、部分を `widgets/` 配下の別ウィジェットに切り出す

## 特殊ディレクトリ

### .steering/(ステアリングファイル)

**役割**: 作業単位の「今回何をするか」を定義する。**履歴としてコミットして保持する**

```
.steering/
└── [YYYYMMDD]-[task-name]/
    ├── requirements.md
    ├── design.md
    └── tasklist.md
```

**命名規則**: `20261006-show-weekly-steps` 形式

### .claude/ ほか開発ハーネス

テンプレート所有のハーネス(`.claude/` / `.codex/` / `.husky/` / `.harness/` / `.github/workflows/` / `.devcontainer/`)。構成は `README.md` と `CLAUDE.md` を参照。アプリのコードはここに置かない。

## 除外設定

### .gitignore(Flutter 用に追加する項目)

既存の設定(`build/` / `coverage/` / `.idea/` / `.vscode/` 等)に加えて、`flutter create` が生成する `.gitignore` の項目を統合する(重複は生成物の書き方を優先する)。主な項目:

```
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/

# Android
android/.gradle/
android/local.properties
# Android Studio が出力する署名済み APK の置き場(ソースの android/app/src/* とは別)
android/app/debug/
android/app/profile/
android/app/release/
android/**/GeneratedPluginRegistrant.java
*.jks
*.keystore
android/key.properties
```

- `pubspec.lock` は除外しない(コミットする。`architecture.md`「依存関係管理」)
- 署名鍵(`*.jks` / `key.properties`)は必ず除外する

### ツールの除外

- `dart format`: `build/` `.dart_tool/` は自動で対象外
- `prettier`(ハーネス): `.prettierignore` に `lib/` `test/` `android/` `build/` `.dart_tool/` を追加し、Dart・Gradle ファイルを対象外にする
