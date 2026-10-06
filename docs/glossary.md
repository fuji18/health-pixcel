# プロジェクト用語集 (Glossary)

## 概要

health-pixcel のドキュメントとコードで使う用語の定義。**ドキュメントの日本語とコードの英語名はこの表に合わせる**(`development-guidelines.md`「命名規則」)。

**更新日**: 2026-10-06

### 用語対応表(早見表)

| 日本語 | コード上の名前 | 定義の節 |
|---|---|---|
| 直近 7 日 | `DateRange` | ドメイン用語 |
| 日付の区切り | `buildDateRange` / `nextDay` | ドメイン用語 |
| 日別歩数 | `DailySteps` / `steps` | データモデル用語 |
| 途中値 | `isToday` | ドメイン用語 |
| 睡眠セッション | `SleepSession` | データモデル用語 |
| 就寝時刻 / 起床時刻 | `start` / `end` | データモデル用語 |
| 睡眠時間 | `duration` / `total` | ドメイン用語 |
| 帰属日 | `DailySleep.date` | ドメイン用語 |
| 日別睡眠 | `DailySleep` | データモデル用語 |
| 記録なし | `null`(歩数)/ 空の `sessions`(睡眠) | ドメイン用語 |
| 取得結果 | `MetricResult` | ステータス・状態 |
| 権限状態 | `PermissionStatus` | ステータス・状態 |
| 利用可否 | `HealthAvailability` | ステータス・状態 |
| 画面状態 | `DashboardState`(`DashboardUnavailable` / `DashboardNeedsPermission` / `DashboardReady`) | ステータス・状態 |
| 読み込み中 | `AsyncLoading`(Riverpod) | ステータス・状態 |
| 取得結果の各状態 | `MetricLoaded` / `MetricPermissionDenied` / `MetricFailed` | ステータス・状態 |
| データなし案内の判定 | `DashboardReady.isAllEmpty` | ステータス・状態 |
| 起動理由 | `LaunchAction` | ステータス・状態 |
| 7 日分の組み立て | `WeeklySummaryService` | アーキテクチャ用語 |
| 画面の状態管理 | `DashboardController` | アーキテクチャ用語 |
| 現在時刻の注入 | `clockProvider` | アーキテクチャ用語 |
| 案内・エラーの共通表示 | `StatusMessage` | アーキテクチャ用語 |
| 読み取りエラー | `HealthReadException` / `HealthErrorKind` | エラー・例外 |
| ヘルスコネクト用の実装 | `HealthConnectRepository` | アーキテクチャ用語 |
| 起動理由の取得 | `LaunchChannel` / `launchActionProvider` | ステータス・状態 |
| 権限の利用目的画面 | `PermissionRationaleScreen` | 技術用語 |
| 設定画面・ストアを開く操作 | `openSettings` / `openStore`(Controller)、`openPermissionSettings` / `openHealthConnectStore`(Repository) | アーキテクチャ用語 |
| 書き込み元 | `sourceName` / `sourceId`(参照しない) | ドメイン用語 |

## ドメイン用語

### 直近 7 日

**定義**: 今日を含む 7 日間(今日 と その前 6 日)。

**説明**: MVP の表示期間。日付は端末のタイムゾーンにおけるローカル日付で、新しい日が先頭に並ぶ。

**関連用語**: 日付の区切り、帰属日

**使用例**:
- 10/6 に開いた場合、直近 7 日は 10/6〜9/30

**英語表記**: last 7 days(コード: `DateRange`)

### 日付の区切り

**定義**: ローカル時刻の 00:00〜翌 00:00 を 1 日とする規則。

**説明**: 歩数の日別集計の区間は `[その日 00:00, 翌日 00:00)`。日の加減算は `DateTime(y, m, d ± n)` で行う(夏時間対策)。

**関連用語**: 直近 7 日

**英語表記**: day boundary

### 日別歩数

**定義**: 1 日の区間に記録された歩数の合計。

**説明**: ヘルスコネクトの集計(aggregate)で求め、複数の書き込み元の重複除外はヘルスコネクトに任せる。0 は記録なしとして扱う。

**関連用語**: 途中値、記録なし

**英語表記**: daily steps(コード: `DailySteps.steps`)

