# 設計書: 表示期間の切り替え(7 日 / 30 日)(#20)

<!-- status: ready -->

## 決定事項(Issue の「着手時に決める」項目)

| 論点 | 決定 | 理由 |
|---|---|---|
| 「月」の定義 | **直近 30 日(今日を含む 30 日)** | 暦の月にすると月初は 1〜2 日しか表示されず、日数も 28〜31 で揺れる。「今日から遡る N 日」なら 7 日表示と同じ規則(A1)で一般化でき、#21 のグラフも横軸の本数が固定になる |
| 切り替え UI の位置 | **`DashboardReady` のリスト先頭(データなし案内より上)**に全幅の `SegmentedButton` | AppBar に置くと権限未許可・利用不可の画面でも出てしまう。期間はデータを表示している状態でだけ意味がある |
| 切り替え中の表示 | `requestPermissions()` と同じく `AsyncLoading`(画面は全体のローディング) | 既存の状態別表示(`isLoading` → インジケーター)をそのまま使え、新しい表示状態を増やさない。前回の値を残すと「30 日」を選んだのに 7 行が見え続けて誤読を招く |
| 歩数の取得 | 既存の `readTotalSteps`(= `getTotalStepsInInterval`。ヘルスコネクトの aggregate API)を**日ごとに 30 回、並行に**呼ぶ | 「日ごとの区間集計 API」そのもの。生データは取得しない。`getHealthIntervalDataFromTypes` は秒単位の固定長バケットで、夏時間の日に 00:00 からずれる(A1 の規約に反する)ため使わない |
| 選んだ期間の保存 | しない(起動時は常に 7 日) | Issue のスコープ外 |

## アーキテクチャ概要

層構成は変えない。期間はドメイン層の enum として定義し、プレゼンテーション層(`DashboardController`)が保持、アプリケーション層には日数(`int`)だけを渡す。

```
DashboardScreen ──selectPeriod(p)──▶ DashboardController(_period を保持)
                                        │ service.currentRange(dayCount: _period.dayCount)
                                        ▼
                                   WeeklySummaryService ──▶ buildDateRange(now, dayCount: n)
                                        │ loadSteps: readTotalSteps × n(並行)
                                        │ loadSleep: readSleepSessions × 1
                                        ▼
                                   DashboardReady(period, range, steps, sleep)
```

## コンポーネント設計

### 1. `DisplayPeriod`(新規 `lib/domain/models/display_period.dart`)

```dart
/// ダッシュボードの表示期間(機能設計書「DisplayPeriod」)。
enum DisplayPeriod {
  /// 直近 7 日。起動時の既定。
  week(7),

  /// 直近 30 日。
  month(30);

  const DisplayPeriod(this.dayCount);

  /// 今日を含む日数。
  final int dayCount;
}
```

- 表示ラベル(「7 日」「30 日」)はドメインに置かない(画面が持つ)

### 2. `buildDateRange`(`lib/domain/date_range_builder.dart`)

シグネチャを `DateRange buildDateRange(DateTime now, {int dayCount = 7})` に変える。

```dart
/// [now] を含む直近 [dayCount] 日の範囲を返す。
///
/// [now] はローカル時刻に変換して保持する。日付はすべてローカルの 00:00。
DateRange buildDateRange(DateTime now, {int dayCount = 7}) {
  assert(dayCount > 0, 'dayCount は 1 以上');
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  // (既存のコメントを残す)
  final days = List<DateTime>.unmodifiable([
    for (var i = 0; i < dayCount; i++)
      DateTime(today.year, today.month, today.day - i),
  ]);
  return DateRange(now: local, today: today, days: days);
}
```

- 既定値 7 により、既存の呼び出し・既存テストは変更不要
- `nextDay` は変更しない

### 3. `DateRange`(`lib/domain/models/date_range.dart`)

コードは変えず、ドキュメントコメントだけ一般化する:
- クラス: `/// 直近 N 日(今日を含む)の範囲。日付はローカルタイムゾーンの 00:00。`
- `days`: `/// 新しい順の N 日分 \`[today, today-1, ..., today-(N-1)]\`。`
- `oldestDay`: `/// 最古の日(today - (N-1) 日)。`

### 4. `WeeklySummaryService`(`lib/application/weekly_summary_service.dart`)

- `DateRange currentRange({int dayCount = 7}) => buildDateRange(_clock(), dayCount: dayCount);`
- `loadSteps` / `loadSleep` のロジックは変えない(すでに `range.days.length` に従う)。コメントの「7 日分」を「期間の日数分」に直す。クラスのコメントも「直近 7 日」→「直近 N 日(7 / 30)」
- クラス名・ファイル名は変えない(リネームはスコープ外)

