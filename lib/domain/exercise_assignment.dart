import 'package:health_pixcel/domain/models/daily_exercise.dart';
import 'package:health_pixcel/domain/models/date_range.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';

/// [sessions] を開始日(start のローカル日付)ごとに振り分け、[range] の日数分を新しい順で返す。
///
/// - 日をまたぐ記録も分割せず、開始日に全時間を帰属させる
/// - range に含まれない日に開始した記録は捨てる
/// - 同一の start / end を持つ記録は 1 件にまとめる(書き込み元の重複対策)
/// - 各日の記録は start の昇順。記録がない日は空リスト
/// - range.days の先頭(今日)だけ isToday = true
///
/// 機能設計書 A6。
List<DailyExercise> assignExerciseToDays(
  DateRange range,
  List<ExerciseSession> sessions,
) {
  final unique = {for (final s in sessions) (s.start, s.end): s}.values;
  final byDay = <DateTime, List<ExerciseSession>>{};
  for (final s in unique) {
    final start = s.start.toLocal();
    final day = DateTime(start.year, start.month, start.day);
    byDay.putIfAbsent(day, () => []).add(s);
  }
  return List<DailyExercise>.unmodifiable([
    for (var i = 0; i < range.days.length; i++)
      DailyExercise(
        date: range.days[i],
        sessions: List<ExerciseSession>.unmodifiable(
          <ExerciseSession>[...?byDay[range.days[i]]]
            ..sort((a, b) => a.start.compareTo(b.start)),
        ),
        isToday: i == 0,
      ),
  ]);
}
