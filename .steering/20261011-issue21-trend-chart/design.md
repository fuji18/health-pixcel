# 設計書

<!-- status: ready -->

## アーキテクチャ概要

既存のレイヤー構成(domain / application / data / presentation)は変えない。データ取得は既存の `MetricLoaded.days` をそのまま使い、新しい取得処理は足さない。

```
DashboardReady.steps / .sleep (MetricLoaded.days = 新しい順)
   │
   ├─ StepsSection / SleepSection(MetricLoaded の分岐だけ変更)
   │     ├─ TrendBarChart  ← 新規。fl_chart の BarChart を包む汎用ウィジェット
   │     └─ 既存の日別一覧(変更なし)
   │
   └─ lib/domain/trend_summary.dart ← 新規。読み上げ要約と縦軸上限の純粋関数
      lib/domain/formatters.dart    ← formatShortDate / formatNumber を追加
```

- `package:fl_chart/` を import してよいのは `lib/presentation/` 配下だけ(今回は `trend_bar_chart.dart` とそのテストのみ)
- `scripts/check-layer-imports.sh` は変更しない(委託禁止領域。今回の import は既存ルールに抵触しない)

## コンポーネント設計

### 1. `lib/domain/formatters.dart`(追記)

既存関数は変更しない。次の 2 関数を末尾に追加する。

```dart
/// 日付を `10/6` 形式にする(グラフの横軸ラベル用)。
///
/// 事前に `initializeDateFormatting('ja')` が必要。
String formatShortDate(DateTime date) => DateFormat('M/d', 'ja').format(date);

/// 整数を `8,432` 形式にする(3 桁区切りは半角 `,`。単位なし)。
String formatNumber(int value) => NumberFormat('#,##0', 'ja').format(value);
```

### 2. `lib/domain/trend_summary.dart`(新規)

Flutter に依存しない純粋関数。import は `daily_steps.dart` / `daily_sleep.dart` / `formatters.dart` と `dart:math` のみ。

```dart
/// 歩数グラフの読み上げ要約。[days] は表示期間の全日(順不同)。
String stepsTrendSummary(List<DailySteps> days)

/// 睡眠時間グラフの読み上げ要約。[days] は表示期間の全日(順不同)。
String sleepTrendSummary(List<DailySleep> days)

/// 歩数グラフの縦軸上限。2,000 歩単位で切り上げ、最小 2,000。
double stepsAxisMax(Iterable<int> values)

/// 睡眠グラフの縦軸上限(時間)。2 時間単位で切り上げ、最小 2。
double sleepAxisMaxHours(Iterable<Duration> totals)
```

**要約の文言(固定。半角スペースの位置も含めてこの通り)**

`n = days.length`、`k = 記録のある日の数`(歩数は `steps != null`、睡眠は `hasRecord`)。

| 条件 | 歩数 | 睡眠 |
|---|---|---|
| `k == 0` | `歩数の推移グラフ。直近 $n 日、記録はありません` | `睡眠時間の推移グラフ。直近 $n 日、記録はありません` |
| `k > 0` | `歩数の推移グラフ。直近 $n 日のうち記録のある日 $k 日、1 日平均 ${formatSteps(avg)}、最多 ${formatSteps(max)}` | `睡眠時間の推移グラフ。直近 $n 日のうち記録のある日 $k 日、1 日平均 ${formatDuration(avg)}、最長 ${formatDuration(max)}` |

- 歩数の `avg = (記録のある日の合計 / k).round()`、`max` = 記録のある日の最大値。今日の途中値も含める
- 睡眠の `avg = Duration(minutes: (記録のある日の total.inMinutes の合計 / k).round())`、`max` = 記録のある日の `total` の最大値

**縦軸上限の計算**

- `stepsAxisMax`: `m` = 最大値(空なら 0)。`max(2000, ((m + 1999) ~/ 2000) * 2000).toDouble()`
  - 例: 空 → 2000 / 0 → 2000 / 2000 → 2000 / 8432 → 10000 / 12001 → 14000
- `sleepAxisMaxHours`: `m` = 最大の `inMinutes`(空なら 0)。`max(2, ((m + 119) ~/ 120) * 2).toDouble()`
  - 例: 空 → 2 / 6時間00分 → 6 / 7時間12分 → 8 / 45分 → 2

上限は常に偶数(歩数は 2,000 の倍数)なので、`上限 / 2` の中間線も整数(歩数は 1,000 の倍数)になる。

### 3. `lib/presentation/dashboard/widgets/trend_bar_chart.dart`(新規)