### 5. `DashboardReady`(`lib/presentation/dashboard/dashboard_state.dart`)

- フィールド `final DisplayPeriod period;` を追加し、コンストラクタで `required this.period` にする(既定値は付けない)。コメントは `/// 表示期間。range.days.length == period.dayCount。`
- `range` のコメントを `/// 表示する期間の日付範囲。` に直す
- `isAllEmpty` のロジックは変えない(`days.every` なので N 日に自動で対応)

### 6. `DashboardController`(`lib/presentation/dashboard/dashboard_controller.dart`)

**追加する private 状態**: `DisplayPeriod _period = DisplayPeriod.week;`

**追加する public メソッド**:

```dart
/// 表示期間を切り替えて読み直す。同じ期間なら何もしない。
Future<void> selectPeriod(DisplayPeriod period) async {
  if (period == _period) return;
  _period = period;
  state = const AsyncLoading<DashboardState>();
  final next = await _fetch(force: true);
  if (!ref.mounted || !_isCurrent(next)) return;
  state = AsyncData(next);
}
```

**追加する private ヘルパー**:

```dart
/// 読み込みの結果が今の表示期間のものか。期間に依存しない状態(利用不可・権限なし)は常に true。
bool _isCurrent(DashboardState s) => s is! DashboardReady || s.period == _period;
```

**既存メソッドの変更**:

- `refresh()`: `if (!ref.mounted) return;` を `if (!ref.mounted || !_isCurrent(next)) return;` にする
- `requestPermissions()`: 最後の `if (!ref.mounted) return; state = AsyncData(next);` の条件を同様に `!ref.mounted || !_isCurrent(next)` にする
- `_fetchBody()`:
  - 冒頭(`repository` / `service` 取得の直後)で `final period = _period;` を取る。以降は `_period` を直接読まない
  - `service.currentRange()` の 2 箇所(手順 4 と catch 内)を `service.currentRange(dayCount: period.dayCount)` にする
  - `DashboardReady(...)` の 2 箇所に `period: period` を渡す

**なぜ `_isCurrent` が要るか**(コードコメントに 1 行で残す): 期間を変えた後でも、変える前に始まった `_fetch` が完了することがある(`refresh()` が古い期間の実行中 Future に合流している、`selectPeriod` を連続で呼んだ、など)。古い期間の `DashboardReady` で `state` を上書きすると、選択中の期間と表示がずれる。期間を変えた側(`selectPeriod`)が必ず新しい期間で `_fetch(force: true)` を走らせて `state` を設定するため、古い結果は捨ててよい。

`build()` / `onResumed()` / `openSettings()` / `openStore()` / `_fetch()` は変更しない。

### 7. `DashboardScreen`(`lib/presentation/dashboard/dashboard_screen.dart`)

`_buildReady` の戻りリストの**先頭**に次の 2 要素を入れる(`isAllEmpty` の案内より上):

```dart
SegmentedButton<DisplayPeriod>(
  segments: const [
    ButtonSegment(value: DisplayPeriod.week, label: Text('7 日')),
    ButtonSegment(value: DisplayPeriod.month, label: Text('30 日')),
  ],
  selected: {state.period},
  showSelectedIcon: false,
  onSelectionChanged: (selection) =>
      _controller.selectPeriod(selection.single),
),
const SizedBox(height: 16),
```

- `ListView` の中なので全幅に伸びる(タップ領域を大きく取れる)。`Align` などで包まない
- `DashboardUnavailable` / `DashboardNeedsPermission` / `AsyncError` / `AsyncLoading` では出さない
- `StepsSection` / `SleepSection` は変更しない(`result.days` の件数ぶん描画する)

### 8. `PermissionRationaleScreen`(`lib/presentation/rationale/permission_rationale_screen.dart`)

「使い道」の本文を `'直近 7 日または 30 日の歩数と睡眠を、このアプリの画面に表示するためだけに使います'` に変える(利用目的の記載を実際の動作と一致させるため)。`test/presentation/rationale/permission_rationale_screen_test.dart` の期待文字列も同じ文言に変える。

## エラーハンドリング戦略

新しいエラー種別は無い。30 日の歩数のうち 1 日でも失敗したら歩数全体が `MetricFailed`(A2 の既存規則がそのまま適用される)。想定外の例外の経路(`_fetchBody` の catch)でも `period` を保った `DashboardReady` を返す。

