import 'package:health_pixcel/domain/models/date_range.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

/// [sessions] を起床日(end のローカル日付)ごとに振り分け、[range] の 7 日分を新しい順で返す。
///
/// - range に含まれない日に起床したセッションは捨てる
/// - 同一の start / end を持つセッションは 1 件にまとめる(書き込み元の重複対策)
/// - 各日のセッションは start の昇順。セッションがない日は空リスト
///
/// 機能設計書 A3。
List<DailySleep> assignSleepToDays(
  DateRange range,
  List<SleepSession> sessions,
) {
  final unique = {for (final s in sessions) (s.start, s.end): s}.values;
  final byDay = <DateTime, List<SleepSession>>{};
  for (final s in unique) {
    final end = s.end.toLocal();
    final day = DateTime(end.year, end.month, end.day);
    byDay.putIfAbsent(day, () => []).add(s);
  }
  return List<DailySleep>.unmodifiable([
    for (final d in range.days)
      DailySleep(
        date: d,
        sessions: List<SleepSession>.unmodifiable(
          <SleepSession>[...?byDay[d]]
            ..sort((a, b) => a.start.compareTo(b.start)),
        ),
      ),
  ]);
}
