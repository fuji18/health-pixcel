# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

権限状態を「歩数・睡眠の 2 フィールドのレコード」から「**許可済みのデータ種別の集合**」(`HealthPermissions`)に一般化する。データ種別は列挙型 `HealthMetric` で表し、#25(体重)・#26(運動記録)は列挙値を 1 つ足すだけで権限まわりが広がる形にする。

心拍は歩数と同じ「1 日ずつ区間を読んで集計値を返す」形で読む。リポジトリが `HeartRateStats?`(平均・最小・最大)を返し、`WeeklySummaryService.loadHeartRate` が期間の日数分を並行に読んで `MetricResult<DailyHeartRate>` を作る。画面は睡眠 → 歩数 → **心拍**の順にセクションを並べる(グラフなし。一覧のみ)。

```
HealthConnectRepository.readHeartRate(start, end)
   └─ getHealthDataFromTypes([HEART_RATE]) → [start, end) の標本だけ残す → summarizeHeartRate()(domain)
WeeklySummaryService.loadHeartRate(range) → MetricResult<DailyHeartRate>
DashboardController._fetchBody → DashboardReady(..., heartRate)
DashboardScreen → SleepSection / StepsSection / HeartRateSection(新規)
```

## 決定事項(Issue の「着手時に design.md で決める」ほか)

| 項目 | 決定 |
|---|---|
| 日別の代表値 | **平均**(主表示)と**最小〜最大**(補足)。その日の心拍の標本(`HeartRateRecord` の各 sample)から計算する。平均は標本の単純平均を四捨五入した整数 |
| 安静時心拍 | 扱わない(`READ_RESTING_HEART_RATE` が別に要るため。最小権限。PRD に記載済み) |
| 今日の扱い | 今日も [今日 0:00, 現在) の標本で同じに計算する。「(途中)」は**付けない**(平均・範囲は累積値ではなく、途中でも意味が変わらないため) |
| 画面の構成 | **セクション追加**(タブにしない)。睡眠 → 歩数 → 心拍 の順で、心拍は歩数の下に `Divider(height: 32)` を挟んで置く。睡眠・歩数の位置は変えないため「スクロールせずに今日を含む直近の歩数・睡眠が見える」要件は保たれる |
| 権限リクエスト | **まとめて出す**。「権限を許可する」は常に歩数・睡眠・心拍の 3 種をまとめて `requestAuthorization` する(ヘルスコネクトの画面は 1 回で済む。許可済みの種別はヘルスコネクト側で許可済みとして表示される)。データ種別ごとのリクエストは作らない |
| 全種別未許可 | 3 種すべて未許可のとき `DashboardNeedsPermission`(従来の「両方未許可」の一般化) |
| 権限状態の型 | `HealthPermissions`(許可済みの `HealthMetric` の集合。値の等価性を持つ)。`PermissionStatus` 列挙型は**削除**する |
| 区間外の標本 | `HeartRateRecord` は区間をまたぐことがあり、ヘルスコネクトは区間と重なるレコードを丸ごと返すため、標本の時刻(`dateFrom`)が `[start, end)` に入るものだけを使う |
| 複数ソースの重複 | `health` の `removeDuplicates` に任せる(同じ時刻・値でもソースが異なれば両方数える。平均への影響は小さいため許容) |
| 単位の表記 | `68 bpm`(半角スペース + `bpm`)。範囲は `(52〜128)` |

## コンポーネント設計

### 1. `lib/domain/models/health_status.dart`(変更)

`PermissionStatus` を削除し、次の 2 つを追加する(他の列挙型はそのまま)。

```dart
/// 読み取るデータの種別(権限はこの単位で扱う)。
enum HealthMetric { steps, sleep, heartRate }

/// データ種別ごとの権限状態(許可済みの種別の集合)。値で比較できる。
class HealthPermissions {
  /// [granted] は許可済みの種別。
  const HealthPermissions(this.granted);

  /// 許可済みの種別。
  final Set<HealthMetric> granted;

  /// [metric] が許可済みか。
  bool isGranted(HealthMetric metric) => granted.contains(metric);

  /// どの種別も許可されていないか。
  bool get noneGranted => granted.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is HealthPermissions &&
      other.granted.length == granted.length &&
      other.granted.containsAll(granted);

  @override
  int get hashCode => Object.hashAllUnordered(granted);
}
```

