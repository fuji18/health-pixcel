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

  group('buildDateRange 30 日', () {
    test('通常', () {
      final r = buildDateRange(DateTime(2026, 10, 6, 9, 30), dayCount: 30);
      expect(r.days.length, 30);
      expect(r.days.first, DateTime(2026, 10, 6));
      expect(r.days[1], DateTime(2026, 10, 5));
      expect(r.oldestDay, DateTime(2026, 9, 7));
      expect(r.today, DateTime(2026, 10, 6));
    });

    test('月またぎ(2 月を含む)', () {
      final r = buildDateRange(DateTime(2026, 3, 15, 12), dayCount: 30);
      expect(r.days[14], DateTime(2026, 3, 1));
      expect(r.days[15], DateTime(2026, 2, 28));
      expect(r.oldestDay, DateTime(2026, 2, 14));
    });

    test('年またぎ', () {
      final r = buildDateRange(DateTime(2026, 1, 10, 12), dayCount: 30);
      expect(r.days[9], DateTime(2026, 1, 1));
      expect(r.days[10], DateTime(2025, 12, 31));
      expect(r.oldestDay, DateTime(2025, 12, 12));
    });

    test('全日 00:00 かつ連続', () {
      for (final now in [
        DateTime(2026, 10, 6, 9, 30),
        DateTime(2026, 3, 15, 12),
        DateTime(2026, 1, 10, 12),
      ]) {
        final days = buildDateRange(now, dayCount: 30).days;
        for (final d in days) {
          expect(d.hour, 0);
          expect(d.minute, 0);
          expect(d.second, 0);
          expect(d.millisecond, 0);
          expect(d.microsecond, 0);
        }
        for (var i = 0; i < 29; i++) {
          final d = days[i];
          expect(DateTime(d.year, d.month, d.day - 1), days[i + 1]);
        }
      }
    });

    test('既定は 7 日', () {
      expect(
        buildDateRange(DateTime(2026, 10, 6)).days,
        buildDateRange(DateTime(2026, 10, 6), dayCount: 7).days,
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
