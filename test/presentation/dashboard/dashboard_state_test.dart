import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';
import 'package:health_pixcel/domain/models/daily_exercise.dart';
import 'package:health_pixcel/domain/models/daily_heart_rate.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/daily_weight.dart';
import 'package:health_pixcel/domain/models/display_period.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';
import 'package:health_pixcel/domain/models/heart_rate_stats.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_state.dart';

void main() {
  final range = buildDateRange(DateTime(2026, 10, 6, 10, 30));

  MetricLoaded<DailySteps> stepsOf(List<int?> values) => MetricLoaded([
    for (var i = 0; i < 7; i++)
      DailySteps(date: range.days[i], steps: values[i], isToday: i == 0),
  ]);
  MetricLoaded<DailySleep> sleepOf({bool withRecordOnToday = false}) =>
      MetricLoaded([
        for (var i = 0; i < 7; i++)
          DailySleep(
            date: range.days[i],
            sessions: i == 0 && withRecordOnToday
                ? [
                    SleepSession(
                      start: DateTime(2026, 10, 5, 23),
                      end: DateTime(2026, 10, 6, 7),
                    ),
                  ]
                : const [],
          ),
      ]);
  MetricLoaded<DailyHeartRate> heartOf({bool withRecordOnToday = false}) =>
      MetricLoaded([
        for (var i = 0; i < 7; i++)
          DailyHeartRate(
            date: range.days[i],
            stats: i == 0 && withRecordOnToday
                ? const HeartRateStats(average: 68, min: 52, max: 128)
                : null,
            isToday: i == 0,
          ),
      ]);
  MetricLoaded<DailyWeight> weightOf({bool withRecordOnToday = false}) =>
      MetricLoaded([
        for (var i = 0; i < 7; i++)
          DailyWeight(
            date: range.days[i],
            kg: i == 0 && withRecordOnToday ? 65.3 : null,
            isToday: i == 0,
          ),
      ]);
  MetricLoaded<DailyExercise> exerciseOf({bool withRecordOnToday = false}) =>
      MetricLoaded([
        for (var i = 0; i < 7; i++)
          DailyExercise(
            date: range.days[i],
            sessions: i == 0 && withRecordOnToday
                ? [
                    ExerciseSession(
                      start: DateTime(2026, 10, 6, 7),
                      end: DateTime(2026, 10, 6, 7, 45),
                    ),
                  ]
                : const [],
            isToday: i == 0,
          ),
      ]);
  const noSteps = <int?>[null, null, null, null, null, null, null];

  DashboardReady ready(
    MetricResult<DailySteps> steps,
    MetricResult<DailySleep> sleep, [
    MetricResult<DailyHeartRate> heartRate = const MetricPermissionDenied(),
    MetricResult<DailyWeight> weight = const MetricPermissionDenied(),
    MetricResult<DailyExercise> exercise = const MetricPermissionDenied(),
  ]) => DashboardReady(
    period: DisplayPeriod.week,
    range: range,
    steps: steps,
    sleep: sleep,
    heartRate: heartRate,
    weight: weight,
    exercise: exercise,
  );

  group('isAllEmpty', () {
    test('片方未許可 + 片方全日記録なし', () {
      expect(
        ready(const MetricPermissionDenied(), sleepOf()).isAllEmpty,
        isTrue,
      );
    });
    test('両方 Loaded・全日記録なし', () {
      expect(ready(stepsOf(noSteps), sleepOf()).isAllEmpty, isTrue);
    });
    test('歩数に記録あり', () {
      final values = <int?>[8432, null, null, null, null, null, null];
      expect(ready(stepsOf(values), sleepOf()).isAllEmpty, isFalse);
    });
    test('睡眠に記録あり', () {
      expect(
        ready(stepsOf(noSteps), sleepOf(withRecordOnToday: true)).isAllEmpty,
        isFalse,
      );
    });
    test('片方 MetricFailed', () {
      expect(
        ready(
          const MetricFailed(HealthErrorKind.readFailed),
          sleepOf(),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('両方未許可', () {
      expect(
        ready(
          const MetricPermissionDenied(),
          const MetricPermissionDenied(),
        ).isAllEmpty,
        isFalse,
      );
    });

    test('心拍だけ記録あり', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(withRecordOnToday: true),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('3 種とも全日記録なし', () {
      expect(ready(stepsOf(noSteps), sleepOf(), heartOf()).isAllEmpty, isTrue);
    });
    test('心拍が MetricFailed', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          const MetricFailed(HealthErrorKind.readFailed),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('心拍だけ未許可で歩数・睡眠が全日記録なし', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          const MetricPermissionDenied(),
        ).isAllEmpty,
        isTrue,
      );
    });

    test('体重だけ記録あり', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          weightOf(withRecordOnToday: true),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('4 種とも全日記録なし', () {
      expect(
        ready(stepsOf(noSteps), sleepOf(), heartOf(), weightOf()).isAllEmpty,
        isTrue,
      );
    });
    test('体重が MetricFailed', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          const MetricFailed(HealthErrorKind.readFailed),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('体重だけ未許可で他 3 種が全日記録なし', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          const MetricPermissionDenied(),
        ).isAllEmpty,
        isTrue,
      );
    });

    test('運動だけ記録あり', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          weightOf(),
          exerciseOf(withRecordOnToday: true),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('5 種とも全日記録なし', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          weightOf(),
          exerciseOf(),
        ).isAllEmpty,
        isTrue,
      );
    });
    test('運動が MetricFailed', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          weightOf(),
          const MetricFailed(HealthErrorKind.readFailed),
        ).isAllEmpty,
        isFalse,
      );
    });
    test('運動だけ未許可で他 4 種が全日記録なし', () {
      expect(
        ready(
          stepsOf(noSteps),
          sleepOf(),
          heartOf(),
          weightOf(),
          const MetricPermissionDenied(),
        ).isAllEmpty,
        isTrue,
      );
    });
  });
}
