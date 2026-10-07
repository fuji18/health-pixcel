# 技術仕様書 (Architecture Design Document)

本書は `docs/product-requirements.md` と `docs/functional-design.md` を技術的に実現するための構成・技術選定・制約を定義する。機能設計書で先送りした論点(状態管理・設定画面の開き方・権限の利用目的表示のマニフェスト記述)はここで確定する。

## テクノロジースタック

### 言語・ランタイム

| 技術 | バージョン | 選定理由 |
|------|-----------|----------|
| Flutter | 3.47.x(stable) | 開発機にインストール済みの stable。Android / iOS 共通のコードベースで、将来の iPhone 移行時に UI とロジックを流用できる |
| Dart | 3.13.x(Flutter 同梱) | Flutter の標準言語。null 安全・`sealed class`・レコード型で、状態とデータ欠損(`null` = 記録なし)を型で表せる |
| Android SDK | minSdk 34 / targetSdk・compileSdk は Flutter 既定の最新 | 対象は Pixel 10 のみ。ヘルスコネクトが OS に統合された Android 14(API 34)以上に絞ることで、ヘルスコネクトの別アプリ版への対応を不要にする |
| JDK | 17(Android Studio 同梱) | Android Gradle Plugin の要件 |

### フレームワーク・ライブラリ

| 技術 | バージョン | 用途 | 選定理由 |
|------|-----------|------|----------|
| `health` | ^13.3.2 | ヘルスコネクトの権限確認・リクエスト、歩数集計、睡眠セッションの読み取り | ヘルスコネクトと Appleヘルスケアを同一 API で扱え、iOS 対応時もデータ層の実装差し替えで済む。CARP(デンマーク工科大学)による保守が継続している |
| `flutter_riverpod` | ^3.4.3 | 状態管理・依存性注入 | `HealthRepository` や時計をプロバイダーとして差し替えられ、テストでフェイクを注入しやすい。`AsyncNotifier` で非同期の画面状態を素直に書ける。コード生成(`riverpod_generator`)は**使わない**(ビルド手順と依存を増やさないため) |
| `intl` | ^0.20.2 | 日付(曜日付き)・数値(3 桁区切り)のフォーマット | `health` が既に依存しているパッケージで、新たなパッケージは増えない。ただしアプリから直接 import するため `pubspec.yaml` には明示的に宣言する(`depend_on_referenced_packages`)。バージョンは `flutter pub get` が解決できる範囲(Flutter SDK が固定する版と `health` の要求範囲の共通部分)に合わせる |

### 開発ツール

| 技術 | バージョン | 用途 | 選定理由 |
|------|-----------|------|----------|
| `flutter_lints` | Flutter 既定(最新) | 静的解析ルール | Flutter 公式の推奨ルールセット。`avoid_print` を含み、健康データのログ出力防止にも効く |
| `flutter_test` | SDK 同梱 | ユニット・ウィジェットテスト | 追加依存なし |
| `dart format` | SDK 同梱 | フォーマット | 公式フォーマッタ。設定不要 |
| Android Studio | 最新 stable | 実機デバッグ・APK Analyzer | リリース APK の権限確認に APK Analyzer を使う |

### 検証コマンド

| 目的 | コマンド |
|------|---------|
| 静的解析 | `flutter analyze` |
| フォーマット検査 | `dart format --output=none --set-exit-if-changed .` |
| テスト | `flutter test` |
| リリースビルド | `flutter build apk --release` |
| リリース APK の権限検査 | `bash scripts/check-release-permissions.sh`(最終 APK の権限一覧を許可リストと照合。`INTERNET` が無いこと・ヘルスコネクト権限が `READ_STEPS` / `READ_SLEEP` だけであることを確認。仕様は `repository-structure.md`) |
| レイヤー検査 | `bash scripts/check-layer-imports.sh` |
| プライバシー検査 | `bash scripts/check-privacy.sh`(`lib/` 内のログ出力・ファイル入出力・クリップボード・共有の使用を検出) |

### コマンドの実行環境

