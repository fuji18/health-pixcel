import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/goal_progress.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

DailySteps steps(int? value, {bool isToday = false}) =>
    DailySteps(date: DateTime(2026, 10, 6), steps: value, isToday: isToday);

DailySleep sleepOf(List<Duration> durations) {
  var start = DateTime(2026, 10, 5, 0);
  final sessions = <SleepSession>[];
  for (final d in durations) {
    sessions.add(SleepSession(start: start, end: start.add(d)));
    start = start.add(d).add(const Duration(minutes: 1));
  }
  return DailySleep(date: DateTime(2026, 10, 6), sessions: sessions);
}

void main() {
  group('stepsGoalStatus', () {
    test('目標なしは notSet(記録なしでも)', () {
      expect(stepsGoalStatus(steps(null), goal: null), GoalStatus.notSet);
      expect(stepsGoalStatus(steps(100), goal: null), GoalStatus.notSet);
    });

    test('記録なしは noRecord', () {
      expect(stepsGoalStatus(steps(null), goal: 8000), GoalStatus.noRecord);
    });

    test('境界', () {
      expect(stepsGoalStatus(steps(7999), goal: 8000), GoalStatus.notAchieved);
      expect(stepsGoalStatus(steps(8000), goal: 8000), GoalStatus.achieved);
      expect(stepsGoalStatus(steps(8001), goal: 8000), GoalStatus.achieved);
    });

    test('今日の途中値', () {
      expect(
        stepsGoalStatus(steps(7999, isToday: true), goal: 8000),
        GoalStatus.inProgress,
      );
      expect(
        stepsGoalStatus(steps(8000, isToday: true), goal: 8000),
        GoalStatus.achieved,
      );
    });

    test('0 歩の過去日は notAchieved', () {
      expect(stepsGoalStatus(steps(0), goal: 8000), GoalStatus.notAchieved);
    });
  });

  group('sleepGoalStatus', () {
    test('目標なしは notSet', () {
      expect(
        sleepGoalStatus(sleepOf([const Duration(hours: 8)]), goalMinutes: null),
        GoalStatus.notSet,
      );
    });

    test('記録なしは noRecord', () {
      expect(
        sleepGoalStatus(sleepOf([]), goalMinutes: 450),
        GoalStatus.noRecord,
      );
    });

    test('境界', () {
      expect(
        sleepGoalStatus(
          sleepOf([const Duration(minutes: 449)]),
          goalMinutes: 450,
        ),
        GoalStatus.notAchieved,
      );
      expect(
        sleepGoalStatus(
          sleepOf([const Duration(minutes: 450)]),
          goalMinutes: 450,
        ),
        GoalStatus.achieved,
      );
      expect(
        sleepGoalStatus(
          sleepOf([const Duration(minutes: 451)]),
          goalMinutes: 450,
        ),
        GoalStatus.achieved,
      );
    });

    test('秒は切り捨て', () {
      expect(
        sleepGoalStatus(
          sleepOf([const Duration(minutes: 449, seconds: 59)]),
          goalMinutes: 450,
        ),
        GoalStatus.notAchieved,
      );
    });

    test('複数セッションの合計', () {
      expect(
        sleepGoalStatus(
          sleepOf([const Duration(minutes: 400), const Duration(minutes: 50)]),
          goalMinutes: 450,
        ),
        GoalStatus.achieved,
      );
    });
  });
}
