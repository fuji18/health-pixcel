/// 1 回の運動記録。
class ExerciseSession {
  const ExerciseSession({required this.start, required this.end});

  /// 開始時刻(ローカル)。
  final DateTime start;

  /// 終了時刻(ローカル)。start より後。
  final DateTime end;

  /// 運動の長さ。
  Duration get duration => end.difference(start);
}
