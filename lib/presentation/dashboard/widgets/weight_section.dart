import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_weight.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';

/// 体重セクション。日別一覧・未許可の案内・エラー表示のいずれかを描画する。
class WeightSection extends StatelessWidget {
  const WeightSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// 体重の取得結果。
  final MetricResult<DailyWeight> result;

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
          child: Text('体重', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        switch (result) {
          MetricLoaded<DailyWeight>(:final days) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'その日の最新の記録',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final day in days) _WeightRow(day: day, today: today),
            ],
          ),
          MetricPermissionDenied<DailyWeight>() => StatusMessage(
            title: '体重の権限が許可されていません',
            actions: [
              StatusAction('権限を許可する', onRequestPermission),
              StatusAction('ヘルスコネクトの設定を開く', onOpenSettings),
            ],
          ),
          MetricFailed<DailyWeight>() => StatusMessage(
            title: 'データを読み込めませんでした',
            actions: [StatusAction('再読み込み', onRetry)],
          ),
        },
      ],
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.day, required this.today});

  final DailyWeight day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.bodyLarge;
    final numeric = label?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final muted = label?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final kg = day.kg;
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
            if (kg == null)
              Text('記録なし', style: muted)
            else
              Flexible(
                child: Text(
                  formatKg(kg),
                  style: numeric,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