| 実行主体 | 環境 | 実行するもの |
|---|---|---|
| 開発者(手元) | Windows 11 + Flutter SDK + Android Studio + Git Bash | 実機確認・`flutter run`・リリースビルドと権限検査(Android SDK が要るもの) |
| Claude Code(司令塔・`implement-ticket` の fork・`/check`) | devcontainer(Linux。Flutter SDK は `post_create.sh` が `~/flutter` に導入。**Android SDK は無い**) | `flutter analyze` / `dart format` / `flutter test` / `scripts/check-layer-imports.sh` / `scripts/check-privacy.sh`。リリースビルドと `check-release-permissions.sh` は実行できないため、CI と開発者(Windows)に任せる |
| Codex 委託 | sandbox(ネットワーク無効) | 依存取得済み(`flutter pub get` 済み)の状態で analyze / format / test のみ。依存追加を伴うチケットは委託しない。プライバシーの判定実体(`scripts/` と `android/app/src/*/AndroidManifest.xml`)は委託禁止領域とし、`/kickoff` フェーズ4 で `AGENTS.md` §4 のプロジェクト固有パスに登録する |
| git hook(lint-staged) | コミットするシェル(devcontainer / Windows) | `*.dart` に `dart format`(`dart` が PATH にあることが前提) |
| CI(GitHub Actions) | ubuntu + `subosito/flutter-action` | 上記すべての検証コマンド + リリースビルド + 権限検査 |

- `.devcontainer/` には Node(ハーネス用)と Flutter SDK を入れる。Android 実機との USB 接続とリリースビルドは Windows 側で行う(2026-10-06 決定。`.steering/20261006-flutter-stack-migration/`)
- `scripts/*.sh` は Git Bash と ubuntu の両方で動く POSIX シェルで書く

## アーキテクチャパターン

### レイヤードアーキテクチャ

```
┌──────────────────────────────────────┐
│ プレゼンテーション層(presentation)   │ ← 画面・ウィジェット・DashboardController
├──────────────────────────────────────┤
│ アプリケーション層(application)      │ ← WeeklySummaryService(7日分の組み立て)
├──────────────────────────────────────┤
│ ドメイン層(domain)                   │ ← モデル・日付計算・睡眠の帰属・フォーマット(純 Dart)
├──────────────────────────────────────┤
│ データ層(data)                       │ ← HealthRepository(抽象)/ HealthConnectRepository(実装)
└──────────────────────────────────────┘
          ↓
   health パッケージ → ヘルスコネクト
```

依存の向き:

```
presentation → application → domain
presentation → data(抽象 HealthRepository のみ。例外: providers.dart は DI の合成箇所として実装クラスを参照してよい)
application  → data(抽象 HealthRepository のみ)
data(実装)  → domain, health パッケージ
domain       → (なし。dart:core と intl のみ)
```

#### プレゼンテーション層
- **責務**: `DashboardState` の表示、ユーザー操作の受付、アプリのライフサイクル(復帰)の検知
- **許可される操作**: `DashboardController` 経由でアプリケーション層・`HealthRepository`(抽象)を呼ぶ。`lib/presentation/providers.dart` に限り、依存の組み立て(DI の合成)のために `HealthConnectRepository` と `LaunchChannel`(`lib/data/platform_channels.dart`)を参照してよい
- **禁止される操作**: `health` パッケージの直接 import(`main.dart` を含む。`Health().configure()` は `HealthConnectRepository` の内部で呼ぶ)、日付範囲や睡眠の帰属の計算

#### アプリケーション層
- **責務**: 日付範囲の決定、リポジトリからの読み取りの並行実行、`MetricResult` への組み立て
- **許可される操作**: `HealthRepository`(抽象)とドメイン層の呼び出し
- **禁止される操作**: Flutter ウィジェットへの依存、`health` パッケージの直接 import

#### ドメイン層
- **責務**: モデル定義と純粋関数(`buildDateRange` / `assignSleepToDays` / フォーマット)
- **許可される操作**: `dart:core`・`intl` の利用
- **禁止される操作**: Flutter(`package:flutter/*`)・`health`・Riverpod への依存。I/O

#### データ層
- **責務**: `HealthRepository` の定義と、`health` パッケージによる Android 実装。プラグイン例外の `HealthReadException` への変換
- **許可される操作**: `health` パッケージ・MethodChannel の利用
- **禁止される操作**: 集計・帰属日判定などのロジック、書き込み元(`sourceName` / `sourceId`)による分岐

`health` パッケージを import してよいのは `lib/data/` 配下だけとする。違反の検出方法は `development-guidelines.md` で定める。

