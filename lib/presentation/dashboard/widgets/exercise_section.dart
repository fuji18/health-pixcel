import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/domain/models/daily_exercise.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';

/// 運動セクション。日別一覧・未許可の案内・エラー表示のいずれかを描画する。
class ExerciseSection extends StatelessWidget {
  const ExerciseSection({
    super.key,
    required this.result,
    required this.today,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// 運動の取得結果。
  final MetricResult<DailyExercise> result;

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
          child: Text('運動', style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        switch (result) {
          MetricLoaded<DailyExercise>(:final days) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'その日に始めた運動の合計時間',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final day in days) _ExerciseRow(day: day, today: today),
            ],
          ),
          MetricPermissionDenied<DailyExercise>() => StatusMessage(
            title: '運動記録の権限が許可されていません',
            body:
                '運動記録の表示には、運動・距離・消費カロリー・歩数の読み取りをすべて許可してください(距離と消費カロリーは表示しません)',
            actions: [
              StatusAction('権限を許可する', onRequestPermission),
              StatusAction('ヘルスコネクトの設定を開く', onOpenSettings),
            ],
          ),
          MetricFailed<DailyExercise>() => StatusMessage(
            title: 'データを読み込めませんでした',
            actions: [StatusAction('再読み込み', onRetry)],
          ),
        },
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.day, required this.today});

  final DailyExercise day;
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
            const SizedBox(width: 8),
            if (!day.hasRecord)
              Text('記録なし', style: muted)
            else
              Flexible(
                child: Text(
                  day.isToday
                      ? '${formatDuration(day.total)} (途中)'
                      : formatDuration(day.total),
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