### 途中値

**定義**: 今日の日別歩数のように、まだ 1 日が終わっていないため増える可能性のある値。

**説明**: 画面では「(途中)」を付けて表示する。

**英語表記**: partial value(コード: `DailySteps.isToday`)

### 睡眠セッション

**定義**: ヘルスコネクトに記録された、1 回分の連続した睡眠(就寝時刻〜起床時刻)。

**説明**: 夜の睡眠と昼寝はそれぞれ別のセッション。終了が開始より前のものは不正として破棄する。

**関連用語**: 就寝時刻、起床時刻、帰属日

**英語表記**: sleep session(コード: `SleepSession`、`health` の `HealthDataType.SLEEP_SESSION`)

### 就寝時刻 / 起床時刻

**定義**: 睡眠セッションの開始時刻 / 終了時刻。

**説明**: ヘルスコネクトの記録上の開始・終了であり、実際に眠りに落ちた時刻・目覚めた時刻とは異なる場合がある。

**英語表記**: bedtime / wake time(コード: `start` / `end`)

### 睡眠時間

**定義**: 睡眠セッションの起床時刻 − 就寝時刻。日別では、その日に帰属するセッションの合計。

**説明**: MVP では途中の覚醒時間を差し引かない。HUAWEIヘルスケアの表示との差異は PRD「未確定事項」で扱う。

**英語表記**: sleep duration(コード: `SleepSession.duration` / `DailySleep.total`)

### 帰属日

**定義**: 睡眠セッションを振り分ける日付。起床時刻のローカル日付。

**説明**: 10/5 23:30〜10/6 6:30 の睡眠の帰属日は 10/6。

**関連用語**: 睡眠セッション、日別睡眠

**英語表記**: attributed date(コード: `DailySleep.date`、関数 `assignSleepToDays`)

### 記録なし

**定義**: その日に表示すべきデータがヘルスコネクトに存在しない状態。

**説明**: 同期遅れ・ウォッチ未装着などで起こる。0 として扱わず、画面では「記録なし」と表示し、行は省略しない。読み取りの失敗(エラー)とは区別する。

**英語表記**: no record(コード: 歩数は `null`、睡眠は空の `sessions`)

### 書き込み元

**定義**: ヘルスコネクトにデータを書き込んだアプリ(Health Sync、将来の Fitbit など)。

**説明**: アプリは書き込み元による分岐を持たない(PRD「データ取得元非依存」)。

**英語表記**: data origin / source(`HealthDataPoint.sourceName` / `sourceId`。参照しない)

### 実機確認

**定義**: Pixel 10 実機でヘルスコネクトとの結合と表示を手動で確かめること。HUAWEIヘルスケアの表示との数値の突き合わせを含む。

**関連ドキュメント**: 機能設計書「テスト戦略 > 実機確認」

## 技術用語

### ヘルスコネクト

**定義**: Android の健康データ共有基盤。アプリ間で健康データを端末内に保存・共有する。

**公式サイト**: https://developer.android.com/health-and-fitness/guides/health-connect

**本プロジェクトでの用途**: 唯一のデータ取得元。Android 14 以降は OS に統合されている。

**英語表記**: Health Connect

### Health Sync

**定義**: HUAWEIヘルスケア等のデータをヘルスコネクトなどへ同期するサードパーティ製 Android アプリ。

**本プロジェクトでの用途**: HUAWEIヘルスケア → ヘルスコネクトの橋渡し。アプリの責務外(アプリは Health Sync に依存しない)。

### HUAWEIヘルスケア

**定義**: HUAWEI のウェアラブル(Band 9)のデータを記録・表示する公式アプリ。

**本プロジェクトでの用途**: データの上流。表示の正確さを確認するときの比較対象。

**英語表記**: HUAWEI Health

### health パッケージ

**定義**: ヘルスコネクトと Appleヘルスケアを同一 API で扱う Flutter プラグイン(carp-dk/carp-health-flutter)。

**公式サイト**: https://pub.dev/packages/health

**本プロジェクトでの用途**: `HealthConnectRepository` の実装。`lib/data/` 以外から import しない。

**バージョン**: ^13.3.2

### Flutter / Dart

**定義**: Google のクロスプラットフォーム UI フレームワークと、その言語。

