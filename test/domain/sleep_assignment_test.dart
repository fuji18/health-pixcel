import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
import 'package:health_pixcel/domain/sleep_assignment.dart';

void main() {
  group('assignSleepToDays', () {
    final range = buildDateRange(DateTime(2026, 10, 6, 9));

    test('日付をまたぐ睡眠 → 起床日に入る', () {
      final session = SleepSession(
        start: DateTime(2026, 10, 5, 23, 30),
        end: DateTime(2026, 10, 6, 6, 30),
      );

      final result = assignSleepToDays(range, [session]);

      expect(result[0].date, DateTime(2026, 10, 6));
      expect(result[0].sessions, [session]);
      expect(result[1].hasRecord, isFalse);
    });

    test('起床がちょうど 00:00 → その日に入る', () {
      final session = SleepSession(
        start: DateTime(2026, 10, 5, 22),
        end: DateTime(2026, 10, 6),
      );

      final result = assignSleepToDays(range, [session]);

      expect(result[0].sessions.length, 1);
    });

    test('最古日に起床 → 最古日に入る', () {
      final session = SleepSession(
        start: DateTime(2026, 9, 29, 23),
        end: DateTime(2026, 9, 30, 6),
      );

      final result = assignSleepToDays(range, [session]);

      expect(result[6].date, DateTime(2026, 9, 30));
      expect(result[6].sessions.length, 1);
    });

    test('最古日より前に起床 → 除外される', () {
      final session = SleepSession(
        start: DateTime(2026, 9, 28, 23),
        end: DateTime(2026, 9, 29, 6),
      );

      final result = assignSleepToDays(range, [session]);

      expect(result.every((d) => !d.hasRecord), isTrue);
    });

    test('同日 2 件(夜 + 昼寝)→ 就寝時刻の昇順', () {
      final nap = SleepSession(
        start: DateTime(2026, 10, 5, 13),
        end: DateTime(2026, 10, 5, 13, 40),
      );
      final night = SleepSession(
        start: DateTime(2026, 10, 4, 23),
        end: DateTime(2026, 10, 5, 6),
      );

      final result = assignSleepToDays(range, [nap, night]);

      expect(result[1].sessions, [night, nap]);
    });

    test('重複(同一 start / end の別インスタンス)→ 1 件', () {
      final a = SleepSession(
        start: DateTime(2026, 10, 5, 23),
        end: DateTime(2026, 10, 6, 6),
      );
      final b = SleepSession(
        start: DateTime(2026, 10, 5, 23),
        end: DateTime(2026, 10, 6, 6),
      );

      final result = assignSleepToDays(range, [a, b]);

      expect(result[0].sessions.length, 1);
    });

    test('戻り値と各日の sessions を変更しようとする → UnsupportedError', () {
      final session = SleepSession(
        start: DateTime(2026, 10, 5, 23, 30),
        end: DateTime(2026, 10, 6, 6, 30),
      );

      final result = assignSleepToDays(range, [session]);

      expect(() => result.add(result.first), throwsUnsupportedError);
      expect(() => result.first.sessions.add(session), throwsUnsupportedError);
    });

    test('今日より後に起床 → 除外される', () {
      final session = SleepSession(
        start: DateTime(2026, 10, 6, 23),
        end: DateTime(2026, 10, 7, 6),
      );

      final result = assignSleepToDays(range, [session]);

      expect(result.every((d) => !d.hasRecord), isTrue);
    });

    test('セッションなし → 7 日分の空リスト', () {
      final result = assignSleepToDays(range, []);

      expect(result.length, 7);
      expect(result.map((d) => d.date), range.days);
      expect(result.every((d) => d.sessions.isEmpty), isTrue);
    });
  });
}
