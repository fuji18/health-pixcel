/// 1 日ぶんの歩数。
class DailySteps {
  const DailySteps({
    required this.date,
    required this.steps,
    required this.isToday,
  });

  /// 対象日の 00:00(ローカル)。
  final DateTime date;

  /// その日の歩数合計。null は記録なし。
  final int? steps;

  /// true の場合、表示時点までの途中値。
  final bool isToday;
}
