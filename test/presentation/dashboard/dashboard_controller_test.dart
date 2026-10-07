import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_controller.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_state.dart';
import 'package:health_pixcel/presentation/providers.dart';

import '../../fakes/fake_health_repository.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10, 30);
  final today = DateTime(2026, 10, 6);
  const granted = PermissionStatus.granted;
  const denied = PermissionStatus.denied;

  late FakeHealthRepository fake;
  late ProviderContainer container;

  setUp(() => fake = FakeHealthRepository());

  ProviderContainer makeContainer() {
    container = ProviderContainer.test(
      overrides: [
        healthRepositoryProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    // Riverpod 3 は購読者のいないプロバイダーを一時停止するため、常に購読しておく
    container.listen(dashboardControllerProvider, (_, _) {});
    return container;
  }

  /// 保留中のマイクロタスクを流す
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  Future<void> initial() async {
    makeContainer();
    await container.read(dashboardControllerProvider.future);
  }

  DashboardController controller() =>
      container.read(dashboardControllerProvider.notifier);
  AsyncValue<DashboardState> st() =>
      container.read(dashboardControllerProvider);
  DashboardState value() => st().requireValue;

  group('初回の読み込み', () {
    test('初回は読み込み中 → 結果', () async {
      makeContainer();
      expect(st().isLoading, isTrue);
      await container.read(dashboardControllerProvider.future);
      expect(st(), isA<AsyncData<DashboardState>>());
      expect(value(), isA<DashboardReady>());
    });

    test('利用不可', () async {
      fake.availability = HealthAvailability.updateRequired;
      await initial();
      final v = value() as DashboardUnavailable;
      expect(v.availability, HealthAvailability.updateRequired);
      expect(fake.checkPermissionsCalls, 0);
      expect(fake.stepsCalls, isEmpty);
      expect(fake.sleepCalls, isEmpty);
    });

    test('両方未許可', () async {
      fake.permissions = (steps: denied, sleep: denied);
      await initial();
      expect(value(), isA<DashboardNeedsPermission>());
      expect(fake.stepsCalls, isEmpty);
      expect(fake.sleepCalls, isEmpty);
    });

    test('片方未許可', () async {
      fake.permissions = (steps: granted, sleep: denied);
      await initial();
      final v = value() as DashboardReady;
      expect(v.steps, isA<MetricLoaded<dynamic>>());
      expect(v.sleep, isA<MetricPermissionDenied<dynamic>>());
      expect(fake.sleepCalls, isEmpty);
    });

    test('読み取り失敗は片方だけ', () async {
      fake.stepsErrors[today] = HealthErrorKind.readFailed;
      await initial();
      final v = value() as DashboardReady;
      expect(
        (v.steps as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
      expect(v.sleep, isA<MetricLoaded<dynamic>>());
    });

    test('読み込み中の unavailable → DashboardUnavailable', () async {
      fake.sleepError = HealthErrorKind.unavailable;
      fake.availabilityQueue.addAll([
        HealthAvailability.available,
        HealthAvailability.notInstalled,
      ]);
      await initial();
      final v = value() as DashboardUnavailable;
      expect(v.availability, HealthAvailability.notInstalled);
    });

    test('読み込み中の unavailable だが利用可能のまま → readFailed', () async {
      fake.sleepError = HealthErrorKind.unavailable;
      await initial();
      final v = value() as DashboardReady;
      expect(
        (v.sleep as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
      expect(v.steps, isA<MetricLoaded<dynamic>>());
    });

    test('想定外の例外は外に出ない', () async {
      fake.availabilityError = Exception('x');
      await initial();
      expect(st().hasError, isFalse);
      final v = value() as DashboardReady;
      expect(
        (v.steps as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
      expect(
        (v.sleep as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
      expect(v.range.today, today);
    });
  });

  group('再読み込み', () {
    test('refresh() 中に前回の値が残る', () async {
      await initial();
      fake.readGate = Completer<void>();
      fake.steps[today] = 100;
      final f = controller().refresh();
      await pump();
      expect(st().isLoading, isFalse);
      expect(value(), isA<DashboardReady>());
      fake.readGate!.complete();
      await f;
      final v = value() as DashboardReady;
      expect((v.steps as MetricLoaded<DailySteps>).days[0].steps, 100);
    });

    test('_fetch() の多重呼び出しが 1 回に合流する', () async {
      fake.readGate = Completer<void>();
      makeContainer();
      await pump();
      final a = controller().refresh();
      final b = controller().refresh();
      fake.readGate!.complete();
      await Future.wait([a, b]);
      expect(fake.checkAvailabilityCalls, 1);
      expect(fake.stepsCalls.length, 7);
    });
  });

  group('権限リクエスト', () {
    test('許可後の自動再読み込み', () async {
      fake.permissions = (steps: denied, sleep: denied);
      fake.permissionsAfterRequest = (steps: granted, sleep: granted);
      await initial();
      expect(value(), isA<DashboardNeedsPermission>());
      fake.readGate = Completer<void>();
      final f = controller().requestPermissions();
      await pump();
      expect(st().isLoading, isTrue);
      fake.readGate!.complete();
      await f;
      expect(st(), isA<AsyncData<DashboardState>>());
      final v = value() as DashboardReady;
      expect(v.steps, isA<MetricLoaded<dynamic>>());
      expect(v.sleep, isA<MetricLoaded<dynamic>>());
      expect(fake.requestPermissionsCalls, 1);
    });

    test('権限ダイアログ中の onResumed() は無視される', () async {
      await initial();
      fake.requestGate = Completer<void>();
      final f = controller().requestPermissions();
      await pump();
      final calls = fake.checkAvailabilityCalls;
      await controller().onResumed();
      expect(fake.checkAvailabilityCalls, calls);
      fake.requestGate!.complete();
      await f;
    });

    test('requestPermissions() が例外 → フラグが戻り、エラーにならない', () async {
      fake.requestError = Exception('x');
      await initial();
      await controller().requestPermissions();
      expect(st().hasError, isFalse);
      expect(value(), isA<DashboardReady>());
      fake.availability = HealthAvailability.updateRequired;
      await controller().onResumed();
      expect(value(), isA<DashboardUnavailable>());
    });

    test('実行中の refresh() があるときの requestPermissions()', () async {
      fake.permissions = (steps: denied, sleep: denied);
      fake.permissionsAfterRequest = (steps: granted, sleep: granted);
      await initial();
      expect(value(), isA<DashboardNeedsPermission>());
      final gate = Completer<void>();
      fake.permissionsGate = gate;
      final r = controller().refresh();
      await pump();
      final p = controller().requestPermissions();
      await pump();
      expect(fake.checkPermissionsCalls, 2);
      fake.permissionsGate = null;
      gate.complete();
      await Future.wait([r, p]);
      expect(fake.checkPermissionsCalls, 3);
      expect(fake.stepsCalls.length, 7);
      final v = value() as DashboardReady;
      expect(v.steps, isA<MetricLoaded<dynamic>>());
      expect(v.sleep, isA<MetricLoaded<dynamic>>());
    });

    test('requestPermissions() の二重呼び出しは 1 回だけリクエストする', () async {
      await initial();
      fake.requestGate = Completer<void>();
      final a = controller().requestPermissions();
      final b = controller().requestPermissions();
      await pump();
      expect(fake.requestPermissionsCalls, 1);
      fake.requestGate!.complete();
      await Future.wait([a, b]);
      expect(fake.requestPermissionsCalls, 1);
    });

    test('読み込みを待っている間に破棄されても例外を出さない', () async {
      fake.readGate = Completer<void>();
      makeContainer();
      await pump();
      final f = controller().requestPermissions();
      await pump();
      container.dispose();
      fake.readGate!.complete();
      await expectLater(f, completes);
    });
  });

  group('フォアグラウンド復帰', () {
    test('権限が変わらない復帰で再読み込みしない', () async {
      await initial();
      final n = fake.stepsCalls.length;
      await controller().onResumed();
      expect(fake.stepsCalls.length, n);
    });

    test('権限なしで終わった後、何も変えずに復帰 → 再読み込みしない', () async {
      fake.permissions = (steps: denied, sleep: denied);
      await initial();
      expect(fake.checkAvailabilityCalls, 1);
      await controller().onResumed();
      expect(fake.checkAvailabilityCalls, 2);
      expect(fake.stepsCalls, isEmpty);
      expect(fake.sleepCalls, isEmpty);
    });

    test('利用不可で終わった後、更新して復帰 → 再読み込み', () async {
      fake.availability = HealthAvailability.updateRequired;
      await initial();
      expect(value(), isA<DashboardUnavailable>());
      fake.availability = HealthAvailability.available;
      await controller().onResumed();
      expect(value(), isA<DashboardReady>());
    });

    test('権限が変わった復帰で再読み込み', () async {
      await initial();
      fake.permissions = (steps: granted, sleep: denied);
      await controller().onResumed();
      final v = value() as DashboardReady;
      expect(v.sleep, isA<MetricPermissionDenied<dynamic>>());
    });

    test('想定外の例外の後の復帰は必ず再読み込み', () async {
      fake.availabilityError = Exception('x');
      await initial();
      fake.availabilityError = null;
      await controller().onResumed();
      final v = value() as DashboardReady;
      expect(v.steps, isA<MetricLoaded<dynamic>>());
    });

    test('復帰の確認中の例外 → 再読み込み', () async {
      await initial();
      fake.permissionsError = Exception('x');
      await controller().onResumed();
      expect(st().hasError, isFalse);
      final v = value() as DashboardReady;
      expect(
        (v.steps as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
      expect(
        (v.sleep as MetricFailed<dynamic>).kind,
        HealthErrorKind.readFailed,
      );
    });
  });

  group('設定・ストア', () {
    test('openSettings() はリポジトリの結果を返し、状態を変えない', () async {
      await initial();
      final before = value();
      fake.openSettingsResult = false;
      expect(await controller().openSettings(), isFalse);
      expect(fake.openSettingsCalls, 1);
      expect(identical(value(), before), isTrue);
    });

    test('openStore() も同様', () async {
      await initial();
      final before = value();
      fake.openStoreResult = true;
      expect(await controller().openStore(), isTrue);
      expect(fake.openStoreCalls, 1);
      expect(identical(value(), before), isTrue);
    });
  });
}