### 状態管理(Riverpod)

| プロバイダー | 種類 | 提供するもの |
|---|---|---|
| `clockProvider` | `Provider<DateTime Function()>` | 現在時刻(既定は `DateTime.now`)。テストで固定値に差し替える |
| `healthRepositoryProvider` | `Provider<HealthRepository>` | 既定は `HealthConnectRepository`。テストでフェイクに差し替える |
| `weeklySummaryServiceProvider` | `Provider<WeeklySummaryService>` | 上記 2 つから生成 |
| `dashboardControllerProvider` | `AsyncNotifierProvider<DashboardController, DashboardState>` | 画面状態。`build()` で初回の読み込み(`_fetch()`)を行う |
| `launchActionProvider` | `FutureProvider<LaunchAction>` | 起動理由。`LaunchChannel.getLaunchAction()` を呼ぶ。`app.dart` が最初の画面を決めるために使う |

- `DashboardController` は `AsyncNotifier<DashboardState>` として実装する。状態遷移の規則(どの操作で `AsyncLoading` に戻すか、`refresh()` で前回値を保つこと、多重実行の抑止)は機能設計書「DashboardController」が正。`AsyncError` は発生させない(例外は `_fetch()` 内で捕捉して `MetricFailed` に変換する)
- `refresh()` は `state` を `AsyncLoading` にせず、`_fetch()` の完了後に `state = AsyncData(...)` で置き換える(全画面のローディングに戻さないため)
- **Riverpod 3 の既定動作の確認**: Riverpod 3 は失敗したプロバイダーの自動リトライと、画面が見えていない間の購読の一時停止を既定で行う。最初の実装チケットで実際の挙動を確認し、`_fetch()` が例外を外に出さない設計と矛盾しないこと(自動リトライが走らないこと)を確かめる。必要なら `ProviderScope(retry: (_, __) => null)` で自動リトライを無効にする
- 画面は `ref.watch(dashboardControllerProvider)` で状態を購読し、操作は `ref.read(dashboardControllerProvider.notifier)` 経由で呼ぶ
- ライフサイクルの復帰検知は `DashboardScreen` で `AppLifecycleListener(onResume: ...)` を使い、`onResumed()` を呼ぶ
- `ProviderScope` は `main.dart` の最上位に 1 つだけ置く
- Notifier の中では依存を各メソッド内で `ref.read` して取得する(リポジトリ・サービス・時計は不変のため `watch` しない)。「`build()` の中で `ref.read` しない」規約はウィジェットの `build()` にだけ適用する

## プラットフォーム統合(Android)

### MainActivity

- `health` パッケージの要件に従い、`MainActivity` は `FlutterFragmentActivity` を継承する(権限リクエストの ActivityResult を受けるため)
- MethodChannel を 2 本実装する: `health_pixcel/health_connect_settings`(下記)と `health_pixcel/launch`(起動理由の取得)
- `launchMode` は Flutter 既定(`singleTop`)のまま変えない。`onNewIntent` は扱わない(コールドスタート時の起動インテントのみ対応。機能設計書「起動理由の取得」)

### 起動理由の取得(`health_pixcel/launch`)

- メソッド: `getLaunchAction`。`onCreate` 時点の `intent.action` を返す
  - `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` または `android.intent.action.VIEW_PERMISSION_USAGE` → 文字列 `"permissionRationale"`
  - それ以外 → `"normal"`
- Dart 側(`lib/data/platform_channels.dart` の `LaunchChannel`)は文字列を `LaunchAction` に変換する。未知の値・例外は `LaunchAction.normal`

### ヘルスコネクトの設定画面を開く(`openPermissionSettings`)

`health` パッケージには設定画面を開く API がないため、最小の MethodChannel を自作する。

- チャネル名: `health_pixcel/health_connect_settings`、メソッド: `open`
- Android 側の処理(Kotlin):
  1. `Intent(HealthConnectManager.ACTION_MANAGE_HEALTH_PERMISSIONS)`(`"android.health.connect.action.MANAGE_HEALTH_PERMISSIONS"`)に `Intent.EXTRA_PACKAGE_NAME = packageName` を付けて `startActivity` する(このアプリの権限画面が直接開く)
  2. 1 が `ActivityNotFoundException`(または `SecurityException`)を投げたら、`Intent(HealthConnectManager.ACTION_HEALTH_HOME_SETTINGS)`(`"android.health.connect.action.HEALTH_HOME_SETTINGS"`)を `startActivity` する(ヘルスコネクトのホーム)
  3. 2 も例外を投げたら `false` を返す。成功したら `true` を返す。Dart 側は `false` のとき「ヘルスコネクトを開けませんでした」と表示する
