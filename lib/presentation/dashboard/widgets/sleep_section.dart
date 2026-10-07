import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';

/// 睡眠セクション。7 行の一覧・未許可の案内・エラー表示のいずれかを描画する。
class SleepSection extends StatelessWidget {
  const SleepSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// 睡眠の取得結果。
  final MetricResult<DailySleep> result;

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
          child: Text('睡眠', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        switch (result) {
          MetricLoaded<DailySleep>(:final days) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in days) _SleepRow(day: day, today: today),
            ],
          ),
          MetricPermissionDenied<DailySleep>() => StatusMessage(
            title: '睡眠の権限が許可されていません',
            actions: [
              StatusAction('権限を許可する', onRequestPermission),
              StatusAction('ヘルスコネクトの設定を開く', onOpenSettings),
            ],
          ),
          MetricFailed<DailySleep>() => StatusMessage(
            title: 'データを読み込めませんでした',
            actions: [StatusAction('再読み込み', onRetry)],
          ),
        },
      ],
    );
  }
}

class _SleepRow extends StatelessWidget {
  const _SleepRow({required this.day, required this.today});

  final DailySleep day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.bodyLarge;
    final numeric = label?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final muted = label?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(formatDayLabel(day.date, today: today), style: label),
            ),
            if (!day.hasRecord)
              Text('記録なし', style: muted)
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final s in day.sessions)
                    Text(
                      '${formatTime(s.start)}→${formatTime(s.end)}',
                      style: numeric,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Text(formatDuration(day.total), style: numeric),
            ],
          ],
        ),
      ),
    );
  }
}