```dart
/// 日別の推移を棒グラフで描く。記録なしの日は棒も下地も描かない。
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({
    super.key,
    required this.dates,
    required this.values,
    required this.maxY,
    required this.axisLabel,
    required this.semanticsLabel,
  });

  /// 各棒の日付。古い順(左が古い)。
  final List<DateTime> dates;

  /// 各棒の値。[dates] と同じ長さ・同じ順。null は記録なし。
  final List<double?> values;

  /// 縦軸の上限。
  final double maxY;

  /// 縦軸ラベルの文字列。
  final String Function(double value) axisLabel;

  /// スクリーンリーダー向けの要約。
  final String semanticsLabel;
}
```

**build の構造**

```
Semantics(container: true, label: semanticsLabel,
  child: ExcludeSemantics(
    child: SizedBox(width: double.infinity, height: 160, child: <中身>)))
```

- **中身(全日 null のとき)**: `Center(child: Text('この期間の記録はありません', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)))`。`BarChart` は作らない
- **中身(それ以外)**: `BarChart(data, duration: Duration.zero)`(アニメーションなし)

**`BarChartData` の指定(これ以外の引数は既定値のまま)**

| 引数 | 値 |
|---|---|
| `alignment` | `BarChartAlignment.spaceAround` |
| `minY` / `maxY` | `0` / `maxY` |
| `barTouchData` | `BarTouchData(enabled: false)` |
| `borderData` | `FlBorderData(show: false)` |
| `gridData` | `FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 2, getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outlineVariant, strokeWidth: 1))` |
| `titlesData` | 下表 |
| `barGroups` | `for (var i = 0; i < n; i++) BarChartGroupData(x: i, barRods: [rod(i)])` |

`titlesData` は `FlTitlesData(...)`:

- `topTitles` / `rightTitles`: `AxisTitles(sideTitles: SideTitles(showTitles: false))`
- `leftTitles`: `AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48, interval: maxY / 2, minIncluded: false, getTitlesWidget: (value, meta) => SideTitleWidget(meta: meta, child: Text(axisLabel(value), style: labelStyle))))`
  - 結果として中間線と上限の 2 つだけにラベルが付く(0 は出さない)
- `bottomTitles`: `AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: _bottomTitle))`
  - `_bottomTitle(value, meta)`: `i = value.toInt()`。`n <= 7 || (n - 1 - i) % 7 == 0` のときだけ `SideTitleWidget(meta: meta, child: Text(formatShortDate(dates[i]), style: labelStyle))`、それ以外は `const SizedBox.shrink()`
  - 30 日表示では今日(右端)から 7 日おきにラベルが付く(右端は必ず付く)
- `labelStyle = textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)`

**棒 `rod(i)`**(`width = n <= 7 ? 16.0 : 6.0`)

- 値あり(0 を含む):
  ```dart
  BarChartRodData(
    toY: values[i]!,
    color: colorScheme.primary,
    width: width,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
    backDrawRodData: BackgroundBarChartRodData(
      show: true, toY: maxY, color: colorScheme.surfaceContainerHighest),
  )
  ```
- 記録なし(null): `BarChartRodData(toY: 0, color: Colors.transparent, width: width)`(`backDrawRodData` は既定 = `show: false`)
  - **空の `barRods` にしない**。グループ幅が 0 になり `spaceAround` の間隔が崩れるため、透明な棒で幅だけ確保する

区別の根拠: 記録のある日には常に下地(縦長のトラック)があり、記録なしの日には何も無い。色ではなく形の有無で区別する(`docs/ui-design-guidelines.md` §5)。値 0 の日も下地があるので記録なしと見分けられる。

### 4. `StepsSection` / `SleepSection`(変更)

変更するのは `MetricLoaded` の分岐だけ。既存の行ウィジェット(`_StepsRow` / `_SleepRow`)と他の分岐はそのまま残す。

**歩数**(`steps_section.dart`)

```dart
MetricLoaded<DailySteps>(:final days) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TrendBarChart(
      dates: [for (final d in days.reversed) d.date],
      values: [for (final d in days.reversed) d.steps?.toDouble()],
      maxY: stepsAxisMax(days.map((d) => d.steps).whereType<int>()),
      axisLabel: (v) => formatNumber(v.round()),
      semanticsLabel: stepsTrendSummary(days),
    ),
    const SizedBox(height: 16),
    for (final day in days) _StepsRow(day: day, today: today),
  ],
),
```

**睡眠**(`sleep_section.dart`)

