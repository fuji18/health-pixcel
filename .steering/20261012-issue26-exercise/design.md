# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

#25(体重)の横展開に、睡眠(A3)と同型の「区間を持つ記録を日に振り分ける」処理を足す。**参照実装は `.steering/20261012-issue25-weight/design.md` とその実装(`readLatestWeight` / `loadWeight` / `WeightSection`)、および睡眠の `readSleepSessions` / `assignSleepToDays` / `loadSleep`**。「体重と同じ」「睡眠と同じ」と書いた箇所は、該当コードの形をそのまま写し、名前と型だけを替える。

```
HealthConnectRepository.readExerciseSessions(start, end)
   └─ getHealthDataFromTypes([WORKOUT]) → dateTo > dateFrom のものだけ ExerciseSession に
WeeklySummaryService.loadExercise(range)
   └─ readExerciseSessions(range.oldestDay, range.now) → assignExerciseToDays(range, sessions)(domain)
DashboardController._fetchBody → DashboardReady(..., weight, exercise)
DashboardScreen → ... / WeightSection / ExerciseSection(新規)
```

## 前提(`health` 13.3.2 の制約。ユーザー決定 2026-10-12)

`health` 13.3.2 は Android で WORKOUT を読むとき、運動記録ごとに **距離(`DistanceRecord`)・消費カロリー(`TotalCaloriesBurnedRecord`)・歩数(`StepsRecord`)を権限の確認なしに読む**(`HealthDataReader.kt` の `handleWorkoutData`)。どれか 1 つでも未許可だと SecurityException になり、プラグインが握りつぶして**空リストを返す**(エラーにならない)。

そのため、このアプリでは **運動記録の「許可」= WORKOUT・DISTANCE_DELTA・TOTAL_CALORIES_BURNED・STEPS の 4 つすべてが許可済み** と定義する。1 つでも欠けたら運動記録は `MetricPermissionDenied` として扱い、「記録なし」と誤表示しない。距離・消費カロリーの値はプラグインの戻り値に含まれるが、**このアプリでは一切参照しない**(`WorkoutHealthValue` を読まない)。

## 決定事項

| 項目 | 決定 |
|---|---|
| 帰属日 | 運動記録の**開始時刻(`start`)のローカル日付**。日をまたぐ記録(例 23:30〜翌 0:30)は**分割せず**開始日に全時間を帰属させる。睡眠(A3)と同じ「1 件を丸ごと 1 日に」の考え方で、どの日かは運動の自然な感覚(始めた日)に合わせて開始日にする(睡眠は起床日 = 終了日) |
| 読み取り区間 | `[range.oldestDay 00:00, range.now]`。開始日で振り分けるため、睡眠のように 1 日前から読む必要はない。区間と重なる記録はプラグインが返すが、開始が最古日より前のものは振り分けで捨てる |
| 不正な記録 | `dateTo <= dateFrom` の記録はリポジトリで捨てる(睡眠と同じ) |
| 重複 | 同一の `start` / `end` を持つ記録は 1 件にまとめる(睡眠と同じ。書き込み元は見ない) |
| 日別の値 | その日に帰属した記録の `end − start` の合計(`DailyExercise.total`)。記録がなければ「記録なし」 |
| 表記 | `formatDuration`(既存。`1時間5分` / `45分` / `2時間`)。新しいフォーマッタは作らない |
| 今日の扱い | 今日は表示時点までの途中値なので、記録があれば値の後に `(途中)` を付ける(歩数と同じ) |
| 画面の構成 | 睡眠 → 歩数 → 心拍 → 体重 → **運動**。体重の下に `Divider(height: 32)` を挟んで置く |
| 権限リクエスト | 「権限を許可する」は 7 型(STEPS・SLEEP_SESSION・HEART_RATE・WEIGHT・WORKOUT・DISTANCE_DELTA・TOTAL_CALORIES_BURNED)をまとめてリクエストする |
| 全種別未許可 | 5 種すべて未許可のとき `DashboardNeedsPermission`(`noneGranted` のまま。変更不要) |

## コンポーネント設計

### 1. `lib/domain/models/health_status.dart`(変更)

