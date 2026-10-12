/// ある区間の心拍の集計値(bpm。整数)。
class HeartRateStats {
  const HeartRateStats({
    required this.average,
    required this.min,
    required this.max,
  });

  /// 標本の平均(四捨五入)。
  final int average;

  /// 最小値。
  final int min;

  /// 最大値。
  final int max;
}