```dart
MetricLoaded<DailySleep>(:final days) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TrendBarChart(
      dates: [for (final d in days.reversed) d.date],
      values: [
        for (final d in days.reversed)
          d.hasRecord ? d.total.inMinutes / 60 : null,
      ],
      maxY: sleepAxisMaxHours(
        days.where((d) => d.hasRecord).map((d) => d.total),
      ),
      axisLabel: (v) => '${v.round()}時間',
      semanticsLabel: sleepTrendSummary(days),
    ),
    const SizedBox(height: 16),
    for (final day in days) _SleepRow(day: day, today: today),
  ],
),
```

- `days` は新しい順(`MetricLoaded` の契約)なので、グラフには `reversed` で古い順に渡す
- 両クラスの doc コメントの「7 行の一覧」は「推移グラフと日別一覧」に直す

## データフロー

### 期間の切り替え
```
1. SegmentedButton → DashboardController.selectPeriod(既存)
2. DashboardReady が新しい期間の days(7 / 30 件)で再構築される(既存)
3. 各セクションが days から TrendBarChart の dates / values / maxY / 要約を作り直す(新規)
```

## エラーハンドリング戦略

新しいエラーは無い。`MetricPermissionDenied` / `MetricFailed` のときはグラフを出さず、既存の案内表示のまま。

## テスト戦略

### ユニットテスト
- `test/domain/formatters_test.dart` に追記: `formatShortDate(DateTime(2026, 10, 6)) == '10/6'`、`formatNumber(0) == '0'`、`formatNumber(8432) == '8,432'`、`formatNumber(12000) == '12,000'`
- `test/domain/trend_summary_test.dart`(新規):
  - `stepsTrendSummary`: 全日記録あり / 一部記録なし / 全日記録なし の 3 ケースで、上の表どおりの完全一致文字列
  - `sleepTrendSummary`: 同じ 3 ケース(複数セッションの日を 1 つ含める)
  - `stepsAxisMax` / `sleepAxisMaxHours`: 「縦軸上限の計算」の例をすべて

### ウィジェットテスト
- `test/presentation/dashboard/widgets/trend_bar_chart_test.dart`(新規)。`setUpAll(() => initializeDateFormatting('ja'))`。`MaterialApp(home: Scaffold(body: TrendBarChart(...)))` で pump する。棒の検査は `tester.widget<BarChart>(find.byType(BarChart)).data.barGroups` を読む
  1. **データあり(7 日・全日値あり)**: `barGroups.length == 7`。全棒の `backDrawRodData.show == true`、`color == colorScheme.primary`、`width == 16`。`find.bySemanticsLabel(要約)` が 1 件
  2. **一部記録なし(7 日、index 1 と 4 が null、index 2 が 0)**: null の棒は `color == Colors.transparent` かつ `backDrawRodData.show == false`。値 0 の棒は `backDrawRodData.show == true`
  3. **全日記録なし**: `find.byType(BarChart)` が 0 件、`find.text('この期間の記録はありません')` が 1 件、要約ラベルが 1 件
  4. **30 日**: `barGroups.length == 30`、棒の `width == 6`。右端の日付ラベル(`formatShortDate(dates.last)`)が表示され、右から 2 番目(`formatShortDate(dates[28])`)は表示されない
- `test/presentation/dashboard/dashboard_screen_test.dart` に追記:
  - **23 グラフは歩数・睡眠の両方に出て、期間に追従する**: `seedData()` → 7 日で `find.byType(BarChart)` が 2 件、各 `barGroups.length == 7`。`30 日` をタップ → `pumpAndSettle` → 各 `barGroups.length == 30`。BarChart が画面外で見つからなければ `find.byType(BarChart, skipOffstage: false)` を使う
  - **24 未許可のセクションにはグラフが出ない**: 歩数だけ未許可(テスト 9 と同じ準備)で `find.byType(BarChart)` が 1 件
- **既存テストの扱い**: グラフで縦が 2 × 176px 伸びるため、既存テストが「画面外で見つからない」理由だけで落ちた場合は、`pumpScreen` の `physicalSize` の高さを `2400` から `3000` に上げて対応する。**期待値(件数・文言・順序)は変えない**。それ以外の理由で落ちたら停止して報告する

### 検収指摘によるテスト追加(2026-10-11)

code-reviewer の minor 指摘 2〜4 を受けて追加する。実装コード(`lib/`)は変えない。

- `trend_bar_chart_test.dart`
  - **縦軸ラベル**: `maxY: 10`、`axisLabel: (v) => '${v.round()}件'` のケースで `find.text('5件')` と `find.text('10件')` が各 1 件以上、`find.text('0件')` が 0 件
  - **棒の高さ**: 「一部記録なし」ケースで、値ありの棒の `toY` が `values[i]` と一致し、値 0 の棒は `toY == 0`、null の棒は `toY == 0`
