import 'dart:math';

import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';

/// 歩数グラフの読み上げ要約。[days] は表示期間の全日(順不同)。
String stepsTrendSummary(List<DailySteps> days) {
  final n = days.length;
  final values = days.map((d) => d.steps).whereType<int>().toList();
  if (values.isEmpty) return '歩数の推移グラフ。直近 $n 日、記録はありません';
  final k = values.length;
  final avg = (values.reduce((a, b) => a + b) / k).round();
  final maxValue = values.reduce(max);
  return '歩数の推移グラフ。直近 $n 日のうち記録のある日 $k 日、'
      '1 日平均 ${formatSteps(avg)}、最多 ${formatSteps(maxValue)}';
}

/// 睡眠時間グラフの読み上げ要約。[days] は表示期間の全日(順不同)。
String sleepTrendSummary(List<DailySleep> days) {
  final n = days.length;
  final totals = days.where((d) => d.hasRecord).map((d) => d.total).toList();
  if (totals.isEmpty) return '睡眠時間の推移グラフ。直近 $n 日、記録はありません';
  final k = totals.length;
  final sumMinutes = totals.fold<int>(0, (s, t) => s + t.inMinutes);
  final avg = Duration(minutes: (sumMinutes / k).round());
  final maxValue = totals.reduce((a, b) => a > b ? a : b);
  return '睡眠時間の推移グラフ。直近 $n 日のうち記録のある日 $k 日、'
      '1 日平均 ${formatDuration(avg)}、最長 ${formatDuration(maxValue)}';
}

/// 歩数グラフの縦軸上限。2,000 歩単位で切り上げ、最小 2,000。
double stepsAxisMax(Iterable<int> values) {
  final m = values.fold<int>(0, max);
  return max(2000, ((m + 1999) ~/ 2000) * 2000).toDouble();
}

/// 睡眠グラフの縦軸上限(時間)。2 時間単位で切り上げ、最小 2。
double sleepAxisMaxHours(Iterable<Duration> totals) {
  final m = totals.fold<int>(0, (a, t) => max(a, t.inMinutes));
  return max(2, ((m + 119) ~/ 120) * 2).toDouble();
}
