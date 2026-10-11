import 'package:flutter/material.dart';
import 'package:health_pixcel/domain/goal_progress.dart';

/// 一覧の行末に置く目標の達成マーク。目標が設定されているときだけ置く(notSet では置かない)。
/// 判定しない日(noRecord / inProgress)は同じ幅の空白にして、値の列を揃える。
class GoalMark extends StatelessWidget {
  const GoalMark({super.key, required this.status});

  final GoalStatus status;

  static const double width = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final Widget? child = switch (status) {
      GoalStatus.achieved => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text('達成', style: textTheme.labelMedium),
        ],
      ),
      GoalStatus.notAchieved => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.remove_circle_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '未達',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      GoalStatus.noRecord || GoalStatus.inProgress || GoalStatus.notSet => null,
    };
    if (child == null) return const SizedBox(width: width);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: width),
      child: child,
    );
  }
}
