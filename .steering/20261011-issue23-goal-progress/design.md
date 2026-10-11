# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

ダッシュボードが `goalsControllerProvider`(#22)を **watch** し、目標値を各セクションへ渡す。判定は純 Dart のドメイン関数、描画はウィジェットが担う。`DashboardController` / `DashboardState` は**変更しない**(目標は健康データの読み込みと独立した状態であり、目標を変えたときにヘルスコネクトを読み直さないため)。

```
DashboardScreen ──watch──> goalsControllerProvider(既存。save() で state が置き換わる → 即座に再描画)
   │  goals.steps / goals.sleepMinutes
   ├─> StepsSection(goal) ──> stepsGoalStatus()(domain/goal_progress.dart)
   │                      └─> TrendBarChart(goalY)
   └─> SleepSection(goalMinutes) ──> sleepGoalStatus()
                               └─> TrendBarChart(goalY)
```

## 決定事項(Issue の「着手時に design.md で決める」ほか)

| 項目 | 決定 |
|---|---|
| 判定の境界 | **値 ≧ 目標 で達成**(目標ちょうどは達成) |
| 睡眠の比較単位 | `day.total.inMinutes`(秒は切り捨て。表示の `formatDuration` と同じ)と `goalMinutes` を比べる |
| 今日の歩数(途中値) | 目標以上なら**達成**。目標未満なら**判定しない**(`inProgress`。マークなし。「(途中)」の表示は従来どおり) |
| 今日の睡眠 | 他の日と同じに判定する(睡眠は起床日に帰属し、表示時点でその夜の睡眠は終わっているため) |
| 判定の優先順 | 目標なし → `notSet`、記録なし → `noRecord`、値 ≧ 目標 → `achieved`、途中値 → `inProgress`、それ以外 → `notAchieved` |
| マークの表現 | アイコン + 文言(色だけに頼らない)。達成 = `Icons.check_circle` + 「達成」、未達 = `Icons.remove_circle_outline` + 「未達」 |
| 未達の色 | エラー色は使わない(未達は異常ではない)。`onSurfaceVariant` |
| 目標ライン | 破線の水平線 + 右上に「目標」ラベル。グラフの縦軸上限は目標値を含むように切り上げる |
| 目標の表示 | 目標設定時、セクション見出しの下に「目標 8,000 歩」/「目標 7時間30分」を出す(ラインの値を文字で読めるようにする) |
| 目標の読み込み中・失敗 | 目標なしとして描画する(`GoalsController` は失敗時 `Goals()` を返す既存仕様) |
| 達成数の集計 | しない(P2) |

## コンポーネント設計

### 1. `lib/domain/goal_progress.dart`(新規。純 Dart)

```dart
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';

/// 1 日ぶんの目標の達成状況。
enum GoalStatus {
  /// 目標が設定されていない。
  notSet,

  /// その日の記録がない(判定しない)。
  noRecord,

  /// 今日の途中値が目標に届いていない(判定しない)。
  inProgress,

  /// 目標以上。
  achieved,

  /// 目標未満。
  notAchieved,
}

/// 歩数の達成状況。目標ちょうどは達成。今日の途中値は目標以上なら達成、未満なら判定しない。
GoalStatus stepsGoalStatus(DailySteps day, {required int? goal}) {
  if (goal == null) return GoalStatus.notSet;
  final steps = day.steps;
  if (steps == null) return GoalStatus.noRecord;
  if (steps >= goal) return GoalStatus.achieved;
  if (day.isToday) return GoalStatus.inProgress;
  return GoalStatus.notAchieved;
}

/// 睡眠時間の達成状況。合計時間(分。秒は切り捨て)が目標以上なら達成。
GoalStatus sleepGoalStatus(DailySleep day, {required int? goalMinutes}) {
  if (goalMinutes == null) return GoalStatus.notSet;
  if (!day.hasRecord) return GoalStatus.noRecord;
  return day.total.inMinutes >= goalMinutes
      ? GoalStatus.achieved
      : GoalStatus.notAchieved;
}
```

### 2. `lib/domain/trend_summary.dart`(変更)

#### 2-1. 読み上げ要約に目標を足す

- `stepsTrendSummary(List<DailySteps> days, {int? goal})`: 記録がある場合のみ、末尾に `、目標 ${formatSteps(goal)}` を足す(goal が null なら従来どおり)。記録なしの文言は変えない
  - 例: `歩数の推移グラフ。直近 7 日のうち記録のある日 2 日、1 日平均 5,821 歩、最多 8,432 歩、目標 8,000 歩`
- `sleepTrendSummary(List<DailySleep> days, {int? goalMinutes})`: 同様に末尾へ `、目標 ${formatDuration(Duration(minutes: goalMinutes))}`
  - 例: `…、1 日平均 7時間12分、最長 7時間12分、目標 7時間30分`

#### 2-2. 縦軸上限に目標を含める

既存の関数の**シグネチャは変えない**。呼び出し側(セクション)が目標値を値の列に足して渡す:

- 歩数: `stepsAxisMax([...days.map((d) => d.steps).whereType<int>(), ?goal])` 相当(Dart のバージョンで null-aware 要素が使えなければ `if (goal != null) goal`)
- 睡眠: `sleepAxisMaxHours([...記録のある日の total, if (goalMinutes != null) Duration(minutes: goalMinutes)])`

### 3. `lib/presentation/dashboard/widgets/trend_bar_chart.dart`(変更)

- コンストラクタに `this.goalY`(`final double? goalY;` 。doc コメント「目標ラインの値。null なら引かない。」)を追加(任意引数)
- `BarChartData` に次を追加(`goalY == null` なら `const ExtraLinesData()` = 線なし):

```dart
extraLinesData: goalY == null
    ? const ExtraLinesData()
    : ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: goalY!,
            color: colorScheme.onSurface,
            strokeWidth: 1.5,
            dashArray: const [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              style: labelStyle?.copyWith(color: colorScheme.onSurface),
              labelResolver: (_) => '目標',
            ),
          ),
        ],
      ),
```

- `goalY` はローカル変数に受けて `!` を避けてよい(書き方は任意)
- 全日記録なしの代替表示(「この期間の記録はありません」)のときは従来どおりグラフ自体を描かない(ラインも出ない)
- Semantics は従来どおり `semanticsLabel` 1 本(要約に目標が入るため、ここでは何もしない)

### 4. `lib/presentation/dashboard/widgets/goal_mark.dart`(新規。両セクション共通)

```dart
/// 一覧の行末に置く目標の達成マーク。目標が設定されているときだけ置く(notSet では置かない)。
/// 判定しない日(noRecord / inProgress)は同じ幅の空白にして、値の列を揃える。
class GoalMark extends StatelessWidget {
  const GoalMark({super.key, required this.status});

  final GoalStatus status;

  static const double width = 56;
  ...
}
```

- `build`: `SizedBox(width: GoalMark.width, child: ...)`。中身は
  - `achieved`: `Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.check_circle, size: 16, color: colorScheme.primary), SizedBox(width: 4), Text('達成', style: textTheme.labelMedium)])`
  - `notAchieved`: 同じ形で `Icons.remove_circle_outline` / `color: colorScheme.onSurfaceVariant` / `Text('未達', style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant))`
  - `noRecord` / `inProgress` / `notSet`: 子なし(`SizedBox` の空白のみ)
- `Icon` には `semanticLabel` を付けない(読み上げは文言「達成」「未達」が担い、行の `MergeSemantics` で「今日 10/6(火) 3,210 歩 達成」のように読まれる)

### 5. `lib/presentation/dashboard/widgets/steps_section.dart`(変更)

- コンストラクタに `required this.goal`(`final int? goal;` 。doc「1 日の歩数の目標。null は目標なし。」)を追加
- `MetricLoaded` の Column の先頭(グラフの前)に、`goal != null` のとき:
  ```dart
  Align(
    alignment: Alignment.centerLeft,
    child: Text('目標 ${formatSteps(goal)}', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
  ),
  const SizedBox(height: 8),
  ```
- `TrendBarChart` に `maxY`(2-2 の通り目標込み)・`goalY: goal?.toDouble()`・`semanticsLabel: stepsTrendSummary(days, goal: goal)` を渡す
- `_StepsRow` に `required this.goal`(`int?`)を追加。行の `Row` の末尾、値(と「(途中)」)の後ろに、`goal != null` のとき `const SizedBox(width: 8), GoalMark(status: stepsGoalStatus(day, goal: goal))` を足す。`goal == null` なら何も足さない(従来と同一のレイアウト)

### 6. `lib/presentation/dashboard/widgets/sleep_section.dart`(変更)

- コンストラクタに `required this.goalMinutes`(`final int? goalMinutes;` 。doc「1 日の睡眠時間の目標(分)。null は目標なし。」)
- 見出し下の目標表示: `'目標 ${formatDuration(Duration(minutes: goalMinutes))}'`(5 と同じ形)
- `TrendBarChart`: `maxY` は 2-2 の通り、`goalY: goalMinutes == null ? null : goalMinutes / 60`、`semanticsLabel: sleepTrendSummary(days, goalMinutes: goalMinutes)`
- `_SleepRow` に `required this.goalMinutes`。Row の末尾(合計時間の後ろ)に `goalMinutes != null` のとき `const SizedBox(width: 8), GoalMark(status: sleepGoalStatus(day, goalMinutes: goalMinutes))`
  - `_SleepRow` の Row は `crossAxisAlignment: start` のまま(マークは 1 行目に揃う)

### 7. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- `build` で `final goals = ref.watch(goalsControllerProvider).value ?? const Goals();` を取り、`_buildBody(async, goals)` → `_buildChildren(state, goals)` → `_buildReady(state, goals)` と引数で渡す
- `SleepSection(goalMinutes: goals.sleepMinutes, ...)` / `StepsSection(goal: goals.steps, ...)`
- import: `package:health_pixcel/domain/models/goals.dart` と `package:health_pixcel/presentation/goals/goals_controller.dart`
- `GoalSettingsScreen` で保存すると `GoalsController.save` が `state` を置き換えるため、戻った時点で再描画される(追加の処理は不要。`goalsControllerProvider` は autoDispose ではないので設定画面とダッシュボードで同じインスタンスを共有する)

## テスト設計

### `test/domain/goal_progress_test.dart`(新規)

`stepsGoalStatus`(goal = 8000):
- goal null → `notSet`(steps が null でも `notSet`。優先順の確認)
- steps null → `noRecord`
- 7999 → `notAchieved` / **8000 → `achieved`(境界)** / 8001 → `achieved`
- isToday かつ 7999 → `inProgress` / isToday かつ 8000 → `achieved`
- 0 歩(過去日) → `notAchieved`

`sleepGoalStatus`(goalMinutes = 450):
- goalMinutes null → `notSet`
- sessions 空 → `noRecord`
- 合計 449 分 → `notAchieved` / **450 分 → `achieved`(境界)** / 451 分 → `achieved`
- 合計 449 分 59 秒 → `notAchieved`(秒切り捨て)
- 2 セッション合計で 450 分 → `achieved`

### `test/domain/trend_summary_test.dart`(追加)

- `stepsTrendSummary(days, goal: 8000)` の末尾が `、目標 8,000 歩`
- 記録なしで goal ありでも従来の「記録はありません」の文言のまま
- `sleepTrendSummary(days, goalMinutes: 450)` の末尾が `、目標 7時間30分`
- goal 省略時は既存テストのとおり(既存テストは無変更で通ること)

### `test/presentation/dashboard/widgets/trend_bar_chart_test.dart`(追加)

- `goalY` 省略 → `tester.widget<BarChart>(find.byType(BarChart)).data.extraLinesData.horizontalLines` が空
- `goalY: 8000` → 1 本で `y == 8000`

### `test/presentation/dashboard/dashboard_screen_test.dart`(変更・追加)

- `pumpScreen` に名前付き引数 `Goals goals = const Goals()` を追加し、トップレベルの `late FakeGoalRepository goalRepository;` に `FakeGoalRepository()..stored = goals` を入れて `goalRepositoryProvider.overrideWithValue(goalRepository)` を overrides に**常に**含める(`...overrides` より前)。既存テストで `overrides` に `goalRepositoryProvider` を渡しているものがあれば、この引数に置き換える(同じプロバイダーの二重 override を避ける)
- 追加テスト(`seedData()` のデータ。2026-10-06 = 今日 3,210 歩、10-05 = 8,432 歩、睡眠は今日に記録あり):
  1. 目標なし → 「達成」「未達」「目標 」で始まるテキストが無い。各 `BarChart` の `horizontalLines` が空
  2. `Goals(steps: 8000)` → 「目標 8,000 歩」が表示される。10/5 の行に「達成」、今日の行(3,210 歩・途中)に「達成」「未達」が無い、記録なしの日にマークが無い(「達成」の数 = 1、「未達」の数 = 0 で確認してよい)。歩数グラフに y=8000 の線
  3. `Goals(steps: 3000)` → 今日の途中値 3,210 で「達成」(「達成」の数 = 2)
  4. `Goals(sleepMinutes: 600)` → 睡眠の記録がある日が「未達」(seedData の睡眠合計が 600 分未満であることを前提にする。前提が崩れる場合はテスト内で値を合わせる)
  5. 即時反映: 目標なしで表示 → `ProviderScope.containerOf(tester.element(find.byType(DashboardScreen))).read(goalsControllerProvider.notifier).save(const Goals(steps: 8000))` → `pump()` → 「目標 8,000 歩」と「達成」が出る
- 読み上げ: 2 のケースで、10/5 の行の `MergeSemantics` のラベルに「達成」が含まれることを `tester.getSemantics` で確認する(書きにくければ `find.bySemanticsLabel(RegExp('達成'))` が 1 件以上で可)

### `test/app_test.dart`(変更)

- 各 `ProviderScope` の overrides に `goalRepositoryProvider.overrideWithValue(FakeGoalRepository())` を足す(ダッシュボードが目標を読むようになり、テストで実 `SharedPreferencesAsync` を触らないため)

### 既存のセクション単体テストがあれば

- `StepsSection` / `SleepSection` を直接組み立てているテストがあれば、`goal: null` / `goalMinutes: null` を足して従来どおり通す

## 守ること

- `lib/domain/` に Flutter の import を入れない(`scripts/check-layer-imports.sh`)。`toString()` を実装しない(`scripts/check-privacy.sh`)
- 健康データの値・目標値をログに出さない
- 余白は 4 の倍数(上記の値はすべて満たす)。新しい色トークンを足さない
- 依存の追加なし

## 検収指摘の反映(code-reviewer。司令塔の判断済み)

### R1. `GoalMark` の幅を「固定」から「最小幅」にする

文字サイズを大きくすると「達成」が 56px に収まらず、行がはみ出す。

- `SizedBox(width: GoalMark.width, ...)` を `ConstrainedBox(constraints: const BoxConstraints(minWidth: GoalMark.width), child: ...)` に替える
- 中身が空になる状態(`noRecord` / `inProgress` / `notSet`)は `const SizedBox(width: GoalMark.width)` のまま(空白で値の列を揃える)
- `achieved` / `notAchieved` の `Row` は `mainAxisSize: MainAxisSize.min` にする
- テストを追加する(`dashboard_screen_test.dart`): `tester.platformDispatcher.textScaleFactorTestValue = 2.0`(`addTearDown` で `clearTextScaleFactorTestValue`)と `Goals(steps: 8000)` で表示し、`tester.takeException()` が null であることを確かめる(オーバーフローが無いこと)

### R2. 目標が縦軸の上限と同じ値でもラベルが欠けないようにする

目標が軸の上限ちょうど(例: 8,000 歩 → 上限 8,000)だと、線が枠の上端に乗る。`topRight` の「目標」ラベルが枠の外に出て、欠ける。

- 縦軸上限の計算に渡す目標値を **+1** する(上限が必ず目標より 1 段上に切り上がる)
  - 歩数: `stepsAxisMax([...値, if (goal != null) goal + 1])`(`?goal` の書き方は `goal == null ? null : goal + 1` 等に合わせて変えてよい)
  - 睡眠: `if (goalMinutes != null) Duration(minutes: goalMinutes + 1)`
- 例: 目標 8,000 歩 → 上限 10,000。目標 7時間30分 → 上限 8 時間。目標 10 時間 → 上限 12 時間
- テスト: `dashboard_screen_test.dart` の目標ラインのケースで、歩数グラフの `BarChart.data.maxY` が目標値より大きいことを確かめる(目標 8000 → `maxY == 10000`)。既存テストの期待値がこの変更で変わる場合は合わせる

### R3. 読み上げテストで、どの行に「達成」が付いたかを確かめる

`find.bySemanticsLabel(RegExp('達成'))` が 1 件以上あるだけでは、どの行に付いたかが分からない。

- 次の形に締める: `find.bySemanticsLabel(RegExp('10/5.*8,432 歩.*達成'))` が `findsOneWidget`
- 今日の行(3,210 歩・途中)の読み上げに「達成」「未達」が含まれないことも確かめる: `find.bySemanticsLabel(RegExp('10/6.*(達成|未達)'))` が `findsNothing`
- 実際のラベルの区切り(改行か空白か)はテストで確認し、正規表現を合わせる(`.*` を `[\s\S]*` にする等)

### docs 側

`docs/functional-design.md` の R2 の記述(「縦軸の上限は目標値より 1 段上に切り上げる」)は司令塔が直す。実装者は触らない。