- ドメイン層は純 Dart のため `package:flutter/foundation.dart` の `setEquals` は使わない(上の手書きの比較にする)

### 2. `lib/domain/models/heart_rate_stats.dart`(新規)

```dart
/// ある区間の心拍の集計値(bpm。整数)。
class HeartRateStats {
  const HeartRateStats({
    required this.average,
    required this.min,
    required this.max,
  });

  /// 標本の平均(四捨五入)。
  final int average;

  /// 最小値。
  final int min;

  /// 最大値。
  final int max;
}
```

### 3. `lib/domain/models/daily_heart_rate.dart`(新規)

```dart
import 'package:health_pixcel/domain/models/heart_rate_stats.dart';

/// 1 日ぶんの心拍。
class DailyHeartRate {
  const DailyHeartRate({
    required this.date,
    required this.stats,
    required this.isToday,
  });

  /// 対象日の 00:00(ローカル)。
  final DateTime date;

  /// その日の集計値。null は記録なし。
  final HeartRateStats? stats;

  /// true の場合、表示時点までの値。
  final bool isToday;
}
```

### 4. `lib/domain/heart_rate_summary.dart`(新規。純 Dart)

```dart
import 'package:health_pixcel/domain/models/heart_rate_stats.dart';

/// 心拍の標本(bpm)から集計値を作る。標本が無ければ null。
HeartRateStats? summarizeHeartRate(Iterable<num> samples) {
  var count = 0;
  num sum = 0;
  num? min;
  num? max;
  for (final v in samples) {
    count++;
    sum += v;
    if (min == null || v < min) min = v;
    if (max == null || v > max) max = v;
  }
  if (count == 0) return null;
  return HeartRateStats(
    average: (sum / count).round(),
    min: min!.round(),
    max: max!.round(),
  );
}
```

### 5. `lib/domain/formatters.dart`(追加)

```dart
/// 心拍を `68 bpm` 形式にする。
String formatBpm(int bpm) => '$bpm bpm';

/// 心拍の範囲を `(52〜128)` 形式にする。
String formatBpmRange(int min, int max) => '($min〜$max)';
```

### 6. `lib/data/health_repository.dart`(変更)

- `checkPermissions()` / `requestPermissions()` の戻り値を `Future<HealthPermissions>` にする。doc コメントは「データ種別ごとの権限状態」「歩数・睡眠・心拍の READ 権限をまとめてリクエストし、リクエスト後の状態を返す」
- 追加:

```dart
  /// [start, end) の心拍の集計値。記録なしは null。失敗時は [HealthReadException] を投げる。
  Future<HeartRateStats?> readHeartRate(DateTime start, DateTime end);
```

### 7. `lib/data/health_connect_repository.dart`(変更)

- 種別と `HealthDataType` の対応をクラス内の定数にする:

```dart
  /// 読み取るデータ種別と health の型の対応。
  static const _types = {
    HealthMetric.steps: HealthDataType.STEPS,
    HealthMetric.sleep: HealthDataType.SLEEP_SESSION,
    HealthMetric.heartRate: HealthDataType.HEART_RATE,
  };
```

- `requestPermissions`: `requestAuthorization(_types.values.toList(), permissions: [for (final _ in _types.values) HealthDataAccess.READ])` の後に `_readPermissions()` を返す
- `_readPermissions`: `_types` の各エントリについて**個別に** `hasPermissions([type], permissions: const [HealthDataAccess.READ])` を順に呼び、`== true` のものだけを集めて `HealthPermissions(Set.unmodifiable({...}))` を返す(null / false は未許可)。`_toStatus` は削除
- `readHeartRate`:

```dart
  @override
  Future<HeartRateStats?> readHeartRate(DateTime start, DateTime end) =>
      _guard(() async {
        final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.HEART_RATE],
          startTime: start,
          endTime: end,
        );
        // 区間をまたぐレコードは丸ごと返るため、標本の時刻で [start, end) に絞る
        return summarizeHeartRate([
          for (final p in points)
            if (!p.dateFrom.isBefore(start) && p.dateFrom.isBefore(end))
              if (p.value case NumericHealthValue(:final numericValue))
                numericValue,
        ]);
      });
```

