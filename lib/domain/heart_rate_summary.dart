import 'package:health_pixcel/domain/models/heart_rate_stats.dart';

/// 心拍の標本(bpm)から集計値を作る。標本が無ければ null。
HeartRateStats? summarizeHeartRate(Iterable<num> samples) {
  var count = 0;
  num sum = 0;
  num? min;
  num? max;
  for (final v in samples) {
    count++;
    sum += v;
    if (min == null || v < min) min = v;
    if (max == null || v > max) max = v;
  }
  if (count == 0) return null;
  return HeartRateStats(
    average: (sum / count).round(),
    min: min!.round(),
    max: max!.round(),
  );
}
