/// 1 回の睡眠セッション。
class SleepSession {
  const SleepSession({required this.start, required this.end});

  /// 就寝時刻(ローカル)。
  final DateTime start;

  /// 起床時刻(ローカル)。start より後。
  final DateTime end;

  /// セッションの長さ。
  Duration get duration => end.difference(start);
}
