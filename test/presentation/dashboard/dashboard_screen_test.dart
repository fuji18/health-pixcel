import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_controller.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_screen.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_state.dart';
import 'package:health_pixcel/presentation/providers.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fakes/fake_health_repository.dart';

class _FailingController extends DashboardController {
  @override
  Future<DashboardState> build() async => throw Exception('boom');
}

final now = DateTime(2026, 10, 6, 10, 30);

const bothDenied = (
  steps: PermissionStatus.denied,
  sleep: PermissionStatus.denied,
);
const bothGranted = (
  steps: PermissionStatus.granted,
  sleep: PermissionStatus.granted,
);

late FakeHealthRepository fake;

Future<void> pumpScreen(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        healthRepositoryProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue(() => now),
        ...overrides,
      ],
      retry: (_, _) => null,
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
}

void seedData() {
  fake.steps[DateTime(2026, 10, 6)] = 3210;
  fake.steps[DateTime(2026, 10, 5)] = 8432;
  fake.sleepSessions = [
    SleepSession(
      start: DateTime(2026, 10, 5, 23, 45),
      end: DateTime(2026, 10, 6, 6, 57),
    ),
    SleepSession(
      start: DateTime(2026, 10, 5, 0, 10),
      end: DateTime(2026, 10, 5, 7, 20),
    ),
    SleepSession(
      start: DateTime(2026, 10, 5, 13, 0),
      end: DateTime(2026, 10, 5, 13, 40),
    ),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('ja'));
  setUp(() => fake = FakeHealthRepository());

  testWidgets('1 権限確認中はローディングを表示する', (tester) async {
    final gate = Completer<void>();
    fake.permissionsGate = gate;
    await pumpScreen(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('睡眠'), findsOneWidget);
  });

  testWidgets('2 未インストールの案内とストア操作', (tester) async {
    fake.availability = HealthAvailability.notInstalled;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('ヘルスコネクトを利用できません'), findsOneWidget);
    expect(find.text('Play ストアでヘルスコネクトの状態を確認してください'), findsOneWidget);
    await tester.tap(find.text('Play ストアを開く'));
    await tester.pumpAndSettle();
    expect(fake.openStoreCalls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('3 ストアを開けないとスナックバーを出す', (tester) async {
    fake.availability = HealthAvailability.notInstalled;
    fake.openStoreResult = false;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play ストアを開く'));
    await tester.pump();
    expect(find.text('Play ストアを開けませんでした'), findsOneWidget);
  });

  testWidgets('4 更新が必要な案内', (tester) async {
    fake.availability = HealthAvailability.updateRequired;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('ヘルスコネクトの更新が必要です'), findsOneWidget);
    await tester.tap(find.text('ヘルスコネクトを更新する'));
    await tester.pump();
    expect(fake.openStoreCalls, 1);
  });

  testWidgets('5 両方未許可の案内', (tester) async {
    fake.permissions = bothDenied;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('歩数と睡眠を表示するには、ヘルスコネクトの読み取り権限が必要です'), findsOneWidget);
    expect(find.text('データの読み取りのみ行い、端末の外には送信しません'), findsOneWidget);
    expect(find.text('権限を許可する'), findsOneWidget);
    expect(find.text('ヘルスコネクトの設定を開く'), findsOneWidget);
    expect(find.text('詳しく見る'), findsNothing);
  });

  testWidgets('6 権限を許可すると再起動なしで表示される', (tester) async {
    fake.permissions = bothDenied;
    fake.permissionsAfterRequest = bothGranted;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('権限を許可する'));
    await tester.pumpAndSettle();
    expect(find.text('睡眠'), findsOneWidget);
    expect(find.text('歩数'), findsOneWidget);
    expect(fake.requestPermissionsCalls, 1);
  });

  testWidgets('7 設定を開けないとスナックバーを出す', (tester) async {
    fake.permissions = bothDenied;
    fake.openSettingsResult = false;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ヘルスコネクトの設定を開く'));
    await tester.pump();
    expect(find.text('ヘルスコネクトを開けませんでした'), findsOneWidget);
    expect(fake.openSettingsCalls, 1);
  });

  testWidgets('8 7 日ぶんの睡眠と歩数を表示する', (tester) async {
    seedData();
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    for (final label in [
      '今日 10/6(火)',
      '昨日 10/5(月)',
      '10/4(日)',
      '10/3(土)',
      '10/2(金)',
      '10/1(木)',
      '9/30(水)',
    ]) {
      expect(find.text(label), findsNWidgets(2));
    }
    expect(find.text('23:45→06:57'), findsOneWidget);
    expect(find.text('7時間12分'), findsOneWidget);
    expect(find.text('00:10→07:20'), findsOneWidget);
    expect(find.text('13:00→13:40'), findsOneWidget);
    expect(find.text('7時間50分'), findsOneWidget);
    expect(find.text('3,210 歩'), findsOneWidget);
    expect(find.text('(途中)'), findsOneWidget);
    expect(find.text('8,432 歩'), findsOneWidget);
    expect(find.text('記録なし'), findsNWidgets(10));
    expect(
      tester.getTopLeft(find.text('睡眠')).dy,
      lessThan(tester.getTopLeft(find.text('歩数')).dy),
    );
    expect(
      tester.getTopLeft(find.text('今日 10/6(火)').first).dy,
      lessThan(tester.getTopLeft(find.text('昨日 10/5(月)').first).dy),
    );
    expect(find.text('ヘルスコネクトにデータがありません'), findsNothing);
  });

  testWidgets('9 歩数だけ未許可なら歩数セクションに案内を出す', (tester) async {
    seedData();
    fake.permissions = (
      steps: PermissionStatus.denied,
      sleep: PermissionStatus.granted,
    );
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('歩数の権限が許可されていません'), findsOneWidget);
    expect(find.text('権限を許可する'), findsOneWidget);
    expect(find.text('ヘルスコネクトの設定を開く'), findsOneWidget);
    expect(find.text('今日 10/6(火)'), findsOneWidget);
  });

  testWidgets('10 睡眠の読み取り失敗は睡眠セクションだけに出て再読み込みで回復する', (tester) async {
    seedData();
    fake.sleepError = HealthErrorKind.readFailed;
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('データを読み込めませんでした'), findsOneWidget);
    expect(find.text('再読み込み'), findsOneWidget);
    expect(find.text('3,210 歩'), findsOneWidget);
    expect(find.text('昨日 10/5(月)'), findsOneWidget);
    fake.sleepError = null;
    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();
    expect(find.text('データを読み込めませんでした'), findsNothing);
    expect(find.text('今日 10/6(火)'), findsNWidgets(2));
  });

  testWidgets('11 データなしの案内', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('ヘルスコネクトにデータがありません'), findsOneWidget);
    expect(find.text('Health Sync の同期設定を確認してください'), findsOneWidget);
    expect(find.text('再読み込み'), findsOneWidget);
    expect(find.text('記録なし'), findsNWidgets(14));
  });

  testWidgets('12 コントローラが例外でも再読み込みで回復する', (tester) async {
    seedData();
    await pumpScreen(
      tester,
      overrides: [
        dashboardControllerProvider.overrideWith(_FailingController.new),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('データを読み込めませんでした'), findsOneWidget);
    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();
    expect(find.text('睡眠'), findsOneWidget);
  });

  testWidgets('13 引っぱって更新する', (tester) async {
    seedData();
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    final before = fake.checkAvailabilityCalls;
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(fake.checkAvailabilityCalls, greaterThan(before));
  });

  testWidgets('14 復帰時に権限が変わっていれば読み直す', (tester) async {
    seedData();
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    fake.permissions = (
      steps: PermissionStatus.denied,
      sleep: PermissionStatus.granted,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('歩数の権限が許可されていません'), findsOneWidget);
  });

  testWidgets('15 復帰時に変化がなければ読み直さない', (tester) async {
    seedData();
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    final before = fake.checkPermissionsCalls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.checkPermissionsCalls, before + 1);
  });

  testWidgets('16 セクション見出しは見出しとして読まれる', (tester) async {
    final handle = tester.ensureSemantics();
    seedData();
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('睡眠')),
      matchesSemantics(label: '睡眠', isHeader: true),
    );
    expect(
      tester.getSemantics(find.text('歩数')),
      matchesSemantics(label: '歩数', isHeader: true),
    );
    handle.dispose();
  });
}