- `dashboard_screen_test.dart` のテスト 24: `find.byType(BarChart)` が 1 件であることに加え、`find.descendant(of: find.byType(StepsSection), matching: find.byType(BarChart))` が 0 件、`SleepSection` 配下が 1 件であることを確認する

## 依存ライブラリ

```yaml
dependencies:
  fl_chart: ^1.2.0
```

- `flutter pub add fl_chart:^1.2.0` で追加し、`pubspec.lock` もコミットに含める
- 審査結果(司令塔が 2026-10-11 に pub キャッシュのソースで確認済み): `fl_chart` 1.2.0 の依存は `equatable` ^2.0.7 / `vector_math` ^2.2.0 のみ。`equatable` 2.0.7 の依存は `collection` / `meta` のみ。いずれも `dart:io`・`package:http`・解析 SDK の import は無い。PR 本文に転記する
- 追加後、`pubspec.lock` に上記以外の新規パッケージが増えていたら停止して報告する

## ディレクトリ構造

```
lib/domain/formatters.dart                                  # 追記
lib/domain/trend_summary.dart                               # 新規
lib/presentation/dashboard/widgets/trend_bar_chart.dart     # 新規
lib/presentation/dashboard/widgets/steps_section.dart       # 変更
lib/presentation/dashboard/widgets/sleep_section.dart       # 変更
test/domain/formatters_test.dart                            # 追記
test/domain/trend_summary_test.dart                         # 新規
test/presentation/dashboard/widgets/trend_bar_chart_test.dart  # 新規
test/presentation/dashboard/dashboard_screen_test.dart      # 追記
pubspec.yaml / pubspec.lock                                 # 依存追加
docs/functional-design.md / docs/architecture.md / docs/repository-structure.md  # 更新
```

## ドキュメント更新の内容

- `docs/functional-design.md`
  - 「画面・ウィジェット」の表: `StepsSection` / `SleepSection` の責務を「推移グラフ(`TrendBarChart`)と期間の日数分の一覧 …」に直し、`TrendBarChart` の行を追加(「日別の値を棒グラフで描く。記録なしの日は棒も下地も描かない。全日記録なしなら代替文言。グラフ全体の要約を Semantics で読ませる」)
  - 「画面レイアウト(DashboardReady)」の図: 睡眠・歩数それぞれの見出しの直下に `[ 推移グラフ(棒)。左が古い日 ]` の 1 行を追加
  - 「表示項目」に「推移グラフ(睡眠・歩数共通)」の小節を追加: 横軸 = 日付(7 日は全日、30 日は今日から 7 日おき、`M/d`)、縦軸 = 歩数(2,000 歩単位で切り上げ)/ 睡眠時間(2 時間単位)、記録なしは棒も下地も無し、全日記録なしは「この期間の記録はありません」、読み上げ要約の文言(この design.md の表)
  - 「カラーコーディング」に 1 行: 棒は `primary`、記録のある日の下地は `surfaceContainerHighest`、補助線は `outlineVariant`。記録の有無は下地の有無(形)で区別する
  - 「テスト戦略 > ウィジェットテスト」に 1 行: 推移グラフ(データあり / 一部記録なし / 全日記録なし / 30 日)
- `docs/architecture.md` 23 行目の `**グラフのチケットで追加する**` を `#21 で追加` に直す
- `docs/repository-structure.md`: `lib/domain/` のツリーに `trend_summary.dart  # 推移グラフの読み上げ要約・縦軸上限`、widgets のツリーに `trend_bar_chart.dart  # TrendBarChart`、test のツリーに対応するテストファイルを既存の書式で追加

## 実装の順序

1. 依存追加(`pubspec.yaml` / `pubspec.lock`)
2. `formatters.dart` 追記 + テスト
3. `trend_summary.dart` + テスト
4. `trend_bar_chart.dart` + テスト
5. 両セクションへの組み込み + `dashboard_screen_test.dart` 追記
6. docs 更新

## セキュリティ考慮事項

- 新規依存は通信・解析 SDK を含まない(上記審査)。リリース APK に `INTERNET` が無いことは CI の権限検査で確認する(devcontainer では実行できない)

## パフォーマンス考慮事項

- 最大 30 本 × 2 グラフ。アニメーション無し・タッチ無効のため再描画は期間切り替え時のみ

## 将来の拡張性

- 目標ライン(#23)は `BarChartData.extraLinesData` で `TrendBarChart` に引数を足して対応できる。今回は引数を追加しない