- **事前に `resolveActivity` / `queryIntentActivities` で解決可能か確認しない**。Android 11 以降のパッケージ可視性の制限により、`<queries>` に宣言していない Intent は解決結果が常に空になるため。`startActivity` を直接呼んで例外で判定する(`startActivity` 自体は可視性の制限を受けない)
- `HealthConnectManager` の定数は API 34 で追加されたもので、minSdk 34 のため直接参照してよい
- 追加の依存パッケージ(`android_intent_plus` 等)は使わない。依存を増やさないため

### AndroidManifest の構成

**`android/app/src/main/AndroidManifest.xml`(全ビルド共通)**:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ヘルスコネクト: 読み取り権限のみ(PRD F1) -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>

    <!-- ヘルスコネクトの状態確認(getSdkStatus)と権限の利用目的表示。health パッケージの README の指定どおり -->
    <queries>
        <package android:name="com.google.android.apps.healthdata"/>
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
        </intent>
    </queries>

    <application ...>
        <activity android:name=".MainActivity" ...>
            <intent-filter>(LAUNCHER)</intent-filter>
            <!-- 権限の利用目的(androidx 版ヘルスコネクトの action。health パッケージの README の指定どおり残す。Android 14+ では下の alias が使われる) -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
            </intent-filter>
        </activity>

        <!-- Android 14+: ヘルスコネクトの権限画面の「利用目的」リンク先 -->
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
            </intent-filter>
        </activity-alias>
    </application>
</manifest>
```

- 利用目的のインテントで起動された場合、`MainActivity` は起動インテントの action を MethodChannel(`health_pixcel/launch` の `getLaunchAction`)で Dart に渡し、Dart 側は `PermissionRationaleScreen` を最初の画面として表示する
- `ACTIVITY_RECOGNITION` は宣言しない。`health` パッケージの README ではステップ取得に必要とされているが、これは Google Fit 時代の要件であり、ヘルスコネクト経由の読み取りには `READ_STEPS` のみが必要と想定する。**最初の実装チケットで実機確認し**、必要だった場合は宣言を追加して PRD「セキュリティ・プライバシー」に理由を追記する(`check-release-permissions.sh` の許可リストも同時に更新する)

### 最初の実装チケットで確認する事項

設計時点では資料ベースで決めており、実物で確かめていないもの。確認結果が設計と違えば、該当ドキュメントを更新してから実装を進める。

| 対象 | 確認すること |
|---|---|
| `health` 13 | `getHealthConnectSdkStatus()` の戻り値の enum 名 / `getTotalStepsInInterval` が記録なしの区間で `0` と `null` のどちらを返すか / `Health().configure()` の要否 / Android で `hasPermissions` が `READ` に対して `true`/`false` を返すこと / プラグイン自身のマニフェストが追加する権限(`ACTIVITY_RECOGNITION` 等) |
| Riverpod 3 | 自動リトライ・購読の一時停止の既定動作(上記「状態管理」) / `AsyncNotifier` の `state` の型と、値を保ったまま更新する書き方 |
| ヘルスコネクト | `ACTIVITY_RECOGNITION` なしで歩数が読めること / `MANAGE_HEALTH_PERMISSIONS` でこのアプリの権限画面が開くこと |
| `getHealthDataFromTypes(SLEEP_SESSION)` | 読み取り区間の開始より前に始まり区間内に終わるセッションが返るか(区間と重なるものが返るか、区間に収まるものだけか)。返る場合、機能設計書 A3 の「区間開始より前に始まるセッションは対象外」の注記を「返る」に改める |

**確認結果(#6、`health` 13.3.2 のソースで確認。実機は未確認)**:

| 項目 | 結果 | 設計への反映 |
|---|---|---|
| `getHealthConnectSdkStatus()` の enum 名 | `sdkUnavailable` / `sdkUnavailableProviderUpdateRequired` / `sdkAvailable`。ネイティブ呼び出しが失敗すると例外を握りつぶして `null` を返す | 設計どおり |
| `getTotalStepsInInterval` の記録なし | 集計結果が無いと `0` を返す。ネイティブ側の例外は握りつぶして `null` を返す | **変更**: `0` → 記録なし、`null` → `readFailed`(機能設計書の表・A2) |
| `Health().configure()` | 端末 ID(`deviceId`)を取得するだけ。読み取り自体には不要だが API 上「使用前に呼ぶ」とされている | 設計どおり 1 回だけ呼ぶ |
| `hasPermissions`(Android, `READ`) | 付与済み権限の `containsAll` を `true`/`false` で返す(`null` は iOS 向け) | 設計どおり |
| プラグイン自身のマニフェスト | 空(権限を追加しない)。推移的依存の権限はリリースビルドの権限検査(CI)で確認する | 変更なし |
| `installHealthConnect()` | ネイティブ側の失敗を握りつぶす(`void`) | `openHealthConnectStore` が `false` になるのは Dart 側の例外のときだけ(機能設計書に注記) |
| `getTotalStepsInInterval` の利用可否検査 | 他の読み取り API と違い `UnsupportedError` を投げない(利用不可時はネイティブ側の例外 → `null` → `readFailed`) | 変更なし(読み込み後の利用可否の再確認は #7 の `_fetch()` が行う) |

実機での確認が必要な残り(`ACTIVITY_RECOGNITION` なしで歩数が読めること / `MANAGE_HEALTH_PERMISSIONS` で権限画面が開くこと / 睡眠セッションの区間の扱い)は #10 の実機検証で行う。

**`android/app/src/release/AndroidManifest.xml`(リリースビルドのみ)**:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">
    <!-- 依存パッケージ経由で混入した INTERNET 権限もマージ時に除去する(PRD 最重要要件) -->
    <uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>
</manifest>
```

