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
