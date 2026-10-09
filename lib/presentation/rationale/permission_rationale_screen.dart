import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _items = [
  (label: '読み取るデータ', body: '歩数・睡眠(就寝・起床時刻)'),
  (label: '使い道', body: '直近 7 日または 30 日の歩数と睡眠を、このアプリの画面に表示するためだけに使います'),
  (label: '送信', body: 'データを端末の外に送信しません(このアプリはインターネットに接続する権限を持っていません)'),
  (label: '保存・書き込み', body: 'データをアプリ内に保存せず、ヘルスコネクトへの書き込みも行いません'),
  (label: '取り消し', body: '権限はヘルスコネクトの設定からいつでも取り消せます'),
];

/// 権限の利用目的の説明画面(ヘルスコネクトの「利用目的」と案内画面の「詳しく見る」の表示先)。
class PermissionRationaleScreen extends StatelessWidget {
  const PermissionRationaleScreen({super.key, this.closesApp = false});

  /// true なら「閉じる」でアプリを閉じる(ヘルスコネクトから起動された場合)。false なら前の画面に戻る。
  final bool closesApp;

  void _close(BuildContext context) {
    if (closesApp) {
      SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('健康データの利用について')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(item.label, style: textTheme.titleSmall),
                  ),
                  const SizedBox(height: 4),
                  Text(item.body, style: textTheme.bodyLarge),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _close(context),
              child: const Text('閉じる'),
            ),
          ),
        ],
      ),
    );
  }
}