`enum HealthMetric { steps, sleep, heartRate, weight, exercise }`(`exercise` を末尾に足すだけ)。

### 2. `lib/domain/models/exercise_session.dart`(新規)

`SleepSession` と同じ形。

```dart
/// 1 回の運動記録。
class ExerciseSession {
  const ExerciseSession({required this.start, required this.end});

  /// 開始時刻(ローカル)。
  final DateTime start;

  /// 終了時刻(ローカル)。start より後。
  final DateTime end;

  /// 運動の長さ。
  Duration get duration => end.difference(start);
}
```

### 3. `lib/domain/models/daily_exercise.dart`(新規)

```dart
import 'package:health_pixcel/domain/models/exercise_session.dart';

/// 1 日ぶんの運動(開始日に帰属)。
class DailyExercise {
  const DailyExercise({
    required this.date,
    required this.sessions,
    required this.isToday,
  });

  /// 帰属日(開始日)の 00:00(ローカル)。
  final DateTime date;

  /// 開始時刻の昇順。空は記録なし。
  final List<ExerciseSession> sessions;

  /// true の場合、表示時点までの途中値。
  final bool isToday;

  /// 記録があるか。
  bool get hasRecord => sessions.isNotEmpty;

  /// sessions の duration の合計。空なら [Duration.zero]。
  Duration get total =>
      sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
}
```

### 4. `lib/domain/exercise_assignment.dart`(新規。純 Dart)

`assignSleepToDays` と同じ形で、振り分けのキーを **`start`** にする。

```dart
/// [sessions] を開始日(start のローカル日付)ごとに振り分け、[range] の日数分を新しい順で返す。
///
/// - 日をまたぐ記録も分割せず、開始日に全時間を帰属させる
/// - range に含まれない日に開始した記録は捨てる
/// - 同一の start / end を持つ記録は 1 件にまとめる(書き込み元の重複対策)
/// - 各日の記録は start の昇順。記録がない日は空リスト
/// - range.days の先頭(今日)だけ isToday = true
///
/// 機能設計書 A6。
List<DailyExercise> assignExerciseToDays(
  DateRange range,
  List<ExerciseSession> sessions,
) {
  final unique = {for (final s in sessions) (s.start, s.end): s}.values;
  final byDay = <DateTime, List<ExerciseSession>>{};
  for (final s in unique) {
    final start = s.start.toLocal();
    final day = DateTime(start.year, start.month, start.day);
    byDay.putIfAbsent(day, () => []).add(s);
  }
  return List<DailyExercise>.unmodifiable([
    for (var i = 0; i < range.days.length; i++)
      DailyExercise(
        date: range.days[i],
        sessions: List<ExerciseSession>.unmodifiable(
          <ExerciseSession>[...?byDay[range.days[i]]]
            ..sort((a, b) => a.start.compareTo(b.start)),
        ),
        isToday: i == 0,
      ),
  ]);
}
```

### 5. `lib/data/health_repository.dart`(変更)

- `requestPermissions()` の doc を「歩数・睡眠・心拍・体重・運動記録の READ 権限をまとめてリクエストし、…」にする
- 追加(`readLatestWeight` の後):

```dart
  /// [start, end) と重なる運動記録(start / end はローカル時刻)。
  /// 失敗時は [HealthReadException] を投げる。
  Future<List<ExerciseSession>> readExerciseSessions(
    DateTime start,
    DateTime end,
  );
```

### 6. `lib/data/health_connect_repository.dart`(変更)

**(a) 種別と型の対応を「1 種別 = 複数の型」にする。**

```dart
  /// 読み取るデータ種別と、その種別の読み取りに要る health の型。
  /// 運動記録は health 13.3.2 が距離・消費カロリー・歩数も読むため 4 型すべてが要る(design.md「前提」)。
  static const _types = {
    HealthMetric.steps: [HealthDataType.STEPS],
    HealthMetric.sleep: [HealthDataType.SLEEP_SESSION],
    HealthMetric.heartRate: [HealthDataType.HEART_RATE],
    HealthMetric.weight: [HealthDataType.WEIGHT],
    HealthMetric.exercise: [
      HealthDataType.WORKOUT,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.STEPS,
    ],
  };

  /// リクエスト・問い合わせする型(重複なし。_types の出現順)。
  static final _requestTypes = {
    for (final types in _types.values) ...types,
  }.toList(growable: false);
```

