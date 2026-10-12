import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';
import 'package:health_pixcel/domain/exercise_assignment.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';

void main() {
  group('assignExerciseToDays', () {
    final range = buildDateRange(DateTime(2026, 10, 6, 9));

    test('開始日に帰属する', () {
      final s = ExerciseSession(
        start: DateTime(2026, 10, 5, 7),
        end: DateTime(2026, 10, 5, 8),
      );

      final result = assignExerciseToDays(range, [s]);

      expect(result[1].date, DateTime(2026, 10, 5));
      expect(result[1].sessions, [s]);
      expect(result[0].hasRecord, isFalse);
    });

    test('日をまたぐ記録(23:30〜翌 0:30)は開始日に 60 分すべて帰属し、翌日は記録なし', () {
      final s = ExerciseSession(
        start: DateTime(2026, 10, 4, 23, 30),
        end: DateTime(2026, 10, 5, 0, 30),
      );

      final result = assignExerciseToDays(range, [s]);

      expect(result[2].date, DateTime(2026, 10, 4));
      expect(result[2].total, const Duration(minutes: 60));
      expect(result[1].date, DateTime(2026, 10, 5));
      expect(result[1].hasRecord, isFalse);
    });

    test('最古日より前に開始して最古日に終わる記録は捨てる', () {
      final s = ExerciseSession(
        start: DateTime(2026, 9, 29, 23, 30),
        end: DateTime(2026, 9, 30, 0, 30),
      );

      final result = assignExerciseToDays(range, [s]);

      expect(result.every((d) => !d.hasRecord), isTrue);
    });

    test('同一 start・end は 1 件', () {
      ExerciseSession make() => ExerciseSession(
        start: DateTime(2026, 10, 5, 7),
        end: DateTime(2026, 10, 5, 8),
      );

      final result = assignExerciseToDays(range, [make(), make()]);

      expect(result[1].sessions.length, 1);
    });

    test('同日の複数記録は start 昇順で、total は合計', () {
      final evening = ExerciseSession(
        start: DateTime(2026, 10, 5, 18),
        end: DateTime(2026, 10, 5, 18, 20),
      );
      final morning = ExerciseSession(
        start: DateTime(2026, 10, 5, 7),
        end: DateTime(2026, 10, 5, 7, 45),
      );

      final result = assignExerciseToDays(range, [evening, morning]);

      expect(result[1].sessions, [morning, evening]);
      expect(result[1].total, const Duration(hours: 1, minutes: 5));
    });

    test('記録のない日は空で hasRecord == false', () {
      final result = assignExerciseToDays(range, []);

      expect(result.every((d) => d.sessions.isEmpty && !d.hasRecord), isTrue);
    });

    test('戻り値は range の日数分(7 と 30)で新しい順', () {
      for (final n in [7, 30]) {
        final r = buildDateRange(DateTime(2026, 10, 6, 9), dayCount: n);

        final result = assignExerciseToDays(r, []);

        expect(result.length, n);
        expect(result.map((d) => d.date), r.days);
      }
    });

    test('isToday は先頭だけ true', () {
      final result = assignExerciseToDays(range, []);

      expect(result.first.isToday, isTrue);
      expect(result.skip(1).every((d) => !d.isToday), isTrue);
    });
  });
}
