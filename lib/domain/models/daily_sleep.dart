import 'package:health_pixcel/domain/models/sleep_session.dart';

/// 1 日ぶんの睡眠(起床日に帰属)。
class DailySleep {
  const DailySleep({required this.date, required this.sessions});

  /// 帰属日(起床日)の 00:00(ローカル)。
  final DateTime date;

  /// 就寝時刻の昇順。空は記録なし。
  final List<SleepSession> sessions;

  /// 記録があるか。
  bool get hasRecord => sessions.isNotEmpty;

  /// sessions の duration の合計。空なら [Duration.zero]。
  Duration get total =>
      sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
}
