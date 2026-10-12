import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/daily_exercise.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';

void main() {
  group('DailyExercise', () {
    test('複数記録 → total は duration の合計', () {
      final a = ExerciseSession(
        start: DateTime(2026, 10, 6, 7),
        end: DateTime(2026, 10, 6, 7, 45),
      );
      final b = ExerciseSession(
        start: DateTime(2026, 10, 6, 18),
        end: DateTime(2026, 10, 6, 18, 20),
      );
      final day = DailyExercise(
        date: DateTime(2026, 10, 6),
        sessions: [a, b],
        isToday: false,
      );

      expect(day.total, const Duration(hours: 1, minutes: 5));
      expect(day.hasRecord, isTrue);
    });

    test('記録が空 → total は zero で記録なし', () {
      final day = DailyExercise(
        date: DateTime(2026, 10, 6),
        sessions: const [],
        isToday: false,
      );

      expect(day.total, Duration.zero);
      expect(day.hasRecord, isFalse);
    });
  });
}
