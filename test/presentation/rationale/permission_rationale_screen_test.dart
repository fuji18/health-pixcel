import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/presentation/rationale/permission_rationale_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  int popCount() => calls.where((m) => m == 'SystemNavigator.pop').length;

  testWidgets('本文を表示し、項目ラベルは見出しになる', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: PermissionRationaleScreen()),
    );
    for (final text in [
      '健康データの利用について',
      '読み取るデータ',
      '歩数・睡眠(就寝・起床時刻)',
      '使い道',
      '直近 7 日または 30 日の歩数と睡眠を、このアプリの画面に表示するためだけに使います',
      '送信',
      'データを端末の外に送信しません(このアプリはインターネットに接続する権限を持っていません)',
      '保存・書き込み',
      'データをアプリ内に保存せず、ヘルスコネクトへの書き込みも行いません',
      '取り消し',
      '権限はヘルスコネクトの設定からいつでも取り消せます',
      '閉じる',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final label in ['読み取るデータ', '使い道', '送信', '保存・書き込み', '取り消し']) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isHeader: true),
      );
    }
    handle.dispose();
  });

  testWidgets('閉じるで前の画面に戻る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PermissionRationaleScreen(),
                ),
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionRationaleScreen), findsNothing);
    expect(find.text('開く'), findsOneWidget);
    expect(popCount(), 0);
  });

  testWidgets('closesApp なら閉じるでアプリを閉じる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PermissionRationaleScreen(closesApp: true)),
    );
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(popCount(), 1);
    expect(find.byType(PermissionRationaleScreen), findsOneWidget);
  });
}
