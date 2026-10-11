import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';

/// 日別の推移を棒グラフで描く。記録なしの日は棒も下地も描かない。
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({
    super.key,
    required this.dates,
    required this.values,
    required this.maxY,
    required this.axisLabel,
    required this.semanticsLabel,
  });

  /// 各棒の日付。古い順(左が古い)。
  final List<DateTime> dates;

  /// 各棒の値。[dates] と同じ長さ・同じ順。null は記録なし。
  final List<double?> values;

  /// 縦軸の上限。
  final double maxY;

  /// 縦軸ラベルの文字列。
  final String Function(double value) axisLabel;

  /// スクリーンリーダー向けの要約。
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final n = values.length;
    final width = n <= 7 ? 16.0 : 6.0;

    Widget bottomTitle(double value, TitleMeta meta) {
      final i = value.toInt();
      if (i < 0 || i >= n) return const SizedBox.shrink();
      if (n <= 7 || (n - 1 - i) % 7 == 0) {
        return SideTitleWidget(
          meta: meta,
          child: Text(formatShortDate(dates[i]), style: labelStyle),
        );
      }
      return const SizedBox.shrink();
    }

    BarChartRodData rod(int i) {
      final v = values[i];
      if (v == null) {
        return BarChartRodData(toY: 0, color: Colors.transparent, width: width);
      }
      return BarChartRodData(
        toY: v,
        color: colorScheme.primary,
        width: width,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        backDrawRodData: BackgroundBarChartRodData(
          show: true,
          toY: maxY,
          color: colorScheme.surfaceContainerHighest,
        ),
      );
    }

    final Widget content = values.every((v) => v == null)
        ? Center(
            child: Text(
              'この期間の記録はありません',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: maxY,
              barTouchData: const BarTouchData(enabled: false),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 2,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: maxY / 2,
                    minIncluded: false,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(axisLabel(value), style: labelStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: bottomTitle,
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  BarChartGroupData(x: i, barRods: [rod(i)]),
              ],
            ),
            duration: Duration.zero,
          );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(width: double.infinity, height: 160, child: content),
      ),
    );
  }
}