## テスト戦略

### ユニットテスト

**`test/domain/date_range_builder_test.dart`**(既存テストは変更しない。`group('buildDateRange 30 日', ...)` を追加):

| ケース | 入力 | 期待 |
|---|---|---|
| 30 日・通常 | `buildDateRange(DateTime(2026, 10, 6, 9, 30), dayCount: 30)` | `days.length == 30`、`days.first == DateTime(2026, 10, 6)`、`days[1] == DateTime(2026, 10, 5)`、`oldestDay == DateTime(2026, 9, 7)`、`today == DateTime(2026, 10, 6)` |
| 30 日・月またぎ(2 月を含む) | `DateTime(2026, 3, 15, 12)`, 30 | `days[14] == DateTime(2026, 3, 1)`、`days[15] == DateTime(2026, 2, 28)`、`oldestDay == DateTime(2026, 2, 14)` |
| 30 日・年またぎ | `DateTime(2026, 1, 10, 12)`, 30 | `days[9] == DateTime(2026, 1, 1)`、`days[10] == DateTime(2025, 12, 31)`、`oldestDay == DateTime(2025, 12, 12)` |
| 30 日・全日 00:00 かつ連続 | 上の 3 入力 | 全要素の時・分・秒・ミリ秒・マイクロ秒が 0、隣り合う要素 `days[i]` と `days[i+1]` について `DateTime(d.year, d.month, d.day - 1) == days[i+1]`(i = 0..28) |
| 既定は 7 日 | `buildDateRange(DateTime(2026, 10, 6))` と `buildDateRange(DateTime(2026, 10, 6), dayCount: 7)` | `days` が等しい |

**`test/application/weekly_summary_service_test.dart`**(追加):

| ケース | 期待 |
|---|---|
| `currentRange(dayCount: 30)` | `days.length == 30`、`oldestDay == DateTime(2026, 9, 7)`、時計は 1 回だけ読まれる |
| 歩数: 30 日分 | `loadSteps(currentRange(dayCount: 30))` が `MetricLoaded` で 30 件、`days[0].isToday` が true、`days[29].date == DateTime(2026, 9, 7)`、`fake.stepsCalls.length == 30`、`stepsCalls` に `(DateTime(2026, 9, 7), DateTime(2026, 9, 8))` と `(DateTime(2026, 10, 6), now)` を含む |
| 睡眠: 30 日分の読み取り区間 | `loadSleep(currentRange(dayCount: 30))` の読み取り開始が `DateTime(2026, 9, 6)`・終端が `now`、結果が 30 件(既存の「睡眠: 読み取り区間と振り分け」と同じ方法で読み取り区間を確認する) |

**`test/presentation/dashboard/dashboard_controller_test.dart`**(`group('表示期間', ...)` を追加。既存の `initial()` / `pump()` / `controller()` / `value()` / `st()` ヘルパーを使う):

| ケース | 手順 | 期待 |
|---|---|---|
| 初期は 7 日 | `initial()` | `value()` が `DashboardReady` で `period == DisplayPeriod.week`、`range.days.length == 7` |
| 30 日に切り替える | `initial()` → `fake.readGate = Completer()` → `f = controller().selectPeriod(DisplayPeriod.month)` → `pump()` | この時点で `st().isLoading` が true。`readGate.complete()` → `await f` 後、`period == month`、`range.days.length == 30`、歩数 `MetricLoaded` の `days.length == 30`、睡眠 `MetricLoaded` の `days.length == 30`、`fake.stepsCalls.length == 7 + 30` |
| 同じ期間は読み直さない | `initial()` → `await controller().selectPeriod(DisplayPeriod.week)` | `fake.checkAvailabilityCalls` が呼び出し前と同じ、`st().isLoading` が false |
| 切り替え後の refresh は期間を保つ | `initial()` → `await selectPeriod(month)` → `await refresh()` | `period == month`、`range.days.length == 30` |
| 30 日に戻して 7 日に戻す | `initial()` → `await selectPeriod(month)` → `await selectPeriod(week)` | `period == week`、`range.days.length == 7` |
| 実行中の refresh があるときの切り替え | `initial()` → `fake.readGate = Completer()` → `r = refresh()` → `pump()` → `container.listen` で以降の `AsyncValue` を記録開始 → `s = selectPeriod(month)` → `pump()` → `readGate.complete()` → `await Future.wait([r, s])` | 最終値が `period == month` で 30 日。記録した値のうち `AsyncData` で `DashboardReady` のものは**すべて** `period == month`(古い 7 日の結果で上書きされていない) |
| 連続切り替え | `initial()` → `fake.readGate = Completer()` → `a = selectPeriod(month)` → `pump()` → 記録開始 → `b = selectPeriod(week)` → `pump()` → `readGate.complete()` → `await Future.wait([a, b])` | 最終値が `period == week` で 7 日。記録した `AsyncData` の `DashboardReady` はすべて `period == week` |
| 30 日で歩数の 1 日が失敗 | `initial()` → `fake.stepsErrors[DateTime(2026, 9, 7)] = HealthErrorKind.readFailed` → `await selectPeriod(month)` | `period == month`、`steps` が `MetricFailed`、`sleep` は `MetricLoaded` で 30 件 |
| 30 日で想定外の例外 | `initial()` → `await selectPeriod(month)` → `fake.permissionsError = Exception('x')` → `await refresh()` | `DashboardReady` で `period == month`、`range.days.length == 30`、歩数・睡眠とも `MetricFailed` |

