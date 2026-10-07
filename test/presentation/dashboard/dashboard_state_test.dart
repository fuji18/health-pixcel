import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
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
  const noSteps = <int?>[null, null, null, null, null, null, null];

  DashboardReady ready(
    MetricResult<DailySteps> steps,
    MetricResult<DailySleep> sleep,
  ) => DashboardReady(range: range, steps: steps, sleep: sleep);

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
  });
}
