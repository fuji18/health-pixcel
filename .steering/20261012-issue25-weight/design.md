# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

#24(心拍)の横展開。**参照実装は `.steering/20261011-issue24-heart-rate/design.md` と、その実装(`readHeartRate` / `loadHeartRate` / `HeartRateSection` ほか)**。以下で「心拍と同じ」と書いた箇所は、心拍の該当コードの形をそのまま写し、名前と値の型だけを替える。

体重は「1 日ずつ区間を読んで、その区間の最新の記録(kg)を返す」形で読む。

```
HealthConnectRepository.readLatestWeight(start, end)
   └─ getHealthDataFromTypes([WEIGHT]) → [start, end) の記録だけ残す → pickLatestWeight()(domain)
WeeklySummaryService.loadWeight(range) → MetricResult<DailyWeight>
DashboardController._fetchBody → DashboardReady(..., heartRate, weight)
DashboardScreen → SleepSection / StepsSection / HeartRateSection / WeightSection(新規)
```

## 決定事項

| 項目 | 決定 |
|---|---|
| 日別の値 | その日の区間 `[day, nextDay)`(今日は `[today, now)`)にある体重の記録のうち、**時刻(`dateFrom`)が最も新しいもの**の値。同時刻が複数あれば列挙順で後のものを採る |
| 記録のない日 | 「記録なし」(前日以前の値を引き継がない) |
| 単位・表記 | kg、**小数 1 桁**(`toStringAsFixed(1)`)。例 `65.3 kg`(半角スペース + `kg`)。ポンド表記はしない(`health` 13.3.2 の WEIGHT の既定単位は KILOGRAM) |
| 今日の扱い | 今日も `[今日 0:00, 現在)` の最新値。「(途中)」は**付けない**(最新値は累積値ではない) |
| 画面の構成 | 睡眠 → 歩数 → 心拍 → **体重**。心拍の下に `Divider(height: 32)` を挟んで置く |
| 権限リクエスト | 「権限を許可する」は 4 種(歩数・睡眠・心拍・体重)をまとめてリクエストする(#24 と同じ。`_types` に足すだけで広がる) |
| 全種別未許可 | 4 種すべて未許可のとき `DashboardNeedsPermission`(`noneGranted` のまま。変更不要) |
| 区間外の記録 | 記録の時刻(`dateFrom`)が `[start, end)` に入るものだけを使う(心拍と同じ判定) |
| 値の型 | ドメインでは `double`(kg)。`NumericHealthValue.numericValue` は `num` なので `toDouble()` する |

## コンポーネント設計

### 1. `lib/domain/models/health_status.dart`(変更)

`enum HealthMetric { steps, sleep, heartRate, weight }`(`weight` を末尾に足すだけ)。

### 2. `lib/domain/models/daily_weight.dart`(新規)

```dart
/// 1 日ぶんの体重。
class DailyWeight {
  const DailyWeight({
    required this.date,
    required this.kg,
    required this.isToday,
  });

  /// 対象日の 00:00(ローカル)。
  final DateTime date;

  /// その日の最新の記録(kg)。null は記録なし。
  final double? kg;

  /// true の場合、表示時点までの値。
  final bool isToday;
}
```

### 3. `lib/domain/weight_summary.dart`(新規。純 Dart)

```dart
/// 体重の記録(時刻・kg)から最新の値を返す。記録が無ければ null。
/// 同時刻の記録が複数あれば、列挙順で後のものを採る。
double? pickLatestWeight(Iterable<({DateTime at, num kg})> records) {
  DateTime? latestAt;
  num? latest;
  for (final r in records) {
    if (latestAt == null || !r.at.isBefore(latestAt)) {
      latestAt = r.at;
      latest = r.kg;
    }
  }
  return latest?.toDouble();
}
```

### 4. `lib/domain/formatters.dart`(追加)

```dart
/// 体重を `65.3 kg` 形式(小数 1 桁)にする。
String formatKg(double kg) => '${kg.toStringAsFixed(1)} kg';
```

### 5. `lib/data/health_repository.dart`(変更)

- `requestPermissions()` の doc の「歩数・睡眠・心拍」を「歩数・睡眠・心拍・体重」にする
- 追加(`readHeartRate` の後):

```dart
  /// [start, end) の最新の体重(kg)。記録なしは null。失敗時は [HealthReadException] を投げる。
  Future<double?> readLatestWeight(DateTime start, DateTime end);
```

### 6. `lib/data/health_connect_repository.dart`(変更)

- `_types` に `HealthMetric.weight: HealthDataType.WEIGHT,` を足す
- 追加(`readHeartRate` の後):

```dart
  @override
  Future<double?> readLatestWeight(DateTime start, DateTime end) =>
      _guard(() async {
        final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.WEIGHT],
          startTime: start,
          endTime: end,
        );
        // 心拍と同じく、記録の時刻で [start, end) に絞る
        return pickLatestWeight([
          for (final p in points)
            if (!p.dateFrom.isBefore(start) && p.dateFrom.isBefore(end))
              if (p.value case NumericHealthValue(:final numericValue))
                (at: p.dateFrom, kg: numericValue),
        ]);
      });
```

- 値・例外メッセージをログに出さない(`_guard` を通すだけでよい)

### 7. `lib/application/weekly_summary_service.dart`(追加)

`loadHeartRate` と同じ形で `loadWeight` を追加する。

```dart
  /// 期間の日数分の体重。1 日でも [HealthReadException] が出たら [MetricFailed]。
  Future<MetricResult<DailyWeight>> loadWeight(DateRange range) async {
    // loadHeartRate と同じ:各日 _repository.readLatestWeight(range.days[i], i == 0 ? range.now : nextDay(range.days[i]))
    // → DailyWeight(date: range.days[i], kg: values[i], isToday: i == 0)
  }
```

- クラスの doc コメントを「直近 N 日(7 / 30)の歩数・睡眠・心拍・体重を組み立てる」にする

### 8. `lib/presentation/dashboard/dashboard_state.dart`(変更)

- `DashboardReady` に `required this.weight`(`final MetricResult<DailyWeight> weight;` doc「体重の取得結果。」)を足す。引数の順は `period, range, steps, sleep, heartRate, weight`
- `isAllEmpty` を 4 種に広げる(心拍の扱いと同じ。体重の「記録なし」は `d.kg == null`):
  1. どれも `MetricFailed` ではない
  2. 少なくとも 1 つが `MetricLoaded`
  3. `MetricLoaded` のものはすべて全日記録なし

### 9. `lib/presentation/dashboard/dashboard_controller.dart`(変更)

- 手順 4 のレコードに 4 番目の要素 `MetricResult<DailyWeight> weightResult` を足す(`permissions.isGranted(HealthMetric.weight) ? service.loadWeight(r) : Future<MetricResult<DailyWeight>>.value(const MetricPermissionDenied<DailyWeight>())`)
- 手順 5: `_isUnavailable(weight)` も再確認の条件に含め、`available` のままなら `MetricFailed<DailyWeight>(HealthErrorKind.readFailed)` に読み替える
- 手順 6: `DashboardReady(..., heartRate: heartRate, weight: weight)`
- 手順 7(想定外の例外): 4 種とも `MetricFailed(readFailed)`

### 10. `lib/presentation/dashboard/widgets/weight_section.dart`(新規)

`HeartRateSection` と同じ構成・同じコンストラクタ引数(`result` の型が `MetricResult<DailyWeight>`)。

- 見出し: `'体重'`
- `MetricLoaded`: 説明 `その日の最新の記録`(心拍の「1 日の平均(最小〜最大)」と同じスタイル)→ 日の数だけ `_WeightRow`(新しい日が上)
- `MetricPermissionDenied`: `StatusMessage(title: '体重の権限が許可されていません', actions: [権限を許可する, ヘルスコネクトの設定を開く])`(心拍と同じ)
- `MetricFailed`: `データを読み込めませんでした` + `再読み込み`(心拍と同じ)

`_WeightRow` は `_HeartRateRow` と同じスタイル(`MergeSemantics` + `Padding(vertical: 8)` + `Row`、日付ラベルは `Expanded`)。値側:

- `kg == null` → `Text('記録なし', style: muted)`
- それ以外 → `Flexible(child: Text(formatKg(kg), style: numeric, textAlign: TextAlign.end))`(文字サイズ 2.0 倍で overflow を出さないため `Flexible`)

### 11. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- `_buildReady` の `HeartRateSection(...)` の後に `const Divider(height: 32)` と `WeightSection(result: state.weight, today: today, onRequestPermission: _requestPermissions, onOpenSettings: _openSettings, onRetry: _retry)` を足す
- `DashboardNeedsPermission` の見出しを `'歩数・睡眠・心拍・体重を表示するには、ヘルスコネクトの読み取り権限が必要です'` にする

### 12. `lib/presentation/rationale/permission_rationale_screen.dart`(変更)

- 読み取るデータ: `'歩数・睡眠(就寝・起床時刻)・心拍・体重'`
- 使い道: `'直近 7 日または 30 日の歩数・睡眠・心拍・体重を、このアプリの画面に表示するためだけに使います'`

### 13. `android/app/src/main/AndroidManifest.xml`(変更)

`READ_HEART_RATE` の次の行に追加する(コメントは変えない):

```xml
    <uses-permission android:name="android.permission.health.READ_WEIGHT"/>
```

### 14. `scripts/check-release-permissions.sh`(変更)

`ALLOWED_PERMISSIONS` の `android.permission.health.READ_HEART_RATE` の次の行に `android.permission.health.READ_WEIGHT` を足す。他は変えない。

## テスト設計

### `test/fakes/fake_health_repository.dart`

- `permissions` の既定値に `HealthMetric.weight` を足す(4 種とも許可)
- 追加: `final weights = <DateTime, double>{};`(日付 00:00 → kg。キーが無い日は null)/ `final weightErrors = <DateTime, HealthErrorKind>{};` / `final weightCalls = <(DateTime, DateTime)>[];`。`readLatestWeight` は `readHeartRate` と同じ形(`readGate` も待つ)

既存テストで「全種別許可」を明示している箇所(`{steps, sleep, heartRate}`)は、全種許可の意図なら `weight` も足してよい。体重は記録なしで読まれるだけで既存の期待値は変わらないはず。**画面テストで「記録なし」や日付ラベルの件数が体重セクションのぶん増える場合は、期待件数だけを増やしてよい**(#24 と同じ)。それ以外の期待値が変わる場合は停止して報告する。

### 追加するテスト

| ファイル | ケース |
|---|---|
| `test/domain/weight_summary_test.dart`(新規) | 空 → null / 1 件 → その値(`double`)/ 複数 → 時刻が最も新しいもの(列挙順が時刻順でなくても)/ 同時刻 → 列挙順で後のもの / `int` の kg(`65`)→ `65.0` |
| `test/domain/formatters_test.dart` | `formatKg(65.0)` → `65.0 kg` / `formatKg(65.34)` → `65.3 kg` / `formatKg(65.36)` → `65.4 kg` |
| `test/domain/models/health_status_test.dart` | 必要なら `weight` を含む集合の等価性を 1 件足す(既存が通れば省略可) |
| `test/data/health_connect_repository_test.dart` | `requestPermissions` が `[STEPS, SLEEP_SESSION, HEART_RATE, WEIGHT]` と `READ` 4 つで呼ばれる(既存テストを更新)/ `checkPermissions` が 4 種を個別に問い合わせ、体重だけ false のとき体重だけ未許可 / `readLatestWeight`: 区間内の最新の記録を返す(区間の前・`end` ちょうどは除外、`start` ちょうどは含む)/ 記録なし → null / 例外 → `HealthReadException(readFailed)`、`UnsupportedError` → `unavailable` |
| `test/application/weekly_summary_service_test.dart` | `loadWeight`: 日数分を新しい順に返す / 今日の区間は `[today, now)`、それ以外は `[day, nextDay)` / 記録なしの日は `kg == null` / 1 日でも失敗 → `MetricFailed` |
| `test/presentation/dashboard/dashboard_state_test.dart` | `isAllEmpty`: 体重だけ記録あり → false / 4 種とも全日記録なし → true / 体重が `MetricFailed` → false / 体重だけ未許可で他 3 種が全日記録なし → true |
| `test/presentation/dashboard/dashboard_controller_test.dart` | 4 種とも未許可 → `DashboardNeedsPermission` / 体重だけ未許可 → 他 3 種は `MetricLoaded`、体重は `MetricPermissionDenied` / 体重だけ許可 → `DashboardReady`(他 3 種は `MetricPermissionDenied`)/ 体重の読み込みが `unavailable` → 再確認(`available` のままなら体重は `MetricFailed(readFailed)`)/ 復帰時に体重の権限だけ変わった → 読み直す |
| `test/presentation/dashboard/dashboard_screen_test.dart` | **体重だけ未許可**: 体重セクションに「体重の権限が許可されていません」と 2 つの操作が出て、歩数・睡眠・心拍の値は表示される(受け入れ条件)/ 体重の値の行(`65.3 kg`)と説明「その日の最新の記録」/ 記録なしの日は「記録なし」/ 体重が失敗 → 体重セクション内に「データを読み込めませんでした」/ 4 種とも未許可の見出し文言 / 文字サイズ 2.0 倍で体重の行が overflow を出さない |
| `test/presentation/rationale/permission_rationale_screen_test.dart` | 文言の変更に追従する |

## 変更しないもの

- 歩数・睡眠・心拍の読み取りと表示、目標まわり、`DisplayPeriod` / `DateRange`
- `lib/data/platform_channels.dart`、Kotlin のコード、`pubspec.yaml`
- `docs/`(司令塔が更新する。実装者は触らない)