※ `readGate` が全読み取りを止める仕様でない場合は、`fake_health_repository.dart` の既存フィールドで同等の待機を作る(フェイクへのフィールド追加は可。既存フィールドの意味は変えない)。

**`test/presentation/dashboard/dashboard_state_test.dart`**: `DashboardReady(...)` を直接作っている箇所すべてに `period: DisplayPeriod.week` を追加する(期待値は変えない)。他のテストで `DashboardReady(` を直接作っている箇所も同様。

### ウィジェットテスト(`test/presentation/dashboard/dashboard_screen_test.dart`)

既存の 17 ケースは変更しない(文言の追加で壊れる場合は、期待を変えず finder を絞る)。番号を続けて追加:

| # | ケース | 期待 |
|---|---|---|
| 18 | 期間切り替えは Ready のときだけ出る | `seedData()` → 表示後、`find.byType(SegmentedButton<DisplayPeriod>)` が 1 つ、`'7 日'` と `'30 日'` が見える。選択中が week(`tester.widget<SegmentedButton<DisplayPeriod>>(...).selected == {DisplayPeriod.week}`)。切り替えボタンの上端が `'睡眠'` 見出しより上。別途 `fake.permissions = bothDenied` で表示した場合と、`fake.availability = HealthAvailability.notInstalled` で表示した場合は `SegmentedButton<DisplayPeriod>` が無い |
| 19 | 30 日に切り替えると 30 日分を表示する | `seedData()` → 表示後 `tap(find.text('30 日'))` → `pumpAndSettle()`。`selected == {DisplayPeriod.month}`、`fake.stepsCalls.length == 37`、`'今日 10/6(火)'` が 2 つ(睡眠・歩数)、`tester.scrollUntilVisible(find.text('9/7(月)').first, 300)` で最古日の行に到達できる |
| 20 | 切り替え中はローディングを表示し、7 日に戻せる | `seedData()` → 表示後 `fake.readGate = Completer()` → `tap('30 日')` → `pump()`。`CircularProgressIndicator` があり、`SegmentedButton` は無い。`readGate.complete()` → `pumpAndSettle()` → `tap('7 日')` → `pumpAndSettle()`。`selected == {DisplayPeriod.week}`、`'9/30(水)'` が 2 つ、`fake.stepsCalls.length == 7 + 30 + 7` |
| 21 | 30 日でデータなしの案内が出る | 何も seed しない → 表示後 `tap('30 日')` → `pumpAndSettle()`。`'ヘルスコネクトにデータがありません'` があり、その上に `SegmentedButton` がある(上端の y 座標で比較) |
| 22 | 30 日で歩数だけ未許可の案内が崩れない | `fake.permissions = (steps: denied, sleep: granted)` → 表示後 `tap('30 日')` → `pumpAndSettle()`。歩数セクションに既存ケース 9 と同じ案内文言が出る |

## 依存ライブラリ

追加なし。

## ディレクトリ構造

```
lib/domain/models/display_period.dart                    (新規)
lib/domain/date_range_builder.dart                       (変更)
lib/domain/models/date_range.dart                        (コメントのみ)
lib/application/weekly_summary_service.dart              (変更)
lib/presentation/dashboard/dashboard_state.dart          (変更)
lib/presentation/dashboard/dashboard_controller.dart     (変更)
lib/presentation/dashboard/dashboard_screen.dart         (変更)
lib/presentation/rationale/permission_rationale_screen.dart (文言のみ)
test/domain/date_range_builder_test.dart                 (追加)
test/application/weekly_summary_service_test.dart        (追加)
test/presentation/dashboard/dashboard_controller_test.dart (追加)
test/presentation/dashboard/dashboard_state_test.dart    (引数追加)
test/presentation/dashboard/dashboard_screen_test.dart   (追加)
test/presentation/rationale/permission_rationale_screen_test.dart (文言)
```