**公式サイト**: https://flutter.dev / https://dart.dev

**本プロジェクトでの用途**: アプリ全体。将来の iOS 移行時にコードを流用するために採用。

**バージョン**: Flutter 3.47.x / Dart 3.13.x

### Riverpod

**定義**: Flutter の状態管理・依存性注入ライブラリ。

**公式サイト**: https://riverpod.dev

**本プロジェクトでの用途**: `DashboardController`(`AsyncNotifier`)と、リポジトリ・時計の注入。コード生成は使わない。

**バージョン**: `flutter_riverpod` ^3.4.3

### MethodChannel

**定義**: Flutter の Dart コードと Android(Kotlin)/ iOS(Swift)のネイティブコードを呼び合う仕組み。

**本プロジェクトでの用途**: ヘルスコネクトの設定画面を開く(`health_pixcel/health_connect_settings`)、起動インテントの取得(`health_pixcel/launch`)の 2 本だけ。

### マージ済みマニフェスト

**定義**: ビルド時に、アプリ・ビルドタイプ別・依存ライブラリの `AndroidManifest.xml` を統合した最終的なマニフェスト。

**本プロジェクトでの用途**: リリース用マニフェストの `tools:node="remove"` で `INTERNET` を除去する対象。最終的な権限の検査はマージ後の結果が入った最終 APK に対して行う(`scripts/check-release-permissions.sh`)。

**英語表記**: merged manifest

### 権限の利用目的画面

**定義**: ヘルスコネクトの権限画面からリンクされる、アプリが健康データを使う理由を説明する画面。ヘルスコネクトの要件で必須。

**本プロジェクトでの用途**: `PermissionRationaleScreen`。`ACTION_SHOW_PERMISSIONS_RATIONALE` / `VIEW_PERMISSION_USAGE` で起動される。

**英語表記**: permission rationale

## 略語・頭字語

### MVP

**正式名称**: Minimum Viable Product

**本プロジェクトでの使用**: P0 機能(F1〜F4)だけで成立する最初のリリース。

### P0 / P1 / P2

**意味**: 機能の優先度。P0 = MVP に必須、P1 = 重要だが後回し可、P2 = あれば嬉しい。

**本プロジェクトでの使用**: PRD の機能要件。実装対象は P0 のみ(前倒しはユーザー承認制)。

### F1〜F4

**意味**: PRD の P0 機能の番号。F1 = 権限リクエスト、F2 = 歩数一覧、F3 = 睡眠一覧、F4 = 案内表示。

### UC1〜UC4 / A1〜A4

**意味**: 機能設計書のユースケース番号 / アルゴリズム番号。

### KPI

**正式名称**: Key Performance Indicator

**本プロジェクトでの使用**: PRD の成功指標。テレメトリは取らず、本人の確認で測る。

## アーキテクチャ用語

### レイヤー

**定義**: 責務ごとに分けたコードの層。

**本プロジェクトでの適用**:

```
presentation ──→ application ──→ domain
     │                │             ↑
     └──→ data(抽象)←┘             │
           data(実装)───────────────┘
```

| レイヤー | ディレクトリ | 責務 |
|---|---|---|
| プレゼンテーション層 | `lib/presentation/` | 画面・状態管理 |
| アプリケーション層 | `lib/application/` | 7 日分の組み立て |
| ドメイン層 | `lib/domain/` | モデル・純粋関数(純 Dart) |
| データ層 | `lib/data/` | ヘルスコネクトへのアクセス |

**関連ドキュメント**: `architecture.md`「アーキテクチャパターン」、検査は `scripts/check-layer-imports.sh`

### リポジトリ(HealthRepository)

**定義**: 健康データの取得元を抽象化したインターフェース。

**本プロジェクトでの適用**: 上位層は `HealthRepository` にのみ依存する。Android 実装 = `HealthConnectRepository`、テスト = `FakeHealthRepository`、将来の iOS = `AppleHealthRepository`。

**注意**: Git リポジトリとは別の意味。文脈が紛らわしい場合は「HealthRepository」と書く。

### WeeklySummaryService

**定義**: 直近 7 日の歩数・睡眠を `HealthRepository` から読み、`MetricResult` に組み立てるアプリケーション層のサービス。

