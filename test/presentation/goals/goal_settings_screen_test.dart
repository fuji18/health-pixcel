import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/data/goal_repository.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:health_pixcel/presentation/goals/goal_settings_screen.dart';
import 'package:health_pixcel/presentation/providers.dart';

import '../../fakes/fake_goal_repository.dart';

const stepsField = Key('stepsGoalField');
const hoursField = Key('sleepHoursField');
const minutesField = Key('sleepMinutesField');

Future<void> pumpHome(WidgetTester tester, FakeGoalRepository fake) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [goalRepositoryProvider.overrideWithValue(fake)],
      retry: (_, _) => null,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GoalSettingsScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

void main() {
  testWidgets('保存済みの値が入力欄に入る', (tester) async {
    final fake = FakeGoalRepository()
      ..stored = const Goals(steps: 8000, sleepMinutes: 450);
    await pumpHome(tester, fake);
    expect(textOf(tester, stepsField), '8000');
    expect(textOf(tester, hoursField), '7');
    expect(textOf(tester, minutesField), '30');
  });

  testWidgets('未保存なら空', (tester) async {
    await pumpHome(tester, FakeGoalRepository());
    expect(textOf(tester, stepsField), '');
    expect(textOf(tester, hoursField), '');
    expect(textOf(tester, minutesField), '');
  });

  testWidgets('非数値は理由を表示して保存しない', (tester) async {
    final fake = FakeGoalRepository();
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(stepsField), 'abc');
    await tapSave(tester);
    expect(find.text('数字で入力してください'), findsOneWidget);
    expect(fake.saveCalls, 0);
  });

  testWidgets('範囲外は理由を表示して保存しない', (tester) async {
    final fake = FakeGoalRepository();
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(stepsField), '500');
    await tapSave(tester);
    expect(find.text('1,000〜100,000 歩の範囲で入力してください'), findsOneWidget);
    expect(fake.saveCalls, 0);
  });

  testWidgets('分が 60 以上はエラー', (tester) async {
    final fake = FakeGoalRepository();
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(hoursField), '7');
    await tester.enterText(find.byKey(minutesField), '60');
    await tapSave(tester);
    expect(find.text('0〜59 分で入力してください'), findsOneWidget);
    expect(fake.saveCalls, 0);
  });

  testWidgets('正しい値で保存すると閉じて SnackBar が出る', (tester) async {
    final fake = FakeGoalRepository();
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(stepsField), '8000');
    await tester.enterText(find.byKey(hoursField), '7');
    await tester.enterText(find.byKey(minutesField), '30');
    await tapSave(tester);
    expect(fake.saved, const Goals(steps: 8000, sleepMinutes: 450));
    expect(find.text('目標を保存しました'), findsOneWidget);
    expect(find.byType(GoalSettingsScreen), findsNothing);
  });

  testWidgets('全部空欄で保存すると目標なしで保存される', (tester) async {
    final fake = FakeGoalRepository()
      ..stored = const Goals(steps: 8000, sleepMinutes: 450);
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(stepsField), '');
    await tester.enterText(find.byKey(hoursField), '');
    await tester.enterText(find.byKey(minutesField), '');
    await tapSave(tester);
    expect(fake.saved, const Goals());
  });

  testWidgets('保存失敗では画面に留まる', (tester) async {
    final fake = FakeGoalRepository()..saveError = const GoalStorageException();
    await pumpHome(tester, fake);
    await tester.enterText(find.byKey(stepsField), '8000');
    await tapSave(tester);
    expect(find.text('保存できませんでした'), findsOneWidget);
    expect(find.byType(GoalSettingsScreen), findsOneWidget);
  });

  testWidgets('エラー表示後に入力するとエラーが消える', (tester) async {
    await pumpHome(tester, FakeGoalRepository());
    await tester.enterText(find.byKey(stepsField), 'abc');
    await tapSave(tester);
    expect(find.text('数字で入力してください'), findsOneWidget);
    await tester.enterText(find.byKey(stepsField), '8');
    await tester.pumpAndSettle();
    expect(find.text('数字で入力してください'), findsNothing);
  });
}
