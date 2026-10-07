import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja'));

  group('formatDayLabel', () {
    final today = DateTime(2026, 10, 6);

    test('今日 → 今日ラベル', () {
      expect(formatDayLabel(DateTime(2026, 10, 6), today: today), '今日 10/6(火)');
    });

    test('前日 → 昨日ラベル', () {
      expect(formatDayLabel(DateTime(2026, 10, 5), today: today), '昨日 10/5(月)');
    });

    test('2 日前 → ラベルなし', () {
      expect(formatDayLabel(DateTime(2026, 10, 4), today: today), '10/4(日)');
    });

    test('月初の昨日 → 昨日ラベル', () {
      expect(
        formatDayLabel(DateTime(2026, 1, 1), today: DateTime(2026, 1, 2)),
        '昨日 1/1(木)',
      );
    });
  });

  group('formatSteps', () {
    test('千の区切りが入る', () {
      expect(formatSteps(8432), '8,432 歩');
      expect(formatSteps(1), '1 歩');
      expect(formatSteps(12345678), '12,345,678 歩');
    });
  });

  group('formatTime', () {
    test('24 時間・ゼロ埋め', () {
      expect(formatTime(DateTime(2026, 10, 5, 23, 45)), '23:45');
      expect(formatTime(DateTime(2026, 10, 6, 6, 57)), '06:57');
    });
  });

  group('formatDuration', () {
    test('時間と分 → h時間m分', () {
      expect(formatDuration(const Duration(hours: 7, minutes: 12)), '7時間12分');
    });

    test('1 時間未満 → m分', () {
      expect(formatDuration(const Duration(minutes: 45)), '45分');
    });

    test('ちょうど時間 → h時間', () {
      expect(formatDuration(const Duration(hours: 8)), '8時間');
    });

    test('秒は切り捨て', () {
      expect(
        formatDuration(const Duration(hours: 7, minutes: 12, seconds: 59)),
        '7時間12分',
      );
    });

    test('zero → 0分', () {
      expect(formatDuration(Duration.zero), '0分');
    });
  });
}
