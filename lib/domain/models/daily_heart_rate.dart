import 'package:health_pixcel/domain/models/heart_rate_stats.dart';

/// 1 日ぶんの心拍。
class DailyHeartRate {
  const DailyHeartRate({
    required this.date,
    required this.stats,
    required this.isToday,
  });

  /// 対象日の 00:00(ローカル)。
  final DateTime date;

  /// その日の集計値。null は記録なし。
  final HeartRateStats? stats;

  /// true の場合、表示時点までの値。
  final bool isToday;
}
