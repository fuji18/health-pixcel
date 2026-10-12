# 機能設計書 (Functional Design Document)

本書は `docs/product-requirements.md`(PRD)の **P0(F1〜F4)** を実現する方法を定義する。P1/P2 は拡張ポイントのみ示し、設計は行わない。

## システム構成図

```mermaid
graph TB
    User[ユーザー]

    subgraph App[health-pixcel(Flutter)]
        UI[プレゼンテーション層<br/>画面・ウィジェット]
        Ctrl[DashboardController<br/>画面状態の管理]
        Svc[WeeklySummaryService<br/>7日分の集計]
        Domain[ドメイン層<br/>モデル・日付計算(純 Dart)]
        RepoIF[HealthRepository<br/>抽象インターフェース]
        RepoHC[HealthConnectRepository<br/>Android 実装]
    end

    Pkg[health パッケージ]
    HC[(ヘルスコネクト)]
    HS[Health Sync 等の書き込み元]

    User --> UI
    UI --> Ctrl
    Ctrl --> Svc
    Ctrl --> RepoIF
    Svc --> RepoIF
    Svc --> Domain
    RepoHC -. implements .-> RepoIF
    RepoHC --> Pkg
    Pkg --> HC
    HS -. 書き込み(アプリの責務外) .-> HC
```

**設計の要点**:
- ヘルスコネクト(Android 固有)に触れるのは `HealthConnectRepository` だけ。上位層は `HealthRepository` 抽象にのみ依存する(PRD「移植性・保守性」)。iOS 対応時は `AppleHealthRepository` を追加して差し替える
- ドメイン層(日付範囲の計算・睡眠の帰属日判定・フォーマット)は Flutter にも `health` にも依存しない純 Dart とし、ユニットテストの主対象にする
- 書き込み元アプリ(`sourceName` / `sourceId`)による分岐は持たない

## 技術スタック

| 分類 | 技術 | 選定理由 |
|------|------|----------|
| 言語 | Dart | Flutter の標準言語。iOS 移行時にコードを流用できる |
| フレームワーク | Flutter | Android / iOS のクロスプラットフォーム。将来の iPhone 移行に備える |
| ヘルスデータ取得 | `health` パッケージ(carp-dk/carp-health-flutter) | ヘルスコネクトと Appleヘルスケアを同一 API で扱える |
| データ保存 | なし(MVP) | 起動・再読み込みのたびにヘルスコネクトから読む(PRD「セキュリティ・プライバシー」) |
| 状態管理 | `architecture.md` で確定 | 本書ではコントローラーの責務と状態の型だけを定義する |
| 日付・数値フォーマット | `intl` パッケージ | 曜日付き日付・3 桁区切りの表示 |

## データモデル定義

`DashboardState`(プレゼンテーション層の `lib/presentation/dashboard/dashboard_state.dart` に置く)以外はすべてドメイン層の不変クラス。いずれも健康データの値を含むため `toString()` を独自実装しない(誤ってログに出したときに値が出ないようにする。詳細は「セキュリティ考慮事項」)。

### エンティティ: DisplayPeriod(表示期間)

```dart
/// ダッシュボードの表示期間(P1。#20)
enum DisplayPeriod {
  week(7),    // 直近 7 日。起動時の既定(選んだ期間は保存しない)
  month(30);  // 直近 30 日

  final int dayCount;  // 今日を含む日数
}
```