- `debug` / `profile` のマニフェスト(Flutter が生成する `INTERNET` 宣言)は変更しない。ホットリロード・DevTools に必要なため
- ビルドタイプ別マニフェストはメインより優先度が高いため、`tools:node="remove"` がライブラリ由来の宣言にも効く

## データ永続化戦略

### ストレージ方式

| データ種別 | ストレージ | フォーマット | 理由 |
|-----------|----------|-------------|------|
| 歩数・睡眠(健康データ) | 保存しない(毎回ヘルスコネクトから読む) | — | PRD: MVP は保存しない。端末内の保存箇所を増やさない |
| 画面状態 | メモリ(Riverpod) | Dart オブジェクト | アプリ終了で破棄してよい |

### バックアップ戦略

- アプリは保存データを持たないため、バックアップ対象はない。健康データの原本はヘルスコネクト(およびその上流の HUAWEIヘルスケア)にある
- Android の自動バックアップによるアプリデータのクラウド送信を防ぐため、`AndroidManifest.xml` の `<application>` に `android:allowBackup="false"` を設定する(P1 で保存を導入したときにも外部へ出ないようにするため、MVP から設定しておく)

### P1 以降で保存が必要になった場合

- 保存先はアプリ専用領域(`getApplicationSupportDirectory()` 配下または SQLite)に限定する
- 方式の選定は P1(目標設定)着手時に行い、本書に追記する

## パフォーマンス要件

### レスポンスタイム

| 操作 | 目標時間 | 測定環境 | 測定方法 |
|------|---------|---------|---------|
| コールドスタートから 7 日分の表示完了 | 3 秒以内 | Pixel 10 実機・リリースビルド・権限許可済み | 手動計測(ストップウォッチ)。3 回の中央値 |
| 引っぱって更新から表示更新 | 2 秒以内 | 同上 | 同上 |

- ヘルスコネクトへの問い合わせは 1 回の表示につき最大 8 回(歩数 7 回 + 睡眠 1 回)で、並行に実行する(機能設計書「パフォーマンス最適化」)

### リソース使用量

| リソース | 上限 | 理由 |
|---------|------|------|
| メモリ | 特に制約を設けない(Flutter の最小構成相当) | 扱うデータが 7 日分(歩数 7 件 + 睡眠セッション十数件)と小さい |
| ディスク | アプリ本体のみ(データ保存なし) | 保存しない方針 |
| リリース APK サイズ | 目安 30MB 以下 | 個人利用のため厳密な制約ではない。依存追加時に急増していないかの目安 |

