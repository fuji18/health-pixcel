import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';

void main() {
  group('buildDateRange', () {
    test('通常日 → 今日から 6 日前まで新しい順', () {
      final range = buildDateRange(DateTime(2026, 10, 6, 9, 30));

      expect(range.today, DateTime(2026, 10, 6));
      expect(range.days, [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 4),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 1),
        DateTime(2026, 9, 30),
      ]);
      expect(range.oldestDay, DateTime(2026, 9, 30));
    });

    test('月またぎ → 前月の日付が入る', () {
      final range = buildDateRange(DateTime(2026, 10, 3, 12));

      expect(range.days, [
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 1),
        DateTime(2026, 9, 30),
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 27),
      ]);
    });

    test('年またぎ → 前年の日付が入る', () {
      final range = buildDateRange(DateTime(2026, 1, 3, 12));

      expect(range.days, [
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 1),
        DateTime(2025, 12, 31),
        DateTime(2025, 12, 30),
        DateTime(2025, 12, 29),
        DateTime(2025, 12, 28),
      ]);
    });

    test('23:59 → 今日は同じ日', () {
      final range = buildDateRange(DateTime(2026, 10, 6, 23, 59, 59));

      expect(range.today, DateTime(2026, 10, 6));
      expect(range.days.first, DateTime(2026, 10, 6));
    });

    test('全日が 00:00', () {
      final inputs = [
        DateTime(2026, 10, 6, 9, 30),
        DateTime(2026, 10, 3, 12),
        DateTime(2026, 1, 3, 12),
        DateTime(2026, 10, 6, 23, 59, 59),
      ];

      for (final now in inputs) {
        final range = buildDateRange(now);

        expect(range.days.length, 7);
        for (final d in range.days) {
          expect(d.hour, 0);
          expect(d.minute, 0);
          expect(d.second, 0);
          expect(d.millisecond, 0);
          expect(d.microsecond, 0);
        }
      }
    });

    test('now が保持される', () {
      final now = DateTime(2026, 10, 6, 23, 59, 59);

      final range = buildDateRange(now);

      expect(range.now, now);
    });

    test('days を変更しようとする → UnsupportedError', () {
      final range = buildDateRange(DateTime(2026, 10, 6, 9, 30));

      expect(
        () => range.days.add(DateTime(2026, 10, 7)),
        throwsUnsupportedError,
      );
    });
  });

  group('nextDay', () {
    test('通常日 → 翌日', () {
      expect(nextDay(DateTime(2026, 10, 6)), DateTime(2026, 10, 7));
    });

    test('月末 → 翌月 1 日', () {
      expect(nextDay(DateTime(2026, 10, 31)), DateTime(2026, 11, 1));
    });

    test('年末 → 翌年 1 日', () {
      expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });
  });
}