### DashboardController

**定義**: 画面状態(`AsyncValue<DashboardState>`)を管理する Riverpod の `AsyncNotifier`。読み込み・再読み込み・権限リクエスト・復帰時の再確認を担う。

### clockProvider

**定義**: 現在時刻を返す関数を提供するプロバイダー。テストで「今日」を固定するために差し替える。`DateTime.now()` を直接呼んでよいのはここの既定値だけ。

### 純 Dart

**定義**: Flutter やプラグインに依存せず、`dart:core` 等だけで書かれたコード。

**本プロジェクトでの適用**: ドメイン層。ユニットテストの主対象。

## ステータス・状態

### 画面状態(DashboardState)

| 状態 | 意味 | 遷移条件 |
|---|---|---|
| `AsyncLoading`(値なし) | 読み込み中(`DashboardState` のサブクラスではない) | 起動直後・権限許可直後。引っぱって更新・復帰時は経由しない |
| `DashboardUnavailable` | ヘルスコネクトが使えない | `HealthAvailability` が `available` 以外 |
| `DashboardNeedsPermission` | 歩数・睡眠とも未許可 | 両方 `denied` |
| `DashboardReady` | 少なくとも片方が許可済みで読み込み完了 | 片方以上 `granted` |

**状態遷移図**: 機能設計書「画面遷移図」を参照

### 取得結果(MetricResult)

`DashboardReady.isAllEmpty`(データなし案内の判定)の定義は機能設計書「DashboardState」を参照。

| 状態 | 意味 |
|---|---|
| `MetricLoaded` | 7 日分を読み込めた(記録なしの日を含む) |
| `MetricPermissionDenied` | その種別の権限が未許可 |
| `MetricFailed` | 読み取りに失敗した(`HealthErrorKind` 付き) |

### 権限状態(PermissionStatus)

| 状態 | 意味 |
|---|---|
| `granted` | 読み取り権限が許可済み |
| `denied` | 未許可(未リクエスト・拒否・取り消しを区別しない) |

### 利用可否(HealthAvailability)

| 状態 | 意味 |
|---|---|
| `available` | ヘルスコネクトが利用可能 |
| `notInstalled` | ヘルスコネクトを利用できない(`getHealthConnectSdkStatus()` が `sdkUnavailable` または `null`。minSdk 34 では通常起こらない) |
| `updateRequired` | ヘルスコネクトの更新が必要(`sdkUnavailableProviderUpdateRequired`) |

### 起動理由(LaunchAction)

| 状態 | 意味 |
|---|---|
| `normal` | ランチャー等からの通常起動 |
| `permissionRationale` | ヘルスコネクトの権限画面から「利用目的」を開いて起動された(コールドスタート時のみ判定) |

## データモデル用語

### DailySteps(日別歩数)

**主要フィールド**:
- `date`: 対象日の 00:00(ローカル)
- `steps`: 歩数合計。`null` = 記録なし
- `isToday`: 途中値かどうか

### SleepSession(睡眠セッション)

**主要フィールド**:
- `start`: 就寝時刻(ローカル)
- `end`: 起床時刻(ローカル)
- `duration`: `end − start`

**制約**: `end` は `start` より後

### DailySleep(日別睡眠)

**主要フィールド**:
- `date`: 帰属日(起床日)の 00:00
- `sessions`: その日に帰属するセッション(就寝時刻の昇順。空 = 記録なし)
- `total`: 睡眠時間の合計

**関連エンティティ**: `SleepSession`

## エラー・例外

### HealthReadException

**定義**: データ層が投げる唯一の例外。プラグインの例外を変換したもの。

**フィールド**: `kind`(`HealthErrorKind`)。健康データの値やプラグインのメッセージは含めない。

### HealthErrorKind

| 値 | 意味 | 主な原因 | 画面の表示 |
|---|---|---|---|
| `unavailable` | ヘルスコネクトが使えない | `UnsupportedError` | 利用可否を再確認し、`available` 以外なら利用不可の案内。`available` のままなら `readFailed` と同じ表示 |
| `readFailed` | 読み取りに失敗 | `HealthException` その他 | 「データを読み込めませんでした」+ 再読み込み |