## セキュリティアーキテクチャ

### データ保護

| 対策 | 実現方法 | 検証方法 |
|---|---|---|
| 外部送信の不能化 | リリースマニフェストで `INTERNET` を除去(上記) | リリースビルドごとに `scripts/check-release-permissions.sh` と APK Analyzer で確認 |
| 最小権限 | ヘルスコネクトは `READ_STEPS` / `READ_SLEEP` のみ宣言。書き込み権限なし | `scripts/check-release-permissions.sh`(許可リスト照合) |
| クラウドバックアップの遮断 | `android:allowBackup="false"` | マニフェスト確認 |
| ログへの非出力 | 健康データの値をログ関数に渡さない。ドメインモデルに `toString()` を実装しない | `avoid_print`(`print` のみ検出)+ `scripts/check-privacy.sh`(`debugPrint` / `dart:developer` 等を検出)+ レビュー + 実機での logcat 確認 |
| 保存・共有の禁止 | ファイル書き出し・共有・クリップボードの実装をしない | `scripts/check-privacy.sh`(`dart:io` / `Clipboard` / 共有系パッケージを検出)+ レビュー |
| 暗号化 | 対象なし(保存データがない) | — |

### 入力検証

- ユーザーの入力項目はない(MVP)
- 外部入力はヘルスコネクトからのデータのみ。`dateTo <= dateFrom` の睡眠セッションは破棄し、歩数の `null` / `0` は記録なしとして扱う(機能設計書 A2 / A3)

### エラーハンドリング

- プラグイン例外は `HealthConnectRepository` で `HealthReadException(kind)` に変換し、元の例外メッセージを画面にもログにも出さない
- 画面には固定の文言だけを表示する(機能設計書「状態別の表示」)

### 依存パッケージの審査

- 新しい依存を追加するときは、ネットワーク通信・アナリティクス・クラッシュレポート SDK を含まないことを pub.dev のページとソースで確認する
- 追加後は必ずリリースビルドで INTERNET 権限の不在を確認する(除去されていても、通信を前提とするパッケージは機能しないため採用しない)

## スケーラビリティ設計

### データ増加への対応

- **想定データ量**: MVP は 7 日分固定。P1 の月表示で最大 31 日分(歩数 31 回の集計 + 睡眠 1 回のクエリ)
- **パフォーマンス劣化対策**: 月表示では歩数の日別集計を `health` の集計 API(区間ごと)で取得し、生データの全件取得は行わない
- **アーカイブ戦略**: 保存しないため不要

### 機能拡張性

| 拡張(PRD) | 拡張ポイント |
|---|---|
| P1 心拍・体重・運動記録 | `HealthRepository` に読み取りメソッドを追加し、マニフェストに対応する `READ_*` 権限を追加する |
| P1 週・月の期間切り替え | `buildDateRange` を日数を引数に取る形へ一般化する |
| P1 グラフ | プレゼンテーション層にウィジェットを追加。ライブラリは着手時に選定(ネットワーク通信を含まないこと) |
| P1 目標設定 | 初めての保存データ。「P1 以降で保存が必要になった場合」に従う |
| P2 睡眠ステージ | `health` の `SLEEP_DEEP` / `SLEEP_REM` 等を `HealthRepository` 経由で読む。Health Sync 経由で入るかの検証が先 |
| P2 iOS 対応 | `AppleHealthRepository` を追加し、`healthRepositoryProvider` をプラットフォームで切り替える。上位層は変更しない(下の注記 2 を除く) |

**P2 iOS 対応の注記**:

1. **プラットフォーム固有コード(Kotlin の MethodChannel)は移植対象ではない**。`openPermissionSettings` の Kotlin 実装を呼ぶのは `HealthConnectRepository` だけで、iOS では `AppleHealthRepository` 側に別実装を書く。iOS には特定アプリのヘルスケア権限画面を直接開く公開 API がないため、`url_launcher` で設定アプリ(`app-settings:`)を開き、ユーザーに「ヘルスケア」→ 本アプリの順に操作してもらう案内を出す想定(Swift は不要の見込み)。起動インテントの取得(`getLaunchAction`)は iOS では常に「該当なし」を返す
2. **iOS(HealthKit)は読み取り権限の許可状態をアプリに開示しない**(`hasPermissions` が `null` を返す)。MVP の「片方だけ未許可ならそのセクションに案内」(機能設計書 UC3 / F4)は iOS では判定できないため、iOS では権限状態の分岐をやめ、「7 日間記録なしの場合は、権限またはデータのいずれかに問題がある」旨の案内に統合する。`HealthRepository.checkPermissions()` の戻り値に「不明(unknown)」を追加し、`DashboardController` の分岐を拡張する必要がある(iOS 対応着手時に機能設計書を更新する)

## テスト戦略

### ユニットテスト
- **フレームワーク**: `flutter_test`
- **対象**: ドメイン層の純粋関数、`WeeklySummaryService`、`DashboardController`(`ProviderContainer` に `healthRepositoryProvider` / `clockProvider` のフェイクを override して実行)
- **カバレッジの目安**: ドメイン層・アプリケーション層で 90% 程度(`flutter test --coverage` で `coverage/lcov.info` を出し、必要に応じて確認する。CI のゲートにはしない)。データ層の `HealthConnectRepository` はフェイクの `Health` を注入して**変換規則(記録なし・不正セッションの破棄・例外の変換)だけ**をユニットテストし、プラグインとヘルスコネクトの実際の挙動は実機確認で担保する

### ウィジェットテスト
- **フレームワーク**: `flutter_test`(`ProviderScope(overrides: ...)` でフェイクを注入)
- **対象**: `DashboardScreen` の状態別表示(機能設計書「状態別の表示」の全行)

### 実機確認(E2E 相当)
- **方法**: Pixel 10 に USB デバッグでリリースビルドをインストールして手動で確認する。ヘルスコネクトとの結合は自動テストしない(ヘルスコネクトのテスト用データ投入の仕組みを作るコストが個人利用の利得に見合わないため)
- **シナリオ**: 機能設計書「実機確認」の各項目

## 技術的制約

### 環境要件
- **実行端末**: Android 14 以上(実際の対象は Pixel 10 のみ)
- **前提アプリ**: ヘルスコネクト(OS 統合)、Health Sync(データ書き込み元。アプリの動作要件ではない)
- **開発環境**: Windows 11、Flutter SDK 3.47.x、Android Studio、Pixel 10(USB デバッグ)

### プラットフォーム制約
- ヘルスコネクトは、アプリが初めて権限を得た日より 30 日以上前のデータを既定では読ませない。MVP(7 日)と P1 の月表示(31 日)は範囲内だが、過去のデータを遡る解析(P2)では `READ_HEALTH_DATA_HISTORY` 権限の追加が必要になる
- ヘルスコネクトはアプリがバックグラウンドにある間の読み取りを制限する。読み取りはフォアグラウンドでのみ行う(MVP はバックグラウンド処理を持たない)
- 権限ダイアログは 2 回拒否されると表示されなくなる。設定画面を開く導線で回避する(機能設計書「状態別の表示」)

### セキュリティ制約
- リリースビルドは `INTERNET` 権限なし。ネットワークを使う機能(クラッシュレポート、リモート設定、フォントのダウンロード等)は採用できない。フォントは端末標準を使う(`google_fonts` 等の実行時ダウンロードを使わない)
- 検証コマンドをどの環境で誰が実行するかは「コマンドの実行環境」の表に従う

## 依存関係管理

| ライブラリ | 用途 | バージョン管理方針 |
|-----------|------|-------------------|
| `health` | ヘルスコネクト | `^` 指定。ただし**メジャー更新は実機確認とリリースマニフェストの INTERNET 検査を通してから**取り込む(過去にメジャー更新で API と Android 要件が変わっているため) |
| `flutter_riverpod` | 状態管理 | `^` 指定(マイナー更新は自動) |
| `intl` | フォーマット | `health` の要求範囲に合わせる(`^0.20.2`) |
| `flutter_lints` | 静的解析 | `^` 指定(dev_dependencies) |

- `pubspec.lock` はリポジトリにコミットする(アプリのため。再現可能なビルドを優先する)
- 依存の更新は `flutter pub outdated` で確認し、1 パッケージずつ更新して検証コマンドを通す
