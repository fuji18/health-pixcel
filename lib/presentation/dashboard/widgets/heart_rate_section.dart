import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_heart_rate.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';

/// 心拍セクション。日別一覧・未許可の案内・エラー表示のいずれかを描画する。
class HeartRateSection extends StatelessWidget {
  const HeartRateSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// 心拍の取得結果。
  final MetricResult<DailyHeartRate> result;

  /// 今日(「今日」「昨日」の判定)。
  final DateTime today;

  /// 「権限を許可する」の処理。
  final VoidCallback onRequestPermission;

  /// 「ヘルスコネクトの設定を開く」の処理。
  final VoidCallback onOpenSettings;

  /// 「再読み込み」の処理。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('心拍', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        switch (result) {
          MetricLoaded<DailyHeartRate>(:final days) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '1 日の平均(最小〜最大)',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final day in days) _HeartRateRow(day: day, today: today),
            ],
          ),
          MetricPermissionDenied<DailyHeartRate>() => StatusMessage(
            title: '心拍の権限が許可されていません',
            actions: [
              StatusAction('権限を許可する', onRequestPermission),
              StatusAction('ヘルスコネクトの設定を開く', onOpenSettings),
            ],
          ),
          MetricFailed<DailyHeartRate>() => StatusMessage(
            title: 'データを読み込めませんでした',
            actions: [StatusAction('再読み込み', onRetry)],
          ),
        },
      ],
    );
  }
}

class _HeartRateRow extends StatelessWidget {
  const _HeartRateRow({required this.day, required this.today});

  final DailyHeartRate day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.bodyLarge;
    final numeric = label?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final muted = label?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final mutedNumeric = muted?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final stats = day.stats;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(formatDayLabel(day.date, today: today), style: label),
            ),
            const SizedBox(width: 8),
            if (stats == null)
              Text('記録なし', style: muted)
            else
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: formatBpm(stats.average), style: numeric),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: formatBpmRange(stats.min, stats.max),
                        style: mutedNumeric,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