- 例外の変換(`_guard`)は他メソッドと同じ。値・例外メッセージをログに出さない

### 8. `lib/application/weekly_summary_service.dart`(追加)

`loadSteps` と同じ形で追加する。

```dart
  /// 期間の日数分の心拍。1 日でも [HealthReadException] が出たら [MetricFailed]。
  Future<MetricResult<DailyHeartRate>> loadHeartRate(DateRange range) async {
    try {
      final values = await Future.wait([
        for (var i = 0; i < range.days.length; i++)
          _repository.readHeartRate(
            range.days[i],
            i == 0 ? range.now : nextDay(range.days[i]),
          ),
      ]);
      return MetricLoaded(
        List<DailyHeartRate>.unmodifiable([
          for (var i = 0; i < range.days.length; i++)
            DailyHeartRate(date: range.days[i], stats: values[i], isToday: i == 0),
        ]),
      );
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }
```

- クラスの doc コメントを「直近 N 日(7 / 30)の歩数・睡眠・心拍を組み立てる」にする

### 9. `lib/presentation/dashboard/dashboard_state.dart`(変更)

- `DashboardNeedsPermission` の doc を「すべてのデータ種別が未許可(F4)」に、`DashboardReady` の doc を「少なくとも 1 種別が許可済み」にする
- `DashboardReady` に `required this.heartRate`(`final MetricResult<DailyHeartRate> heartRate;` doc「心拍の取得結果。」)を足す。コンストラクタ引数の順は `period, range, steps, sleep, heartRate`
- `isAllEmpty` を 3 種に広げる。定義は従来と同じ考え方:
  1. どれも `MetricFailed` ではない
  2. 少なくとも 1 つが `MetricLoaded`
  3. `MetricLoaded` のものはすべて全日記録なし(歩数 `steps == null` / 睡眠 `!hasRecord` / 心拍 `stats == null`)
  - `MetricPermissionDenied` は判定から除外

### 10. `lib/presentation/dashboard/dashboard_controller.dart`(変更)

- `_Snapshot.permissions` の型を `HealthPermissions?` にする(`HealthPermissions` は値の等価性を持つため、`current != _lastSnapshot` の比較はそのまま動く)
- `_fetchBody` の手順 3: `if (permissions.noneGranted) return const DashboardNeedsPermission();`
- 手順 4: 3 種を並行に読む。未許可の種別は `MetricPermissionDenied`:

```dart
      final (
        MetricResult<DailySteps> stepsResult,
        MetricResult<DailySleep> sleepResult,
        MetricResult<DailyHeartRate> heartRateResult,
      ) = await (
        permissions.isGranted(HealthMetric.steps)
            ? service.loadSteps(r)
            : Future<MetricResult<DailySteps>>.value(const MetricPermissionDenied<DailySteps>()),
        permissions.isGranted(HealthMetric.sleep)
            ? service.loadSleep(r)
            : Future<MetricResult<DailySleep>>.value(const MetricPermissionDenied<DailySleep>()),
        permissions.isGranted(HealthMetric.heartRate)
            ? service.loadHeartRate(r)
            : Future<MetricResult<DailyHeartRate>>.value(const MetricPermissionDenied<DailyHeartRate>()),
      ).wait;
```

- 手順 5: `unavailable` の判定に心拍も含める(3 種のいずれかが `MetricFailed(unavailable)` なら再確認。`available` のままなら該当する種別を `MetricFailed(readFailed)` に読み替える)
- 手順 6: `DashboardReady(..., heartRate: heartRate)`
- 手順 7(想定外の例外): 3 種とも `MetricFailed(readFailed)`

### 11. `lib/presentation/dashboard/widgets/heart_rate_section.dart`(新規)

`StepsSection` と同じ構成(見出し → 結果に応じた本体)。目標・グラフは無い。