`_requestTypes` の順序は `[STEPS, SLEEP_SESSION, HEART_RATE, WEIGHT, WORKOUT, DISTANCE_DELTA, TOTAL_CALORIES_BURNED]` になる(Set リテラルは挿入順を保つ)。

**(b) `requestPermissions`**: `_types.values.toList()` を `_requestTypes` に、`permissions` を `[for (final _ in _requestTypes) HealthDataAccess.READ]` に替える。

**(c) `_readPermissions`**: 型ごとに 1 回ずつ問い合わせ(`hasPermissions([type], permissions: const [HealthDataAccess.READ])`。**複数の型を 1 回で問い合わせない**)、種別は「その種別の型がすべて許可済み」のとき許可とする。

```dart
  Future<HealthPermissions> _readPermissions() async {
    // 型ごとに個別に問い合わせる。null / false は未許可
    final grantedTypes = <HealthDataType>{};
    for (final type in _requestTypes) {
      final ok = await _health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
      if (ok == true) grantedTypes.add(type);
    }
    // 種別は、読み取りに要る型がすべて許可済みのときだけ許可
    return HealthPermissions(
      Set.unmodifiable({
        for (final entry in _types.entries)
          if (grantedTypes.containsAll(entry.value)) entry.key,
      }),
    );
  }
```

**(d) 追加(`readLatestWeight` の後)**: `readSleepSessions` と同じ形。

```dart
  @override
  Future<List<ExerciseSession>> readExerciseSessions(
    DateTime start,
    DateTime end,
  ) => _guard(() async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: start,
      endTime: end,
    );
    // 距離・消費カロリーなど WorkoutHealthValue の中身は読まない(表示しない。PRD)
    return List<ExerciseSession>.unmodifiable([
      for (final p in points)
        if (p.dateTo.isAfter(p.dateFrom))
          ExerciseSession(start: p.dateFrom.toLocal(), end: p.dateTo.toLocal()),
    ]);
  });
```

- 値・例外メッセージをログに出さない(`_guard` を通すだけでよい)

### 7. `lib/application/weekly_summary_service.dart`(追加)

```dart
  /// 期間の日数分の運動。読み取り区間は [range.oldestDay, range.now](機能設計書 A6)。
  Future<MetricResult<DailyExercise>> loadExercise(DateRange range) async {
    try {
      final sessions = await _repository.readExerciseSessions(
        range.oldestDay,
        range.now,
      );
      return MetricLoaded(assignExerciseToDays(range, sessions));
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }
```

- クラスの doc コメントを「直近 N 日(7 / 30)の歩数・睡眠・心拍・体重・運動を組み立てる」にする

### 8. `lib/presentation/dashboard/dashboard_state.dart`(変更)

- `DashboardReady` に `required this.exercise`(`final MetricResult<DailyExercise> exercise;` doc「運動の取得結果。」)を足す。引数の順は `period, range, steps, sleep, heartRate, weight, exercise`
- `isAllEmpty` を 5 種に広げる(体重の扱いと同じ。運動の「記録なし」は `!d.hasRecord`)

### 9. `lib/presentation/dashboard/dashboard_controller.dart`(変更)

体重を足したときと同じ箇所に 5 番目を足す。

- 手順 4 のレコードに `MetricResult<DailyExercise> exerciseResult`(`permissions.isGranted(HealthMetric.exercise) ? service.loadExercise(r) : Future<MetricResult<DailyExercise>>.value(const MetricPermissionDenied<DailyExercise>())`)
- 手順 5: `_isUnavailable(exercise)` も再確認の条件に含め、`available` のままなら `MetricFailed<DailyExercise>(HealthErrorKind.readFailed)` に読み替える
- 手順 6: `DashboardReady(..., weight: weight, exercise: exercise)`
- 手順 7(想定外の例外): 5 種とも `MetricFailed(readFailed)`