`docs/` の更新は司令塔が行う(実装者は触らない)。

## 実装の順序

1. ドメイン(`DisplayPeriod` / `buildDateRange` / `DateRange` のコメント)+ テスト
2. `WeeklySummaryService` + テスト
3. `DashboardReady` / `DashboardController` + テスト(既存テストの `period:` 追加を含む)
4. `DashboardScreen` / `PermissionRationaleScreen` + テスト
5. 完了条件のコマンドを通す

## 完了条件

次をすべて通す:
1. `flutter analyze`
2. `dart format --output=none --set-exit-if-changed .`
3. `flutter test`
4. `bash scripts/check-layer-imports.sh`
5. `bash scripts/check-privacy.sh`

## セキュリティ考慮事項

- 健康データの値をログに出さない既存規則を守る(新しい `print` / `debugPrint` / `toString` を足さない)
- 依存・権限・マニフェストの変更なし

## パフォーマンス考慮事項

- 30 日表示の歩数は `readTotalSteps` を 30 回 `Future.wait` で並行実行する。各呼び出しはヘルスコネクト側の集計(aggregate)で、生データは転送しない
- 睡眠は 31 日分([oldestDay - 1 日, now])を 1 回で取得する
- 目標: 30 日表示でも起動から表示まで 3 秒以内(実機。#10 で確認)

## 将来の拡張性

- #21 のグラフは `DashboardReady.range` / `steps` / `sleep` をそのまま使える(横軸 = `range.days`)
- 期間の保存が必要になったら `_period` の初期値を `shared_preferences` から読む形に変える(#22 で導入される保存方式に合わせる)

## 9. 検収指摘の対応(code-reviewer 1 巡目)

### 9.1 `requestPermissions()` との競合テストを足す(`dashboard_controller_test.dart` の「表示期間」グループ)

| ケース | 手順 | 期待 |
|---|---|---|
| 権限リクエスト中の切り替え | `initial()` → `fake.requestGate = Completer()` → `fake.readGate = Completer()` → `r = controller().requestPermissions()` → `pump()` → 記録開始 → `s = controller().selectPeriod(DisplayPeriod.month)` → `pump()` → `requestGate.complete()` → `pump()` → `readGate.complete()` → `await Future.wait([r, s])` | 最終値が `period == month` で 30 日。記録した `AsyncData` の `DashboardReady` はすべて `period == month` |

`onResumed()` は `refresh()` 経由のため個別のテストは足さない。

### 9.2 競合テストがゲートに到達してから開けることを確かめる

「実行中の refresh があるときの切り替え」「連続切り替え」「権限リクエスト中の切り替え」の 3 ケースで、`readGate.complete()` の直前に `expect(fake.stepsCalls, isNotEmpty)` を入れ、読み取りがゲートで止まっている状態を作れていることを確認する(足りなければ `pump()` を増やす)。

さらに**一度だけ手元で mutation 確認**をする: `_isCurrent` の本体を一時的に `true` に変えて `flutter test test/presentation/dashboard/dashboard_controller_test.dart` を実行し、上の 3 ケースのうち少なくとも「実行中の refresh があるときの切り替え」「連続切り替え」が落ちることを確認してから元に戻す。落ちないケースがあれば、落ちるようにテストの手順を直す(コントローラーの実装は変えない)。結果は tasklist の申し送りに 1 行で書く。

### 9.3 切り替えボタンの読み上げ

`dashboard_screen.dart` の `SegmentedButton` を `Semantics(container: true, label: '表示期間', child: ...)` で包む。ウィジェットテスト 18 に `expect(find.bySemanticsLabel('表示期間'), findsOneWidget)` を足す(既存ケース 16 と同じ `SemanticsHandle` の扱いに従う)。タップ領域は Material 既定の `MaterialTapTargetSize.padded`(48dp)に任せ、`style` は指定しない。

### 9.4 見送り

- 切り替え中も `SegmentedButton` を残す案: 「決定事項」の理由により採らない
- docs の状態表「期間の切り替え後は前回の値を伴う」: Riverpod 3 の `AsyncLoading` が自動で前回の値を引き継ぐ仕様(「DashboardState」節)の記述であり、`requestPermissions()` と同じ書き方のため変えない
