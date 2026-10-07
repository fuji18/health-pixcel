import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';

/// 歩数セクション。7 行の一覧・未許可の案内・エラー表示のいずれかを描画する。
class StepsSection extends StatelessWidget {
  const StepsSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// 歩数の取得結果。
  final MetricResult<DailySteps> result;

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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('歩数', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        switch (result) {
          MetricLoaded<DailySteps>(:final days) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in days) _StepsRow(day: day, today: today),
            ],
          ),
          MetricPermissionDenied<DailySteps>() => StatusMessage(
            title: '歩数の権限が許可されていません',
            actions: [
              StatusAction('権限を許可する', onRequestPermission),
              StatusAction('ヘルスコネクトの設定を開く', onOpenSettings),
            ],
          ),
          MetricFailed<DailySteps>() => StatusMessage(
            title: 'データを読み込めませんでした',
            actions: [StatusAction('再読み込み', onRetry)],
          ),
        },
      ],
    );
  }
}

class _StepsRow extends StatelessWidget {
  const _StepsRow({required this.day, required this.today});

  final DailySteps day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.bodyLarge;
    final numeric = label?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final muted = label?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final steps = day.steps;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(formatDayLabel(day.date, today: today), style: label),
            ),
            if (steps == null)
              Text('記録なし', style: muted)
            else ...[
              Text(formatSteps(steps), style: numeric),
              if (day.isToday) ...[
                const SizedBox(width: 4),
                Text('(途中)', style: muted),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