### 10. `lib/presentation/dashboard/widgets/exercise_section.dart`(新規)

`WeightSection` と同じ構成・同じコンストラクタ引数(`result` の型が `MetricResult<DailyExercise>`)。

- 見出し: `'運動'`
- `MetricLoaded`: 説明 `その日に始めた運動の合計時間`(体重の「その日の最新の記録」と同じスタイル)→ 日の数だけ `_ExerciseRow`(新しい日が上)
- `MetricPermissionDenied`: `StatusMessage(title: '運動記録の権限が許可されていません', body: '運動記録の表示には、運動・距離・消費カロリー・歩数の読み取りをすべて許可してください(距離と消費カロリーは表示しません)', actions: [権限を許可する, ヘルスコネクトの設定を開く])`
- `MetricFailed`: `データを読み込めませんでした` + `再読み込み`(体重と同じ)

`_ExerciseRow` は `_WeightRow` と同じスタイル(`MergeSemantics` + `Padding(vertical: 8)` + `Row(crossAxisAlignment: start)`、日付ラベルは `Expanded`、その後 `SizedBox(width: 8)`)。値側:

- `!day.hasRecord` → `Text('記録なし', style: muted)`
- それ以外 → `Flexible(child: Text(day.isToday ? '${formatDuration(day.total)} (途中)' : formatDuration(day.total), style: numeric, textAlign: TextAlign.end))`
  - 歩数のように `(途中)` を別 `Text` にしない理由: 文字サイズ 2.0 倍で overflow を出さないため 1 つの `Flexible` に収める。`(途中)` の前は半角スペース 1 つ

### 11. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- `_buildReady` の `WeightSection(...)` の後に `const Divider(height: 32)` と `ExerciseSection(result: state.exercise, today: today, onRequestPermission: _requestPermissions, onOpenSettings: _openSettings, onRetry: _retry)` を足す
- `DashboardNeedsPermission` の見出しを `'歩数・睡眠・心拍・体重・運動記録を表示するには、ヘルスコネクトの読み取り権限が必要です'` にする

### 12. `lib/presentation/rationale/permission_rationale_screen.dart`(変更)

- 読み取るデータ: `'歩数・睡眠(就寝・起床時刻)・心拍・体重・運動記録(開始・終了時刻)。運動記録の読み取りに必要なため距離・消費カロリーの許可も求めますが、それらの値は表示も保存もしません'`
- 使い道: `'直近 7 日または 30 日の歩数・睡眠・心拍・体重・運動時間を、このアプリの画面に表示するためだけに使います'`

### 13. `android/app/src/main/AndroidManifest.xml`(変更)

`READ_WEIGHT` の次の行に追加する(コメントは変えない):

```xml
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
```

`READ_EXERCISE_ROUTES` は宣言しない。

### 14. `scripts/check-release-permissions.sh`(変更)

`ALLOWED_PERMISSIONS` の `android.permission.health.READ_WEIGHT` の次の行に、上の 3 つを同じ順で足す。他は変えない。

## テスト設計

### `test/fakes/fake_health_repository.dart`

- `permissions` の既定値に `HealthMetric.exercise` を足す(5 種とも許可)
- 追加(睡眠と同じ形): `List<ExerciseSession> exerciseSessions = [];` / `HealthErrorKind? exerciseError;` / `final exerciseCalls = <(DateTime, DateTime)>[];`。`readExerciseSessions` は `readSleepSessions` と同じ形(`readGate` も待つ)。`readGate` の doc に `readExerciseSessions` を足す