- 「月」は暦の月ではなく**今日を含む直近 30 日**とする(暦の月は月初に 1〜2 日しか出ず、日数も揺れるため。#20 で決定)
- 表示ラベル(「7 日」「30 日」)はドメインに置かず画面が持つ

### エンティティ: DateRange(直近 N 日の範囲)

```dart
/// 直近 N 日(今日を含む)を表す。日付はローカルタイムゾーンの 00:00。N は DisplayPeriod.dayCount(7 / 30)
class DateRange {
  final DateTime now;              // 範囲を決めた時点の現在時刻(ローカル)。読み取りの終端に使う
  final DateTime today;            // 今日の 00:00(ローカル)
  final List<DateTime> days;       // 新しい順の N 日分 [today, today-1, ..., today-(N-1)]

  DateTime get oldestDay;          // today - (N-1) 日
}
```

**制約**:
- `days.length == N`(7 または 30)、要素は時刻 00:00 のローカル `DateTime`
- 1 回の読み込みでは時計を 1 回だけ読み、`today` と読み取りの終端(`now`)を同じ時刻から決める(0 時をまたいだときに「今日」と終端がずれないようにするため)
- 「1 日前」は `DateTime(y, m, d - 1)` で求める(`subtract(Duration(days: 1))` は夏時間をまたぐと 00:00 からずれるため使わない)

### エンティティ: DailySteps(日別歩数)

```dart
class DailySteps {
  final DateTime date;    // 対象日の 00:00(ローカル)
  final int? steps;       // その日の歩数合計。null = 記録なし
  final bool isToday;     // true の場合、表示時点までの途中値
}
```

**制約**:
- `steps` は `null` または 1 以上。取得値が 0 の場合も `null`(記録なし)として扱う(「アルゴリズム設計」参照)

### エンティティ: DailyHeartRate(日別心拍)(#24)

```dart
/// ある区間の心拍の集計値(bpm。整数)
class HeartRateStats {
  final int average;   // 標本の単純平均(四捨五入)
  final int min;
  final int max;
}

class DailyHeartRate {
  final DateTime date;            // 対象日の 00:00(ローカル)
  final HeartRateStats? stats;    // null = 記録なし
  final bool isToday;             // true の場合、表示時点までの値
}
```

- 集計は `summarizeHeartRate(Iterable<num>)`(`lib/domain/heart_rate_summary.dart`)。標本が無ければ `null`
- 対象区間は歩数と同じ(過去日 `[day, 翌日)`、今日 `[today, range.now)`)
- 今日も「(途中)」を付けない(平均・範囲は累積値ではなく、途中でも意味が変わらないため)
- 安静時心拍は扱わない(`READ_RESTING_HEART_RATE` が別に要るため。PRD「セキュリティ・プライバシー」)

### エンティティ: DailyWeight(日別体重)(#25)

```dart
class DailyWeight {
  final DateTime date;     // 対象日の 00:00(ローカル)
  final double? kg;        // その日の最新の記録(kg)。null = 記録なし
  final bool isToday;      // true の場合、表示時点までの値
}
```

- 値は `pickLatestWeight(Iterable<({DateTime at, num kg})>)`(`lib/domain/weight_summary.dart`)で選ぶ。区間内で時刻が最も新しい記録の値。同時刻が複数あれば列挙順で後のもの。記録が無ければ `null`
- 対象区間は歩数と同じ(過去日 `[day, 翌日)`、今日 `[today, range.now)`)
- 記録のない日は「記録なし」。前日以前の値を引き継がない
- 今日も「(途中)」を付けない(最新値は累積値ではないため)
- BMI・体脂肪率・身長は扱わない(別の権限が要るため。PRD「セキュリティ・プライバシー」)

### エンティティ: SleepSession(睡眠セッション)

```dart
class SleepSession {
  final DateTime start;   // 就寝時刻(ローカル)
  final DateTime end;     // 起床時刻(ローカル)

  Duration get duration => end.difference(start);
}
```

**制約**:
- `end` が `start` より後であること。満たさないセッションは取得時に破棄する(PRD「信頼性」: 不完全なデータでクラッシュしない)

### エンティティ: DailySleep(日別睡眠)

```dart
class DailySleep {
  final DateTime date;                 // 帰属日(起床日)の 00:00(ローカル)
  final List<SleepSession> sessions;   // 就寝時刻の昇順。空 = 記録なし

  bool get hasRecord => sessions.isNotEmpty;
  Duration get total;                  // sessions の duration の合計
}
```

### エンティティ: 取得結果と権限状態

```dart
/// 読み取るデータの種別(権限はこの単位で扱う)。#25 体重・#26 運動記録は列挙値を足して広げる
enum HealthMetric { steps, sleep, heartRate, weight }

/// データ種別ごとの権限状態(許可済みの種別の集合)。値で比較できる(順序によらず集合が等しければ ==)
class HealthPermissions {
  final Set<HealthMetric> granted;
  bool isGranted(HealthMetric metric);
  bool get noneGranted;
}

/// ヘルスコネクト自体の利用可否
enum HealthAvailability {
  available,          // 利用可能
  notInstalled,       // 利用不可(minSdk 34 では OS 統合のため通常は起こらない。防御的に扱う)
  updateRequired,     // ヘルスコネクトの更新が必要
}

/// アプリの起動理由(起動インテントの action から決まる)
enum LaunchAction {
  normal,                 // ランチャー等からの通常起動
  permissionRationale,    // ヘルスコネクトの権限画面から「利用目的」を開いた
}

/// 1 データ種別ぶんの取得結果
sealed class MetricResult<T> {}
class MetricLoaded<T> extends MetricResult<T> { final List<T> days; }  // 7 件、新しい順
class MetricPermissionDenied<T> extends MetricResult<T> {}
class MetricFailed<T> extends MetricResult<T> { final HealthErrorKind kind; }

enum HealthErrorKind { unavailable, readFailed }
```

### エンティティ: Goals(目標値)

```dart
class Goals {
  const Goals({this.steps, this.sleepMinutes});
  final int? steps;         // 1 日の歩数の目標。null = 目標なし
  final int? sleepMinutes;  // 1 日の睡眠時間の目標(分)。null = 目標なし
}
```

- 範囲(両端を含む): 歩数 1,000〜100,000 歩 / 睡眠時間 180〜720 分(3〜12 時間)。範囲と入力の解析は `lib/domain/goal_input.dart` が持つ
- `toString()` は実装しない(プライバシー検査)
- 日別の達成判定は `lib/domain/goal_progress.dart` が持つ(A5)

### エンティティ: DashboardState(画面状態)

読み込み中は `DashboardState` のサブクラスではなく、Riverpod の `AsyncLoading` で表す(「DashboardController」参照)。`requestPermissions()` 中の `AsyncLoading` は Riverpod 3 の仕様で前回の値を引き継ぐ(`state = AsyncLoading()` が自動で `copyWithPrevious` される)ため、画面は `hasValue` ではなく `isLoading` で判定する(`when()` の既定 `skipLoadingOnReload: false` で足りる。#7 で確認)。

```dart
sealed class DashboardState {}

/// ヘルスコネクトが使えない(F4)
class DashboardUnavailable extends DashboardState {
  final HealthAvailability availability;   // notInstalled / updateRequired
}

/// すべてのデータ種別が未許可(F4)。初回起動直後もここ
class DashboardNeedsPermission extends DashboardState {}

/// 少なくとも 1 種別が許可済み(F2 / F3 / F4)
class DashboardReady extends DashboardState {
  final DisplayPeriod period;   // 表示期間。range.days.length == period.dayCount
  final DateRange range;
  final MetricResult<DailySteps> steps;
  final MetricResult<DailySleep> sleep;
  final MetricResult<DailyHeartRate> heartRate;   // #24
  final MetricResult<DailyWeight> weight;         // #25

  /// F4 のデータなし案内を出すかどうか
  bool get isAllEmpty;
}
```

**`isAllEmpty` の定義**: 次の 3 条件をすべて満たすとき `true`。
1. `steps` / `sleep` / `heartRate` / `weight` のどれも `MetricFailed` ではない
2. 少なくとも 1 つが `MetricLoaded`
3. `MetricLoaded` であるものはすべて、期間内の全日が記録なし(歩数は `steps == null`、睡眠は `hasRecord == false`、心拍は `stats == null`、体重は `kg == null`)

`MetricPermissionDenied` の種別は判定から除外する(例: 歩数・心拍が未許可、睡眠が期間内の全日とも記録なし → `true`)。

### ER図

```mermaid
erDiagram
    DATE_RANGE ||--|{ DAILY_STEPS : "7件"
    DATE_RANGE ||--|{ DAILY_SLEEP : "7件"
    DAILY_SLEEP ||--o{ SLEEP_SESSION : "0件以上"
    DAILY_STEPS {
        DateTime date
        int steps "nullable"
        bool isToday
    }
    DAILY_SLEEP {
        DateTime date "起床日"
    }
    SLEEP_SESSION {
        DateTime start
        DateTime end
    }
```

永続化はしないため、これらはメモリ上の値オブジェクトであり ID を持たない。

## コンポーネント設計

### HealthRepository(データ層・抽象)

**責務**:
- ヘルスデータ基盤の利用可否・権限状態の確認と権限リクエスト
- 指定期間の歩数合計・睡眠セッションの読み取り
- プラットフォーム固有の例外を `HealthErrorKind` に変換する(上位層にプラグインの例外型を漏らさない)

**インターフェース**:
```dart
abstract interface class HealthRepository {
  Future<HealthAvailability> checkAvailability();

  /// データ種別ごとの権限状態
  Future<HealthPermissions> checkPermissions();

  /// 歩数・睡眠・心拍・体重の READ 権限をまとめてリクエストし、リクエスト後の状態を返す
  Future<HealthPermissions> requestPermissions();

  /// ヘルスコネクトのアプリ権限設定画面を開く(ダイアログが出なくなった場合の逃げ道)。
  /// 開けなかった場合は false を返す
  Future<bool> openPermissionSettings();

  /// ヘルスコネクトの入手・更新ページ(Play ストア)を開く。開けなかった場合は false を返す
  Future<bool> openHealthConnectStore();

  /// [start, end) の歩数合計。記録なしは null。失敗時は HealthReadException を投げる
  Future<int?> readTotalSteps(DateTime start, DateTime end);

  /// [start, end) と重なる睡眠セッション。失敗時は HealthReadException を投げる
  Future<List<SleepSession>> readSleepSessions(DateTime start, DateTime end);

  /// [start, end) の心拍の集計値。記録なしは null。失敗時は HealthReadException を投げる(#24)
  Future<HeartRateStats?> readHeartRate(DateTime start, DateTime end);

  /// [start, end) の最新の体重(kg)。記録なしは null。失敗時は HealthReadException を投げる(#25)
  Future<double?> readLatestWeight(DateTime start, DateTime end);
}

class HealthReadException implements Exception {
  const HealthReadException(this.kind);
  final HealthErrorKind kind;   // メッセージに健康データの値を含めない
}
```

**依存関係**: なし(抽象)

### HealthConnectRepository(データ層・Android 実装)

**責務**: `HealthRepository` を `health` パッケージで実装する

| メソッド | 使う `health` API | 補足 |
|---|---|---|
| `checkAvailability` | `getHealthConnectSdkStatus()` | `sdkAvailable` → `available`、`sdkUnavailableProviderUpdateRequired` → `updateRequired`、それ以外(`sdkUnavailable`)・`null` → `notInstalled` |
| `checkPermissions` | `hasPermissions([STEPS])` / `hasPermissions([SLEEP_SESSION])` / `hasPermissions([HEART_RATE])` / `hasPermissions([WEIGHT])`(各 `READ`) | 種別ごとに個別に呼ぶ(一部だけ許可を判別するため)。`true` の種別だけを `HealthPermissions.granted` に入れる(`null`/`false` は未許可)。種別と `HealthDataType` の対応はクラス内の定数 `_types` に 1 か所で持つ |
| `requestPermissions` | `requestAuthorization([STEPS, SLEEP_SESSION, HEART_RATE, WEIGHT], permissions: [READ × 4])` | 全種別をまとめてリクエストする(ヘルスコネクトの画面は 1 回で済み、許可済みの種別は許可済みとして表示される)。戻り値の bool は使わず、直後に `checkPermissions()` を呼んで種別ごとの状態を返す |
| `openPermissionSettings` | 自作 MethodChannel `health_pixcel/health_connect_settings` の `open` | Kotlin 側の手順は `architecture.md`「ヘルスコネクトの設定画面を開く」 |
| `openHealthConnectStore` | `installHealthConnect()` | Play ストアのヘルスコネクトのページを開く(更新にも使う)。例外が出たら `false` を返す(`health` 13.3.2 はネイティブ側の失敗を握りつぶすため、実際に `false` になるのは Dart 側で例外が出たときだけ) |
| `readTotalSteps` | `getTotalStepsInInterval(start, end)` | ヘルスコネクトの集計 API を使うため、複数ソースの重複除外はヘルスコネクト側で行われる。`0` は記録なしとして `null` を返す。`null` は `HealthReadException(readFailed)` を投げる(`health` 13.3.2 はネイティブ側の例外を握りつぶして `null` を返し、記録なしの区間では `0` を返すため。#6 でソース確認) |
| `readSleepSessions` | `getHealthDataFromTypes(types: [SLEEP_SESSION], startTime, endTime)` | 各 `HealthDataPoint` の `dateFrom`/`dateTo` を `toLocal()` して `SleepSession` に変換。`dateTo <= dateFrom` は破棄 |
| `readHeartRate` | `getHealthDataFromTypes(types: [HEART_RATE], startTime, endTime)` | `HeartRateRecord` の標本 1 つが 1 データ点になる。レコードは区間をまたぐことがあり、ヘルスコネクトは区間と重なるレコードを丸ごと返すため、**標本の時刻(`dateFrom`)が `[start, end)` に入るものだけ**を `summarizeHeartRate` に渡す。`NumericHealthValue` 以外は無視。複数ソースの重複は `health` の `removeDuplicates` に任せる(ソースが異なれば両方数える。平均への影響は小さいため許容) |
| `readLatestWeight` | `getHealthDataFromTypes(types: [WEIGHT], startTime, endTime)` | `WeightRecord` 1 件が 1 データ点(瞬間の記録。単位は `health` の既定の kg)。心拍と同じく**時刻(`dateFrom`)が `[start, end)` に入るものだけ**を `pickLatestWeight` に渡す。`NumericHealthValue` 以外は無視(#25) |

- `UnsupportedError`(ヘルスコネクト利用不可)→ `HealthReadException(unavailable)`、`HealthException` などその他の例外 → `HealthReadException(readFailed)`。この変換は `checkAvailability` / `checkPermissions` / `requestPermissions` / `readTotalSteps` / `readSleepSessions` / `readHeartRate` / `readLatestWeight` のすべてに適用する(上位層に `health` の例外型を漏らさない)
- `Health` はコンストラクタ引数で差し替えられるようにする(`HealthConnectRepository({Health? health})`)。ユニットテストでフェイクを注入し、上記の変換を検証するため
- 例外を変換するとき、元の例外メッセージやデータ点をログに出さない
- `Health().configure()` は `HealthConnectRepository` の内部で 1 回だけ呼ぶ: フィールド `late final Future<void> _configured = _health.configure();` を持ち、各公開メソッドの先頭で `await _configured;` する(`late final` のため初回アクセス時に 1 度だけ実行される)。`main.dart` は `health` を import しない

**依存関係**: `health` パッケージ

### WeeklySummaryService(アプリケーション層)

**責務**:
- 今日の日付と日数(7 / 30)から `DateRange` を作る
- リポジトリから期間の日数分を読み、`DailySteps` / `DailySleep` / `DailyHeartRate` / `DailyWeight` の N 件リストに組み立てる
- データ種別ごとに**独立に**取得し、1 種別の失敗が他の種別の表示を妨げないようにする

**インターフェース**:
```dart
class WeeklySummaryService {
  WeeklySummaryService(this._repository, this._clock);

  final HealthRepository _repository;
  final DateTime Function() _clock;   // テストで「今日」を固定するため注入する

  /// 時計を 1 回だけ読んで直近 dayCount 日の DateRange を作る
  DateRange currentRange({int dayCount = 7});

  /// 読み取りの終端には range.now を使い、時計を読み直さない
  Future<MetricResult<DailySteps>> loadSteps(DateRange range);
  Future<MetricResult<DailySleep>> loadSleep(DateRange range);

  /// loadSteps と同じ形で 1 日ずつ並行に readHeartRate を呼ぶ。1 日でも失敗したら MetricFailed(#24)
  Future<MetricResult<DailyHeartRate>> loadHeartRate(DateRange range);

  /// loadHeartRate と同じ形で readLatestWeight を呼ぶ(#25)
  Future<MetricResult<DailyWeight>> loadWeight(DateRange range);
}
```

- `HealthReadException(kind)` は `MetricFailed(kind)` に変換して返す(`unavailable` もそのまま返し、画面状態への反映は `DashboardController` が行う)

**依存関係**: `HealthRepository`、ドメイン層の関数(`buildDateRange` / `assignSleepToDays`)

### GoalRepository / SharedPreferencesGoalRepository(データ層)

**責務**: 目標値の保存先。`GoalRepository`(抽象)は `Future<Goals> load()` と `Future<void> save(Goals)` を持ち、失敗は内容を持たない `GoalStorageException` に変換する。`save` は null の項目の保存済みの値を削除する。

- `SharedPreferencesGoalRepository` は `shared_preferences` の `SharedPreferencesAsync` で `goal.steps` / `goal.sleep_minutes`(int)を保存する。`SharedPreferencesAsync` は最初の使用時に生成する。`load()` は範囲外の保存値を null として扱う
- `package:shared_preferences/` の import はこのファイルの 1 行だけで、行末に `privacy-check: allow` を付ける

### GoalsController(プレゼンテーション層・状態管理)

**責務**: `AsyncNotifier<Goals>`(`goalsControllerProvider`)。`build()` で `load()` し、`GoalStorageException` なら `Goals()`(目標なし)にする。`save(Goals)` は成功なら状態を置き換えて `true`、`GoalStorageException` なら状態を変えず `false` を返す。

**依存関係**: `GoalRepository`

### DashboardController(プレゼンテーション層・状態管理)

**責務**:
- 起動時・再読み込み時・表示期間の切り替え時の状態遷移を管理し、画面状態を公開する
- 表示期間(`DisplayPeriod`)を保持する(起動時は `week`。保存しない)
- 権限状態に応じて、許可済みの種別だけを `WeeklySummaryService` で読み込む
- 権限リクエストの起動と、許可直後の再読み込み(F1: 再起動不要)
- アプリがフォアグラウンドに戻ったとき(設定画面から戻った場合など)に権限状態を再確認する

**インターフェース**(Riverpod の `AsyncNotifier<DashboardState>`。公開される `state` の型は `AsyncValue<DashboardState>`):
```dart
class DashboardController extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build();      // 初回読み込み(= _fetch())

  Future<void> refresh();              // 引っぱって更新・「再読み込み」操作
  Future<void> requestPermissions();   // 「権限を許可する」操作
  Future<bool> openSettings();         // 「ヘルスコネクトの設定を開く」操作。開けなかったら false
  Future<bool> openStore();            // 「ヘルスコネクトを更新する」操作。開けなかったら false
  Future<void> onResumed();            // フォアグラウンド復帰時
  Future<void> selectPeriod(DisplayPeriod period);  // 「7 日 / 30 日」の切り替え操作

  // private
  Future<DashboardState> _fetch({bool force = false});  // 利用可否 → 権限 → 読み込み → DashboardState を組み立てる
  Future<DashboardState>? _inFlight;   // 実行中の _fetch(多重実行の抑止)
  bool _requestingPermission = false;  // 権限ダイアログ表示中
  _Snapshot? _lastSnapshot;            // 直近の _fetch が最終的に採用した利用可否・権限状態
  DisplayPeriod _period = DisplayPeriod.week;  // 表示期間
  bool _isCurrent(DashboardState s);   // s が DashboardReady 以外か、period が _period と一致するか
}

/// 利用可否が available 以外のときは権限を取得しないため null
typedef _Snapshot = ({
  HealthAvailability availability,
  HealthPermissions? permissions,   // 値の等価性を持つため、復帰時の比較(!=)がそのまま使える
});
```

**依存の取得**: `HealthRepository` / `WeeklySummaryService` は、各メソッドの中で `ref.read(healthRepositoryProvider)` / `ref.read(weeklySummaryServiceProvider)` で取得する(これらは不変のため `watch` しない。`watch` すると依存の再生成で Notifier が作り直され、`_inFlight` などの private 状態が失われる)。

**状態遷移の規則**:

| 操作 | `state` の変化 |
|---|---|
| `build()`(初回) | `AsyncLoading`(値なし)→ `AsyncData(_fetch() の結果)` |
| `refresh()` | **前回の値を表示したまま** `_fetch()` を実行し、完了したら `AsyncData(新しい値)` に置き換える(全画面のローディングには戻さない)。引っぱって更新の `RefreshIndicator` はこの Future の完了を待つ |
| `requestPermissions()` | `_requestingPermission = true` → `repository.requestPermissions()` を `try` / `finally` で囲み、`finally` で必ず `false` に戻す → `AsyncLoading`(値なし)→ `AsyncData(_fetch(force: true) の結果)`。`repository.requestPermissions()` が例外を投げても画面状態はエラーにせず、そのまま `_fetch(force: true)` に進む(権限状態を読み直して表示する) |
| `onResumed()` | `_requestingPermission` が `true` なら何もしない(権限ダイアログから戻った時の復帰は `requestPermissions()` 側で処理するため)。それ以外は現在の利用可否を `checkAvailability()` で取り、`available` のときだけ `checkPermissions()` も呼んで `_Snapshot` を作る。`_lastSnapshot` と異なれば(`_lastSnapshot` が `null` の場合も含む)`refresh()` を呼ぶ。確認中に例外が出たら `refresh()` を呼ぶ |
| `selectPeriod(period)` | `period` が `_period` と同じなら何もしない。異なれば `_period = period` → `AsyncLoading`(値なし)→ `AsyncData(_fetch(force: true) の結果)`。切り替え中は全体のローディングを表示する(前回の値を残すと、選んだ期間と違う日数のリストが見え続けるため) |
| `openSettings()` | `repository.openPermissionSettings()` の結果を返す(例外は `false`。状態は変えない)。`false` なら**画面が** `ScaffoldMessenger` で「ヘルスコネクトを開けませんでした」を表示する(コントローラーは `BuildContext` を持たないため。#7 で変更)。戻ってきたときの反映は `onResumed()` に任せる |
| `openStore()` | `repository.openHealthConnectStore()` の結果を返す(例外は `false`。状態は変えない)。`false` なら画面がスナックバー「Play ストアを開けませんでした」を表示する。戻ってきたときの反映は `onResumed()` に任せる |

**古い期間の結果を捨てる**: `refresh()` / `requestPermissions()` / `selectPeriod()` は、`_fetch` の結果が `_isCurrent` を満たさない(= 期間を変える前に始まった読み込みの `DashboardReady`)とき `state` を更新しない。期間を変えた側(`selectPeriod`)が新しい期間で必ず `_fetch(force: true)` を走らせて `state` を設定するため、捨ててよい(`refresh()` が古い期間の実行中 Future に合流した場合や、`selectPeriod` の連続呼び出しで起こる)。

**`_fetch({force})` の多重実行の扱い**:
- `force == false` で `_inFlight` が実行中 → その Future を返す(合流する。引っぱって更新の連打や復帰の重なり向け)
- `force == true` で `_inFlight` が実行中 → その完了を待ってから(結果は捨てる)新たに実行する(権限リクエスト直後に、許可前に始まった古い読み込み結果を使わないため)
- 新たに実行するときは、その Future を `_inFlight` に入れ、`whenComplete` で「`_inFlight` が自分自身なら `null` に戻す」

**`_fetch()` の本体の手順**(冒頭で `_period` を 1 回だけ読んで `period` とし、以降はそれを使う):
1. `checkAvailability()` が `available` 以外 → `_lastSnapshot = (availability, permissions: null)` として `DashboardUnavailable(availability)` を返す
2. `checkPermissions()` を呼び、`_lastSnapshot = (available, permissions)` に更新する
3. すべて未許可(`noneGranted`)→ `DashboardNeedsPermission` を返す
4. `currentRange(dayCount: period.dayCount)` で範囲を決め、許可済みの種別だけ `loadSteps` / `loadSleep` / `loadHeartRate` / `loadWeight` を並行実行する(未許可の種別は `MetricPermissionDenied`)
5. いずれかが `MetricFailed(unavailable)` なら `checkAvailability()` を再確認する。`available` 以外なら `_lastSnapshot = (availability, permissions: null)` として `DashboardUnavailable(availability)` を返す。`available` のままなら該当する種別を `MetricFailed(readFailed)` に読み替えて次へ進む
6. `DashboardReady(period, range, steps, sleep, heartRate, weight)` を返す
7. 1〜6 のどこで想定外の例外が出ても捕捉し、`_lastSnapshot = null` にしたうえで 全種別を `MetricFailed(readFailed)` にした `DashboardReady` を返す(範囲が未確定なら `currentRange(dayCount: period.dayCount)` で作る。`_lastSnapshot = null` により次の復帰で必ず再読み込みされる)。値をログに出さない

**`_lastSnapshot` の不変条件**: `_fetch()` が値を返した時点で、`_lastSnapshot` はその戻り値を決めたときの利用可否・権限状態と一致している(どの出口から返った場合も)。

`_fetch()` が例外を外に出さないため、`AsyncError` は通常発生しない。万一発生した場合、画面は「データを読み込めませんでした」+「再読み込み」を表示する。

**依存関係**: `HealthRepository`、`WeeklySummaryService`

### 画面・ウィジェット(プレゼンテーション層)

| コンポーネント | 責務 |
|---|---|
| `DashboardScreen` | 唯一の画面。`DashboardState` に応じて以下を出し分ける。`DashboardReady` のときだけリスト先頭に期間の切り替え(`SegmentedButton<DisplayPeriod>`。「7 日」「30 日」)を置く。`goalsControllerProvider` を watch して目標値を各セクションへ渡す(読み込み中・失敗は目標なし扱い)。目標を保存すると `GoalsController` の状態が置き換わり、ヘルスコネクトを読み直さずに即座に再描画される |
| `StepsSection` | `MetricResult<DailySteps>` と歩数の目標(`int?`)を受け取り、推移グラフ(`TrendBarChart`)と期間の日数分(7 / 30 行)の一覧・未許可案内・エラー表示のいずれかを描画。目標があれば見出しの下に「目標 8,000 歩」、グラフに目標ライン、各行に `GoalMark` を出す |
| `SleepSection` | `MetricResult<DailySleep>` と睡眠時間の目標(分。`int?`)を受け取り、同上(「目標 7時間30分」) |
| `HeartRateSection` | `MetricResult<DailyHeartRate>` を受け取り、期間の日数分の一覧・未許可案内・エラー表示のいずれかを描画(グラフ・目標なし)。一覧の上に説明「1 日の平均(最小〜最大)」を出す(#24) |
| `WeightSection` | `MetricResult<DailyWeight>` を受け取り、`HeartRateSection` と同じ構成で描画する(グラフ・目標なし)。一覧の上に説明「その日の最新の記録」を出す(#25) |
| `TrendBarChart` | 日別の値を棒グラフで描く。記録なしの日は棒も下地も描かない。全日記録なしなら代替文言。グラフ全体の要約を Semantics で読ませる。`goalY` があれば目標ラインを引く |
| `GoalMark` | 一覧の行末の達成マーク(A5 の `GoalStatus` を表示)。目標が設定されているときだけ置き、判定しない日は同じ幅の空白にして値の列を揃える |
| `StatusMessage` | 案内・エラーの共通表示(見出し + 説明 + 操作ボタン) |
| `GoalSettingsScreen` | 目標値の設定画面。歩数(1,000〜100,000 歩)と睡眠時間(時間 3〜12・分 0〜59、合計 3 時間〜12 時間)の数値入力欄。空欄で保存すると目標なし。不正な入力は入力欄の下に理由(「数字で入力してください」等)を出して保存しない。保存成功で SnackBar「目標を保存しました」を出して閉じ、失敗は「保存できませんでした」を出して留まる |
| `PermissionRationaleScreen` | 権限の利用目的の説明画面(ヘルスコネクトから「利用目的」を開いたときの表示先。案内画面の「詳しく見る」からも開く) |
| `HealthPixcelApp`(`app.dart`) | `launchActionProvider` を見て最初の画面を決める(`permissionRationale` → `PermissionRationaleScreen`、それ以外 → `DashboardScreen`)。起動理由は同期的に決まるため、判定待ちの画面は無い |

ウィジェットは状態の表示だけを担い、日付計算・フォーマット以外のロジックを持たない。

### 起動理由の取得(LaunchAction)

- `MainActivity` が利用目的のインテントを受けたとき、Flutter の初期ルート `/permission-rationale` を渡す(`architecture.md`「起動理由の取得(初期ルート)」)
- `lib/presentation/providers.dart` の `launchActionProvider`(`Provider<LaunchAction>`)が起動時のルート名を `LaunchAction` に変換する(`/permission-rationale` → `permissionRationale`、それ以外 → `normal`)。画面はこのプロバイダー経由でのみ参照する
- **起動理由は `MainActivity` のインスタンスが生成されたときに決まる**。`launchMode` は `singleTop` だが、ヘルスコネクトは自分の画面の上に `MainActivity` を開くため、アプリが既に起動していても通常は**新しいインスタンス**ができ、利用目的画面が出る想定(「閉じる」でそのインスタンスだけが終了し、ヘルスコネクトの画面に戻る。#10 の実機確認で確かめる)
- 例外として、`MainActivity` がタスクの最前面にある状態で利用目的のインテントが届いた場合は `onNewIntent` になる。これは扱わず、表示中の画面のままとする(MVP)

### PermissionRationaleScreen の内容

見出し「健康データの利用について」。本文は次の箇条書き:

- 読み取るデータ: 歩数・睡眠(就寝・起床時刻)・心拍・体重
- 使い道: 直近 7 日または 30 日の歩数・睡眠・心拍・体重を、このアプリの画面に表示するためだけに使います
- 送信: データを端末の外に送信しません(このアプリはインターネットに接続する権限を持っていません)
- 保存・書き込み: データをアプリ内に保存せず、ヘルスコネクトへの書き込みも行いません
- 取り消し: 権限はヘルスコネクトの設定からいつでも取り消せます

操作は「閉じる」のみ:
- `LaunchAction.permissionRationale` で起動された場合 → `SystemNavigator.pop()` でアプリを閉じ、ヘルスコネクトに戻る
- 案内画面の「詳しく見る」から開いた場合 → `Navigator.pop()` で元の画面に戻る

## ユースケース図

### UC1: 初回起動〜権限許可〜表示(F1 → F2 / F3)

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant UI as DashboardScreen
    participant Ctrl as DashboardController
    participant Svc as WeeklySummaryService
    participant Repo as HealthRepository
    participant HC as ヘルスコネクト

    User->>UI: アプリを起動
    UI->>Ctrl: build()
    Ctrl->>Repo: checkAvailability()
    Repo-->>Ctrl: available
    Ctrl->>Repo: checkPermissions()
    Repo-->>Ctrl: steps=denied, sleep=denied
    Ctrl-->>UI: DashboardNeedsPermission
    UI-->>User: 権限の説明と「権限を許可する」
    User->>UI: 「権限を許可する」をタップ
    UI->>Ctrl: requestPermissions()
    Ctrl->>Repo: requestPermissions()
    Repo->>HC: 権限ダイアログ
    User->>HC: 許可
    HC-->>Repo: 結果
    Repo-->>Ctrl: steps=granted, sleep=granted
    Ctrl->>Ctrl: AsyncLoading → _fetch() を再実行
    Ctrl->>Svc: loadSteps(range) / loadSleep(range)(並行)
    Svc->>Repo: readTotalSteps ×7 / readSleepSessions ×1
    Repo-->>Svc: データ
    Svc-->>Ctrl: MetricLoaded ×2
    Ctrl-->>UI: DashboardReady
    UI-->>User: 直近7日の歩数・睡眠
```

**フロー説明**:
1. 起動時にヘルスコネクトの利用可否 → 権限状態の順に確認する
2. 両方未許可なら案内画面を出し、ユーザー操作で権限ダイアログを開く(起動直後に自動でダイアログを出さない。何のための権限かを先に見せるため)
3. 許可されたら同じ画面のまま `_fetch()` を再実行し、データを表示する

### UC2: 2 回目以降の起動(F1 / F2 / F3)

1. `build()` → `checkAvailability()` → `checkPermissions()` で許可済みを確認(ダイアログは出さない)
2. 許可済みの種別だけ `WeeklySummaryService` で読み込み、`DashboardReady` を表示する

### UC3: 片方だけ許可(F4)

1. `checkPermissions()` が `steps=granted, sleep=denied` を返す
2. 歩数だけ読み込み、`DashboardReady(steps: MetricLoaded, sleep: MetricPermissionDenied)` とする
3. 睡眠セクションにだけ未許可の案内と「権限を許可する」を表示する

### UC4: 再読み込み・フォアグラウンド復帰

- 画面のプルダウン(引っぱって更新)で `refresh()` を呼ぶ(前回の表示を残したまま更新する)
- `AppLifecycleListener(onResume:)` で `onResumed()` → 利用可否・権限状態が前回と変わっていれば `refresh()` を呼ぶ(ヘルスコネクトの設定画面で許可して戻ってきた場合に対応)。権限ダイアログ表示中の復帰は無視する(`requestPermissions()` と二重に読み込まないため)

## 画面遷移図

画面は `DashboardScreen` 1 つで、状態によって表示が切り替わる。AppBar の旗アイコンから `GoalSettingsScreen` を開く(どの状態でも表示。下の状態機械は変わらない)。`PermissionRationaleScreen` はヘルスコネクトの権限画面から「利用目的」を開いたときだけ表示される。

```mermaid
stateDiagram-v2
    [*] --> Loading: 起動
    Loading --> Unavailable: ヘルスコネクト利用不可
    Loading --> NeedsPermission: 歩数・睡眠とも未許可
    Loading --> Ready: 少なくとも片方が許可済み
    NeedsPermission --> Loading: 権限を許可する → 許可
    NeedsPermission --> NeedsPermission: 権限を許可する → 拒否
    Ready --> Ready: 引っぱって更新(表示を残したまま更新)
    Ready --> Loading: 片方の権限を許可
    Ready --> Unavailable: 読み込み中に利用不可を検知
    Unavailable --> Ready: 復帰時に再確認(表示を残したまま更新)
    NeedsPermission --> Ready: 設定画面で許可して復帰
    Ready --> NeedsPermission: 設定画面で両方の権限を取り消して復帰
    Unavailable --> NeedsPermission: 更新して復帰(権限未許可)
```

- `Loading` は `AsyncLoading`(`isLoading`。権限リクエスト後は前回の値を伴う)。それ以外は `AsyncData` の中身の `DashboardState`
- 復帰時・引っぱって更新では `Loading` を経由しない(`refresh()`)
- 引っぱって更新(`RefreshIndicator`)は `Ready` / `NeedsPermission` / `Unavailable` のすべてで有効にする。案内表示だけの画面でも引っぱれるよう、本文を `ListView`(`AlwaysScrollableScrollPhysics`)に入れる
- `Ready` の中の表示は `MetricResult` の組み合わせで決まる(「UI設計」参照)

## アルゴリズム設計

### A1. 直近 N 日の日付範囲の計算

**目的**: 「今日を含む N 日」(N = 7 / 30)をローカル日付で求める

```dart
DateRange buildDateRange(DateTime now, {int dayCount = 7}) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final days = [
    for (var i = 0; i < dayCount; i++) DateTime(today.year, today.month, today.day - i),
  ];
  return DateRange(now: local, today: today, days: days);
}

/// その日の終わり(翌日 00:00)。読み取り区間 [day, nextDay(day)) に使う
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
```

### A2. 日別歩数の取得

**目的**: 期間の日数分(7 / 30 日)の日別歩数を、記録なしと区別して取得する

1. `range.days` の各日 `d` について `readTotalSteps(d, nextDay(d))` を呼ぶ。ただし今日は終端を `range.now` にする
2. N 回の呼び出しは `Future.wait` で並行に実行する。`readTotalSteps` はヘルスコネクトの集計(aggregate)API による区間ごとの合計で、30 日表示でも生データは取得しない(`getHealthIntervalDataFromTypes` の固定長バケットは夏時間の日に 00:00 からずれるため使わない)
3. 戻り値が `null` → `DailySteps(steps: null)`(記録なし。リポジトリが `0` を `null` に変換済み。プラグインの `null` = 読み取り失敗はリポジトリが `HealthReadException` にする)
4. 1 日でも `HealthReadException` が出た場合は、歩数全体を `MetricFailed` にする(部分的な表示はしない。欠けた日を「記録なし」と誤表示しないため)

**0 を記録なしとする理由**: ヘルスコネクトの集計 API は記録が 1 件もない区間で 0 を返す場合があり、「0 歩」と「記録なし」を区別できない。ウォッチを装着していれば 0 歩の日は実質的に起こらないため、0 は記録なしとして表示する。

### A3. 睡眠セッションの帰属日判定

**目的**: 睡眠セッションを起床日(終了時刻のローカル日付)に振り分ける(PRD「共通の定義」)

1. 読み取り区間: `[range.oldestDay - 1 日の 00:00, range.now]`。最古の日に起床したセッションは前日夜に始まるため、1 日前から読む。区間の開始より前に始まるセッション(最古日に起床し、開始が前々日以前 = 24 時間を大きく超える睡眠)は対象外になるが、記録の異常として扱い許容する
2. 取得したセッションを `end` のローカル日付でグループ化する
3. `range.days` に含まれない日付(最古日より前に起床したもの)は捨てる
4. 各日のセッションを `start` の昇順に並べる
5. 同一の `start`/`end` を持つセッションが複数ある場合は 1 件にまとめる(書き込み元の重複対策。`sourceName` は見ない)
6. 期間の日数分(7 / 30 日)すべてについて `DailySleep` を作る(セッションがない日は `sessions: []`)

```dart
List<DailySleep> assignSleepToDays(DateRange range, List<SleepSession> sessions) {
  final unique = {for (final s in sessions) (s.start, s.end): s}.values;
  final byDay = <DateTime, List<SleepSession>>{};
  for (final s in unique) {
    final e = s.end.toLocal();
    final day = DateTime(e.year, e.month, e.day);
    byDay.putIfAbsent(day, () => []).add(s);
  }
  return [
    for (final d in range.days)
      DailySleep(
        date: d,
        sessions: (byDay[d] ?? [])..sort((a, b) => a.start.compareTo(b.start)),
      ),
  ];
}
```

**睡眠時間**: `SleepSession.duration = end − start`(覚醒時間を差し引かない)。日別の合計は `DailySleep.total`。HUAWEIヘルスケアの表示と差がある場合の見直しは PRD「未確定事項」で扱う。

### A4. 表示フォーマット

| 対象 | 形式 | 例 |
|---|---|---|
| 日付 | `M/d(E)`(`intl`、ロケール `ja`) | `10/6(火)`(2026-10-06 は火曜日) |
| 今日・昨日 | 日付の前に「今日」「昨日」を付ける | `今日 10/6(火)` |
| 歩数 | 3 桁区切り + 「歩」 | `8,432 歩` |
| 時刻 | `HH:mm`(24 時間表記・ゼロ埋め) | `23:45` / `06:57` |
| 時間 | `H時間m分`。1 時間未満は `m分`、分が 0 のときは `H時間` | `7時間12分` / `45分` / `8時間` |
| 心拍 | 平均 + 半角スペース + `bpm`、続けて範囲を `(最小〜最大)` で弱い色 | `68 bpm (52〜128)` |
| 体重 | 小数 1 桁 + 半角スペース + `kg` | `65.3 kg` |

- `intl` の `ja` ロケールの日付データは、`main()` で `runApp` の前に `await initializeDateFormatting('ja')` を呼んで読み込む。テストでは `setUpAll` で同じ呼び出しを行う
- テストの期待値の曜日は、実際の暦どおりに書く(2026-10-04 = 日、10-05 = 月、10-06 = 火)

### A5. 目標の達成判定

`lib/domain/goal_progress.dart` の `stepsGoalStatus(day, goal:)` / `sleepGoalStatus(day, goalMinutes:)` が日ごとに `GoalStatus` を返す。上から順に最初に当たったものになる。

| 条件 | 歩数 | 睡眠 |
|---|---|---|
| 目標が null | `notSet` | `notSet` |
| 記録なし | `noRecord` | `noRecord` |
| 値 ≧ 目標(**目標ちょうどは達成**) | `achieved` | `achieved` |
| 今日の途中値で目標未満 | `inProgress`(判定しない) | ―(今日も通常どおり判定) |
| それ以外 | `notAchieved` | `notAchieved` |

- 睡眠は日別合計の分(`total.inMinutes`。秒は切り捨てで、A4 の表示と同じ)を比べる
- 今日の歩数は途中値のため、目標に届いていれば達成とし、届いていなければまだ判定しない。睡眠は起床日に帰属し、表示時点でその夜の睡眠は終わっているため今日も判定する
- 達成数・達成率の集計はしない(P2「週次の振り返りサマリー」)

## UI設計

### 画面レイアウト(DashboardReady)

```
┌────────────────────────────────┐
│ health-pixcel                  │
├────────────────────────────────┤
│ [   7 日   |   30 日   ]        │  ← 期間の切り替え(全幅の SegmentedButton)
│ 睡眠                            │
│ [ 推移グラフ(棒)。左が古い日 ]   │
│ 今日 10/6(火)  23:45→06:57 7時間12分 │
│ 昨日 10/5(月)  00:10→07:20 7時間50分 │  ← 日別合計
│                13:00→13:40          │  ← 同日の2件目
│ 10/4(日)       記録なし             │
│ …(7行 / 30行)                   │
├────────────────────────────────┤
│ 歩数                            │
│ [ 推移グラフ(棒)。左が古い日 ]   │
│ 今日 10/6(火)   3,210 歩 (途中)     │
│ 昨日 10/5(月)   8,432 歩           │
│ 10/4(日)        記録なし           │
│ …(7行 / 30行)                   │
├────────────────────────────────┤
│ 心拍                            │
│ 1 日の平均(最小〜最大)            │
│ 今日 10/6(火)   68 bpm (52〜128)   │
│ 10/4(日)        記録なし           │
│ …(7行 / 30行。グラフなし)         │
├────────────────────────────────┤
│ 体重                            │
│ その日の最新の記録                │
│ 今日 10/6(火)   65.3 kg            │
│ 昨日 10/5(月)   記録なし           │
│ …(7行 / 30行。グラフなし)         │
└────────────────────────────────┘
```

- 朝に確認することが多い(PRD ペルソナ)ため、**睡眠を上、歩数を下**に置く
- 心拍(#24)は歩数の下にセクションとして追加する(タブにしない)。睡眠・歩数の位置を変えないため、スクロールなしで直近の歩数・睡眠が見える要件は保たれる。体重(#25)は心拍の下に同じ形で足す
- 期間の切り替えはデータなし案内より上に置く。起動時は常に「7 日」が選ばれている
- 両セクションとも新しい日が上。Pixel 10 の縦画面でスクロールせずに少なくとも今日〜直近数日分が見えること

### 表示項目

**睡眠セクション(1 日 1 行。複数セッションは行内に追記)**

| 項目 | 説明 | フォーマット |
|------|------|-------------|
| 日付 | 帰属日(起床日) | A4 の日付形式 |
| 就寝→起床 | 各セッションの開始・終了 | `HH:mm→HH:mm` |
| 睡眠時間 | 日別合計(複数セッション時) | A4 の時間形式 |
| 達成マーク | 目標があるときだけ。A5 の判定 | 「達成」/「未達」(下記) |

**歩数セクション(1 日 1 行)**

| 項目 | 説明 | フォーマット |
|------|------|-------------|
| 日付 | 対象日 | A4 の日付形式 |
| 歩数 | 日別合計。今日は「(途中)」を付ける | A4 の歩数形式 |
| 達成マーク | 目標があるときだけ。A5 の判定 | 「達成」/「未達」(下記) |

**目標の表示**: 目標が設定されているとき、各セクションの見出しの下に「目標 8,000 歩」/「目標 7時間30分」を出す。目標が未設定なら目標の表示・達成マーク・目標ラインのいずれも出さない。

| `GoalStatus` | 行末の表示 |
|---|---|
| `achieved` | チェックのアイコン + 「達成」 |
| `notAchieved` | 円にマイナスのアイコン + 「未達」 |
| `noRecord` / `inProgress` | 何も出さない(「記録なし」「(途中)」の表示で区別できる) |
| `notSet` | 何も出さない(マークの欄自体を置かない) |

- 読み上げは行全体を 1 つにまとめ、「今日 10/6(火) 3,210 歩 達成」のように文言で伝える(アイコンは読ませない)

### 推移グラフ(睡眠・歩数共通)

- 横軸 = 日付(`M/d`)。7 日表示は全日、30 日表示は今日から 7 日おきにラベルを付ける。左が古い日、右が今日
- 縦軸 = 歩数(2,000 歩単位で切り上げ、最小 2,000)/ 睡眠時間(2 時間単位で切り上げ、最小 2 時間)。中間線と上限の 2 か所にラベルを付ける
- 記録なしの日は棒も下地も描かない。値 0 の日は下地があるので記録なしと見分けられる
- 全日記録なしのときはグラフを描かず「この期間の記録はありません」を表示する
- 目標があるときは、目標値の高さに破線の水平線を引き、右上に「目標」と添える。縦軸の上限は目標値より 1 段上に切り上げる(目標が棒より高くても、上限と同じ値でも、ラインと「目標」の文字が枠内に収まる。例: 目標 8,000 歩 → 上限 10,000 歩)
- スクリーンリーダーにはグラフ全体の要約を読ませる(棒ごとには読ませない。日別の値は下の一覧で読める)
  - 歩数あり: `歩数の推移グラフ。直近 N 日のうち記録のある日 K 日、1 日平均 X 歩、最多 Y 歩`
  - 睡眠あり: `睡眠時間の推移グラフ。直近 N 日のうち記録のある日 K 日、1 日平均 X、最長 Y`
  - 記録なし: `歩数の推移グラフ。直近 N 日、記録はありません` / `睡眠時間の推移グラフ。直近 N 日、記録はありません`
  - 目標があるとき(記録ありの場合のみ)、末尾に `、目標 X 歩` / `、目標 X` を足す

### 状態別の表示

| 状態 | 表示 | 操作 |
|---|---|---|
| `AsyncLoading`(`isLoading`。権限リクエスト後・期間の切り替え後は前回の値を伴う) | ローディングインジケーター(期間の切り替えも隠れる) | なし |
| `DashboardUnavailable(notInstalled)` | 「ヘルスコネクトを利用できません」+「Play ストアでヘルスコネクトの状態を確認してください」 | 「Play ストアを開く」(`openStore()`) |
| `DashboardUnavailable(updateRequired)` | 「ヘルスコネクトの更新が必要です」 | 「ヘルスコネクトを更新する」(`openStore()`) |
| `DashboardNeedsPermission` | 「歩数・睡眠・心拍・体重を表示するには、ヘルスコネクトの読み取り権限が必要です。データの読み取りのみ行い、端末の外には送信しません」 | 「権限を許可する」/「ヘルスコネクトの設定を開く」/「詳しく見る」(`PermissionRationaleScreen` へ) |
| `Ready` + セクションが `MetricPermissionDenied` | そのセクション内に「[歩数/睡眠/心拍/体重] の権限が許可されていません」 | 「権限を許可する」/「ヘルスコネクトの設定を開く」 |
| `AsyncError`(通常発生しない) | 「データを読み込めませんでした」 | 「再読み込み」(`refresh()`) |
| `Ready` + セクションが `MetricFailed` | そのセクション内に「データを読み込めませんでした」 | 「再読み込み」 |
| `Ready` + `isAllEmpty` | 画面上部に「ヘルスコネクトにデータがありません。Health Sync の同期設定を確認してください」 | 「再読み込み」(各セクションは期間の全行が「記録なし」で表示) |

- 権限ダイアログを 2 回拒否するとヘルスコネクトはダイアログを出さなくなるため、「権限を許可する」が効かないときの逃げ道として「ヘルスコネクトの設定を開く」を常に併記する

### カラーコーディング

- 「記録なし」「(途中)」は本文より弱い色(`onSurfaceVariant` 相当)で表示し、値のある行と区別する
- エラー・案内は `docs/ui-design-guidelines.md` の基準に従い、色だけに頼らず文言で状態を伝える
- 推移グラフの棒は `primary`、記録のある日の下地は `surfaceContainerHighest`、補助線は `outlineVariant`。記録の有無は下地の有無(形)で区別する
- 目標ラインは `onSurface` の破線(補助線の実線と線種で区別する)
- 達成マークのアイコンは `primary`、未達は文言・アイコンとも `onSurfaceVariant`。未達は異常ではないためエラー色を使わない。達成・未達はアイコンの形と文言で区別し、色だけに頼らない
- 具体的な配色は `docs/ui-design-guidelines.md` §7 の記入(`/kickoff` フェーズ1.5)に従う

## ファイル構造

MVP では健康データをファイル・データベースに保存しない。アプリが書き出すファイルはない。P1 で目標値 2 つ(int)だけを `shared_preferences` に保存する(健康データは保存しない)。

## パフォーマンス最適化

- **歩数の N 回(7 / 30 回)呼び出しを並行実行**: `Future.wait` で並べる(A2)
- **歩数と睡眠を並行取得**: `loadSteps` と `loadSleep` を同時に開始する
- **睡眠は 1 回のクエリ**: N + 1 日分(8 / 31 日分)を 1 回で取得し、端末内で振り分ける(A3)
- 目標: 起動から表示まで 3 秒以内(30 日表示でも)、再読み込みは 2 秒以内(PRD「パフォーマンス」)

## セキュリティ考慮事項

- **INTERNET 権限の排除**: `android/app/src/release/AndroidManifest.xml` に `<uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>` を置き、依存パッケージ経由の混入もマージ時に除去する。リリースビルドの最終マニフェストで不在を確認する(手順は `development-guidelines.md`)。デバッグ/プロファイルではホットリロード等のため INTERNET が入ってよい
- **最小権限**: ヘルスコネクト権限は `android.permission.health.READ_STEPS` / `READ_SLEEP` / `READ_HEART_RATE`(#24)/ `READ_WEIGHT`(#25)のみ宣言する。権限を足すときは先に PRD「セキュリティ・プライバシー」に理由を書く。`health` パッケージが要求する場合を除き、`ACTIVITY_RECOGNITION` 等の追加権限は宣言しない(必要性は実装時に確認し、必要なら PRD に理由を追記する)
- **ログ出力の禁止**: 健康データの値(歩数・時刻・時間)を `print` / `debugPrint` / `log` に渡さない。ドメインモデルは `toString()` を実装しない。例外メッセージにも値を含めない
- **保存・共有の禁止**: ファイル書き出し・共有シート・クリップボードコピーを実装しない
- **権限の利用目的表示**: ヘルスコネクトの要件に従い、`ACTION_SHOW_PERMISSIONS_RATIONALE` と(Android 14 以降の)`VIEW_PERMISSION_USAGE` の表示先として `PermissionRationaleScreen` を用意する。マニフェストの具体的な記述は `architecture.md` で定義する

## エラーハンドリング

### エラーの分類

| エラー種別 | 発生箇所 | 処理 | ユーザーへの表示 |
|-----------|---------|------|-----------------|
| ヘルスコネクト利用不可 | `checkAvailability`、または読み込み中の `UnsupportedError`(→ `MetricFailed(unavailable)`) | `DashboardUnavailable` に遷移(後者は `_fetch()` 本体の手順 5 で利用可否を再確認してから) | 「ヘルスコネクトを利用できません」/「更新が必要です」 |
| 権限未許可(両方) | `checkPermissions` | 読み込みをしない。`DashboardNeedsPermission` | 権限の説明 + 「権限を許可する」 |
| 権限未許可(片方) | `checkPermissions` | 許可済みの種別だけ読む | 該当セクションに未許可の案内 |
| 権限ダイアログで拒否 | `requestPermissions` | 状態を再確認して表示を更新(エラーにはしない) | 未許可の案内のまま |
| 読み取り失敗 | `readTotalSteps` / `readSleepSessions` | 該当種別を `MetricFailed(readFailed)` にする。もう片方は表示を続ける | 該当セクションに「データを読み込めませんでした」+「再読み込み」 |
| 不正なセッション(`end <= start`) | `HealthConnectRepository` の変換 | 破棄する(エラーにしない) | 該当日に他のセッションがなければ「記録なし」 |
| 想定外の例外 | どこでも | `_fetch()` の最上位で捕捉し、両種別を `MetricFailed(readFailed)` にする。値をログに出さない | 「データを読み込めませんでした」 |
| 設定画面を開けない | `openPermissionSettings` が `false` | 状態は変えない | スナックバー「ヘルスコネクトを開けませんでした」 |
| Play ストアを開けない | `openHealthConnectStore` が `false` | 状態は変えない | スナックバー「Play ストアを開けませんでした」 |
| 権限リクエストの失敗 | `requestPermissions` の例外 | フラグを戻し、権限状態を読み直して表示する(エラー表示にはしない) | 未許可の案内のまま |

## テスト戦略

### ユニットテスト(`flutter test`)
- `buildDateRange`: 通常日・月またぎ・年またぎ・23:59 で 7 日・30 日が 00:00 に揃い、`now` が保持される(30 日は 2 月を含む月またぎ・年またぎも。夏時間の検証は任意。対象端末の日本には夏時間がないため、`DateTime(y, m, d ± n)` を使う規約で担保する)
- `assignSleepToDays`: 日付をまたぐ睡眠が起床日に入る / 最古日より前に起床したセッションが除外される / 同日 2 件(昼寝)が昇順に並ぶ / 重複セッションが 1 件になる / セッションがない日が空リストになる
- A4 のフォーマット関数(`7時間12分` / `45分` / `8,432 歩` / `今日 10/6(火)`。2026-10-06 基準)
- `HealthConnectRepository`: フェイクの `Health` を注入し、歩数の `0` → `null`・`null` → `readFailed` / `dateTo <= dateFrom` のセッションの破棄と `toLocal()` / `UnsupportedError` → `unavailable`・その他の例外 → `readFailed` / `configure()` が 1 回だけ呼ばれること / 権限が種別ごとに判定されること
- `WeeklySummaryService`: フェイクの `HealthRepository` と固定時計で、歩数の `null`/`0` → 記録なし、1 日失敗 → `MetricFailed`、今日の終端が `range.now` になること、時計が 1 回しか読まれないこと
- `DashboardController`: フェイクのリポジトリで、利用不可 / 両方未許可 / 片方未許可 / 許可後の自動再読み込み / 読み取り失敗 / 読み込み中の `unavailable` → `DashboardUnavailable` / `refresh()` 中に前回の値が残る / `_fetch()` の多重呼び出しが 1 回に合流する / 権限ダイアログ中の `onResumed()` が無視される / 権限が変わらない復帰で再読み込みしない
- `isAllEmpty`: 定義の 3 条件の組み合わせ(片方未許可 + 片方全日記録なし → `true`、片方 `MetricFailed` → `false`)
- `DashboardController` の追加ケース: 利用不可で終わった `_fetch()` の後、更新して復帰 → 再読み込みされる / 権限なしで終わった後、何も変えずに復帰 → 再読み込みされない / 実行中の `refresh()` があるときの `requestPermissions()` → 許可後の権限状態で表示される / `requestPermissions()` が例外 → `_requestingPermission` が `false` に戻る
- `HealthPixcelApp`: 起動時のルート名(`defaultRouteNameTestValue`)が `/permission-rationale` → `PermissionRationaleScreen`、`/` や未知の値 → `DashboardScreen` が最初のフレームから表示される
- `PermissionRationaleScreen`: 本文の箇条書きが表示され、「詳しく見る」から開いた場合に「閉じる」で元の画面に戻る
- A5 の達成判定: 目標ちょうど(境界)・目標 ±1・今日の途中値(目標未満 / 以上)・記録なし・目標なし・睡眠の秒切り捨て

### ウィジェットテスト(`flutter test`)
- `DashboardScreen` が各 `DashboardState` で「状態別の表示」の文言と操作ボタンを出す
- `Ready` で 7 行ずつ表示され、記録なしの日も行が省略されない
- 推移グラフ(データあり / 一部記録なし / 全日記録なし / 30 日 / 目標ラインの有無)
- 目標の表示(目標なしで何も出ない / 達成・未達・途中・記録なしの出し分け / 目標を保存すると即座に反映される)

### 実機確認(Pixel 10、手動)
- 初回起動 → 権限許可 → 再起動なしで表示(F1)
- 表示された 7 日分の歩数・睡眠が HUAWEIヘルスケアの表示と一致する(PRD セカンダリーKPI)
- ヘルスコネクトの設定で片方の権限を外す → 復帰時に該当セクションだけ案内に変わる
- 機内モード・Health Sync 停止中でもクラッシュしない
- リリース APK の権限一覧に `INTERNET` が含まれない(`scripts/check-release-permissions.sh`)
- ヘルスコネクトの権限画面から「利用目的」を開くと `PermissionRationaleScreen` が表示され、「閉じる」でヘルスコネクトに戻る
- `adb logcat` を確認しながら起動・再読み込みを行い、歩数・時刻・睡眠時間の値がログに出ていない(プラグインの Kotlin 側を含む)
