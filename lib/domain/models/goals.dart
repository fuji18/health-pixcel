/// ユーザーが設定した目標値(機能設計書「Goals」)。null は目標なし。
class Goals {
  const Goals({this.steps, this.sleepMinutes});

  /// 1 日の歩数の目標。null は目標なし。
  final int? steps;

  /// 1 日の睡眠時間の目標(分)。null は目標なし。
  final int? sleepMinutes;

  @override
  bool operator ==(Object other) =>
      other is Goals &&
      other.steps == steps &&
      other.sleepMinutes == sleepMinutes;

  @override
  int get hashCode => Object.hash(steps, sleepMinutes);
}