既存テストで「全種別許可」を明示している箇所(`{steps, sleep, heartRate, weight}`)は、全種許可の意図なら `exercise` も足してよい。**画面テストで「記録なし」や日付ラベルの件数が運動セクションのぶん増える場合は、期待件数だけを増やしてよい**(#25 と同じ)。「○○だけ未許可」のテストで「権限を許可する」が複数出て壊れる場合は、許可セットに `exercise` を足す(#25 と同じ)。それ以外の期待値が変わる場合は停止して報告する。

`test/data/health_connect_repository_test.dart` の `_FakeHealth.hasPermissions` は `types.single` を引く形のままでよい(型ごとに 1 回ずつ問い合わせる設計のため)。`granted` に無い型は `null`(= 未許可)になるので、既存の「全許可」テストは新しい 3 型(WORKOUT・DISTANCE_DELTA・TOTAL_CALORIES_BURNED)を `true` で足して意図を保つ。

### 追加するテスト

| ファイル | ケース |
|---|---|
| `test/domain/exercise_assignment_test.dart`(新規) | 開始日に帰属する / **日をまたぐ記録(23:30〜翌 0:30)は開始日に 60 分すべて帰属し、翌日は記録なし**(受け入れ条件)/ 最古日より前に開始して最古日に終わる記録は捨てる / 同一 start・end は 1 件 / 同日の複数記録は start 昇順で、`total` は合計 / 記録のない日は空で `hasRecord == false` / 戻り値は range の日数分(7 と 30 の両方)で新しい順 / `isToday` は先頭だけ true |
| `test/domain/models/daily_exercise_test.dart`(新規。`daily_sleep` のテストがあればその形に合わせる) | `total` が duration の合計 / 空なら `Duration.zero` |
| `test/data/health_connect_repository_test.dart` | `requestPermissions` が 7 型(上記の順)と `READ` 7 つで呼ばれる(既存テストを更新)/ `checkPermissions` が 7 型を 1 つずつ問い合わせる / **WORKOUT は許可・DISTANCE_DELTA だけ未許可 → exercise は未許可、steps は許可** / **STEPS だけ未許可 → steps と exercise が未許可** / 7 型すべて許可 → 5 種とも許可 / `readExerciseSessions`: WORKOUT 型・指定区間で 1 回呼ぶ、`dateTo <= dateFrom` の記録を捨てる、start / end をローカル時刻にする / 例外 → `HealthReadException(readFailed)`、`UnsupportedError` → `unavailable` |
| `test/application/weekly_summary_service_test.dart` | `loadExercise`: 読み取り区間が `[oldestDay, now]`(7 日と 30 日)/ 振り分けた結果を返す(開始日帰属を 1 ケース)/ 失敗 → `MetricFailed` |
| `test/presentation/dashboard/dashboard_state_test.dart` | `isAllEmpty`: 運動だけ記録あり → false / 5 種とも全日記録なし → true / 運動が `MetricFailed` → false / 運動だけ未許可で他 4 種が全日記録なし → true |
| `test/presentation/dashboard/dashboard_controller_test.dart` | 5 種とも未許可 → `DashboardNeedsPermission` / 運動だけ未許可 → 他 4 種は `MetricLoaded`、運動は `MetricPermissionDenied` / 運動だけ許可 → `DashboardReady`(他 4 種は `MetricPermissionDenied`)/ 運動の読み込みが `unavailable` → 再確認(`available` のままなら運動は `MetricFailed(readFailed)`)/ 復帰時に運動の権限だけ変わった → 読み直す |
| `test/presentation/dashboard/dashboard_screen_test.dart` | **運動だけ未許可**: 運動セクションに「運動記録の権限が許可されていません」・説明文・2 つの操作が出て、歩数・睡眠・心拍・体重の値は表示される(受け入れ条件)/ 運動の値の行(`1時間5分`)と説明「その日に始めた運動の合計時間」/ 今日の行は `45分 (途中)` / 記録なしの日は「記録なし」/ 運動が失敗 → 運動セクション内に「データを読み込めませんでした」/ 5 種とも未許可の見出し文言 / 文字サイズ 2.0 倍で運動の行(今日の `(途中)` 付き)が overflow を出さない |
| `test/presentation/rationale/permission_rationale_screen_test.dart` | 文言の変更に追従する |

## 変更しないもの

- 歩数・睡眠・心拍・体重の読み取りと表示、目標まわり、グラフ、`DisplayPeriod` / `DateRange`
- `lib/data/platform_channels.dart`、Kotlin のコード、`pubspec.yaml`、`android/app/build.gradle.kts`
- `docs/`(司令塔が更新する。実装者は触らない)
