import 'package:health_pixcel/domain/models/exercise_session.dart';

/// 1 日ぶんの運動(開始日に帰属)。
class DailyExercise {
  const DailyExercise({
    required this.date,
    required this.sessions,
    required this.isToday,
  });

  /// 帰属日(開始日)の 00:00(ローカル)。
  final DateTime date;

  /// 開始時刻の昇順。空は記録なし。
  final List<ExerciseSession> sessions;

  /// true の場合、表示時点までの途中値。
  final bool isToday;

  /// 記録があるか。
  bool get hasRecord => sessions.isNotEmpty;

  /// sessions の duration の合計。空なら [Duration.zero]。
  Duration get total =>
      sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
}
