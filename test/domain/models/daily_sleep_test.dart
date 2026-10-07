import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

void main() {
  group('DailySleep', () {
    test('複数セッション → total は duration の合計', () {
      final night = SleepSession(
        start: DateTime(2026, 10, 5, 23),
        end: DateTime(2026, 10, 6, 6),
      );
      final nap = SleepSession(
        start: DateTime(2026, 10, 6, 13),
        end: DateTime(2026, 10, 6, 13, 40),
      );
      final sleep = DailySleep(
        date: DateTime(2026, 10, 6),
        sessions: [night, nap],
      );

      expect(sleep.total, const Duration(hours: 7, minutes: 40));
      expect(sleep.hasRecord, isTrue);
    });

    test('セッションが空 → total は zero で記録なし', () {
      final sleep = DailySleep(date: DateTime(2026, 10, 6), sessions: const []);

      expect(sleep.total, Duration.zero);
      expect(sleep.hasRecord, isFalse);
    });
  });
}
