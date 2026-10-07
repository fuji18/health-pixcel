import 'package:flutter/material.dart';

/// StatusMessage の操作ボタン 1 つぶん。
class StatusAction {
  const StatusAction(this.label, this.onPressed);

  /// ボタンの文言。
  final String label;

  /// 押したときの処理。
  final VoidCallback onPressed;
}

/// 案内・エラーの共通表示(見出し + 説明 + 操作ボタン)。
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.title,
    this.body,
    this.actions = const [],
  });

  /// 見出し。
  final String title;

  /// 説明。
  final String? body;

  /// 操作ボタン。1 つ目が主操作。
  final List<StatusAction> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = this.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.titleMedium),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body, style: textTheme.bodyLarge),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < actions.length; i++)
                if (i == 0)
                  FilledButton(
                    onPressed: actions[i].onPressed,
                    child: Text(actions[i].label),
                  )
                else
                  OutlinedButton(
                    onPressed: actions[i].onPressed,
                    child: Text(actions[i].label),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
