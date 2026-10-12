/// 1 日ぶんの体重。
class DailyWeight {
  const DailyWeight({
    required this.date,
    required this.kg,
    required this.isToday,
  });

  /// 対象日の 00:00(ローカル)。
  final DateTime date;

  /// その日の最新の記録(kg)。null は記録なし。
  final double? kg;

  /// true の場合、表示時点までの値。
  final bool isToday;
}
