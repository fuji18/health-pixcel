import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
import 'package:health_pixcel/domain/trend_summary.dart';

DailySteps steps(int day, int? value) =>
    DailySteps(date: DateTime(2026, 10, day), steps: value, isToday: false);

DailySleep sleep(int day, List<(int, int)> sessions) => DailySleep(
  date: DateTime(2026, 10, day),
  sessions: [
    for (final (startHour, minutes) in sessions)
      SleepSession(
        start: DateTime(2026, 10, day, startHour),
        end: DateTime(2026, 10, day, startHour).add(Duration(minutes: minutes)),
      ),
  ],
);

void main() {
  group('stepsTrendSummary', () {
    test('全日記録あり', () {
      final days = [steps(1, 1000), steps(2, 2000), steps(3, 6000)];
      expect(
        stepsTrendSummary(days),
        '歩数の推移グラフ。直近 3 日のうち記録のある日 3 日、'
        '1 日平均 3,000 歩、最多 6,000 歩',
      );
    });

    test('一部記録なし', () {
      final days = [steps(1, 1000), steps(2, null), steps(3, 2001)];
      expect(
        stepsTrendSummary(days),
        '歩数の推移グラフ。直近 3 日のうち記録のある日 2 日、'
        '1 日平均 1,501 歩、最多 2,001 歩',
      );
    });

    test('全日記録なし', () {
      expect(
        stepsTrendSummary([steps(1, null), steps(2, null)]),
        '歩数の推移グラフ。直近 2 日、記録はありません',
      );
    });
  });

  group('sleepTrendSummary', () {
    test('全日記録あり(複数セッションの日を含む)', () {
      final days = [
        sleep(1, [(23, 360)]),
        sleep(2, [(22, 240), (5, 120)]),
      ];
      expect(
        sleepTrendSummary(days),
        '睡眠時間の推移グラフ。直近 2 日のうち記録のある日 2 日、'
        '1 日平均 6時間、最長 6時間',
      );
    });

    test('一部記録なし', () {
      final days = [
        sleep(1, [(23, 432)]),
        sleep(2, []),
        sleep(3, [(23, 45)]),
      ];
      expect(
        sleepTrendSummary(days),
        '睡眠時間の推移グラフ。直近 3 日のうち記録のある日 2 日、'
        '1 日平均 3時間59分、最長 7時間12分',
      );
    });

    test('全日記録なし', () {
      expect(
        sleepTrendSummary([sleep(1, []), sleep(2, [])]),
        '睡眠時間の推移グラフ。直近 2 日、記録はありません',
      );
    });
  });

  group('stepsAxisMax', () {
    test('2,000 歩単位で切り上げ、最小 2,000', () {
      expect(stepsAxisMax([]), 2000);
      expect(stepsAxisMax([0]), 2000);
      expect(stepsAxisMax([2000]), 2000);
      expect(stepsAxisMax([8432]), 10000);
      expect(stepsAxisMax([12001]), 14000);
    });
  });

  group('sleepAxisMaxHours', () {
    test('2 時間単位で切り上げ、最小 2', () {
      expect(sleepAxisMaxHours([]), 2);
      expect(sleepAxisMaxHours([const Duration(hours: 6)]), 6);
      expect(sleepAxisMaxHours([const Duration(hours: 7, minutes: 12)]), 8);
      expect(sleepAxisMaxHours([const Duration(minutes: 45)]), 2);
    });
  });
}