```dart
/// 心拍セクション。日別一覧・未許可の案内・エラー表示のいずれかを描画する。
class HeartRateSection extends StatelessWidget {
  const HeartRateSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });
  final MetricResult<DailyHeartRate> result;
  final DateTime today;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  ...
}
```

- 見出し: `Semantics(header: true, child: Text('心拍', style: textTheme.titleMedium))` + `SizedBox(height: 8)`
- `MetricLoaded`:
  - 見出しの下に説明 `1 日の平均(最小〜最大)` を `bodyMedium` + `onSurfaceVariant` で出し(`StepsSection` の「目標 8,000 歩」と同じスタイル・`Align(centerLeft)`)、`SizedBox(height: 8)` を空ける
  - 日の数だけ `_HeartRateRow`(新しい日が上 = `days` の順のまま)
- `MetricPermissionDenied`: `StatusMessage(title: '心拍の権限が許可されていません', actions: [StatusAction('権限を許可する', onRequestPermission), StatusAction('ヘルスコネクトの設定を開く', onOpenSettings)])`
- `MetricFailed`: `StatusMessage(title: 'データを読み込めませんでした', actions: [StatusAction('再読み込み', onRetry)])`

`_HeartRateRow`(`_StepsRow` と同じスタイル。`MergeSemantics` + `Padding(vertical: 8)` + `Row`):

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: Text(formatDayLabel(day.date, today: today), style: label)),
    const SizedBox(width: 8),
    if (stats == null)
      Text('記録なし', style: muted)
    else
      Flexible(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: formatBpm(stats.average), style: numeric),
            const TextSpan(text: ' '),
            TextSpan(text: formatBpmRange(stats.min, stats.max), style: mutedNumeric),
          ]),
          textAlign: TextAlign.end,
        ),
      ),
  ],
)
```

- `label` / `numeric`(`tabularFigures`)/ `muted`(`onSurfaceVariant`)は `_StepsRow` と同じ定義。`mutedNumeric` は `muted` に `tabularFigures` を足したもの
- 値側を `Flexible` + 折り返し可にするのは、文字サイズ 2.0 倍で `RenderFlex overflow` を出さないため(#23 の申し送り)
- 読み上げは行全体で「今日 10/6(火) 68 bpm (52〜128)」相当になる(`MergeSemantics`)

### 12. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- `_buildReady` の末尾(`StepsSection` の後)に `const Divider(height: 32)` と `HeartRateSection(result: state.heartRate, today: today, onRequestPermission: _requestPermissions, onOpenSettings: _openSettings, onRetry: _retry)` を足す
- `DashboardNeedsPermission` の見出しを `'歩数・睡眠・心拍を表示するには、ヘルスコネクトの読み取り権限が必要です'` にする(説明・操作は変えない)

### 13. `lib/presentation/rationale/permission_rationale_screen.dart`(変更)

- 読み取るデータ: `'歩数・睡眠(就寝・起床時刻)・心拍'`
- 使い道: `'直近 7 日または 30 日の歩数・睡眠・心拍を、このアプリの画面に表示するためだけに使います'`

### 14. `android/app/src/main/AndroidManifest.xml`(変更)

`READ_SLEEP` の次の行に追加する(コメントは変えない):

```xml
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
```

### 15. `scripts/check-release-permissions.sh`(変更)

`ALLOWED_PERMISSIONS` の `android.permission.health.READ_SLEEP` の次の行に `android.permission.health.READ_HEART_RATE` を足す。他は変えない。

## テスト設計

既存テストの `({PermissionStatus steps, PermissionStatus sleep})` / `(steps: ..., sleep: ...)` は `HealthPermissions({...})` に機械的に置き換える(例: `(steps: granted, sleep: denied)` → `HealthPermissions({HealthMetric.steps})`)。既存の検証内容は変えない。**ただし**「歩数・睡眠とも許可」を前提にした既存テストは、心拍も許可(`{steps, sleep, heartRate}`)に置き換えてよい(心拍は記録なしで読まれるだけで、既存の期待値は変わらないはず。変わる場合は停止して報告)。

### `test/fakes/fake_health_repository.dart`

- `permissions` の既定値を `HealthPermissions({HealthMetric.steps, HealthMetric.sleep, HealthMetric.heartRate})`、`permissionsAfterRequest` を `HealthPermissions?` にする
- 追加: `final heartRates = <DateTime, HeartRateStats>{};`(日付 00:00 → 集計値。キーが無い日は null)/ `final heartRateErrors = <DateTime, HealthErrorKind>{};` / `final heartRateCalls = <(DateTime, DateTime)>[];`。`readHeartRate` は `readTotalSteps` と同じ形(`readGate` も待つ)

### 追加するテスト

| ファイル | ケース |
|---|---|
| `test/domain/heart_rate_summary_test.dart`(新規) | 空 → null / 1 標本 → 平均・最小・最大が同値 / 複数 → 平均は四捨五入(例: 60, 61 → 61。60, 60, 61 → 60)/ 小数の標本(`72.4`)も扱える |
| `test/domain/models/health_status_test.dart`(新規。無ければ作る) | `HealthPermissions` の等価性(順序違いの集合が等しい・要素違いは等しくない・`hashCode` 一致)/ `isGranted` / `noneGranted` |
| `test/domain/formatters_test.dart` | `formatBpm(68)` → `68 bpm` / `formatBpmRange(52, 128)` → `(52〜128)` |
| `test/data/health_connect_repository_test.dart` | `requestPermissions` が `[STEPS, SLEEP_SESSION, HEART_RATE]` と `READ` 3 つで呼ばれる / `checkPermissions` が 3 種を個別に問い合わせ、心拍だけ false・null のとき心拍だけ未許可 / `readHeartRate`: 区間内の標本だけで集計する(区間の前・`end` ちょうどの標本は除外、`start` ちょうどは含む)/ 標本なし → null / 例外 → `HealthReadException(readFailed)`、`UnsupportedError` → `unavailable`。`_FakeHealth.getHealthDataFromTypes` は既存の `points` / `dataCalls` を使う(心拍の `HealthDataPoint` は `NumericHealthValue` で作る) |
| `test/application/weekly_summary_service_test.dart` | `loadHeartRate`: 日数分を新しい順に返す / 今日の区間は `[today, now)`、それ以外は `[day, nextDay)` / 記録なしの日は `stats == null` / 1 日でも失敗 → `MetricFailed` |
| `test/presentation/dashboard/dashboard_state_test.dart` | `isAllEmpty`: 心拍だけ記録あり → false / 3 種とも全日記録なし → true / 心拍が `MetricFailed` → false / 心拍だけ未許可で歩数・睡眠が全日記録なし → true |
| `test/presentation/dashboard/dashboard_controller_test.dart` | 3 種とも未許可 → `DashboardNeedsPermission` / 心拍だけ未許可 → 歩数・睡眠は `MetricLoaded`、心拍は `MetricPermissionDenied` / 心拍だけ許可 → `DashboardReady`(歩数・睡眠は `MetricPermissionDenied`)/ 心拍の読み込みが `unavailable` → 利用可否の再確認(`available` のままなら心拍は `MetricFailed(readFailed)`)/ 復帰時に心拍の権限だけ変わった → 読み直す |
| `test/presentation/dashboard/dashboard_screen_test.dart` | **心拍だけ未許可**: 心拍セクションに「心拍の権限が許可されていません」と 2 つの操作が出て、歩数・睡眠の値は表示される(受け入れ条件)/ 心拍の値の行(`68 bpm (52〜128)`)と説明「1 日の平均(最小〜最大)」/ 記録なしの日は「記録なし」/ 心拍が失敗 → 心拍セクション内に「データを読み込めませんでした」/ 3 種とも未許可の見出し文言 / 文字サイズ 2.0 倍(`MediaQuery` の `textScaler: TextScaler.linear(2.0)`)で心拍の行が例外(overflow)を出さない |
| `test/presentation/rationale/permission_rationale_screen_test.dart` | 文言の変更に追従する |

## 変更しないもの

- `DisplayPeriod` / `DateRange` / 睡眠・歩数の読み取りと表示・目標まわり
- `lib/data/platform_channels.dart`、Kotlin のコード
- `docs/`(司令塔が更新する。実装者は触らない)
