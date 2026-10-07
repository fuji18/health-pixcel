import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_pixcel/data/health_connect_repository.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

class _FakeHealth extends Fake implements Health {
  int configureCalls = 0;
  Object? configureError;
  HealthConnectSdkStatus? sdkStatus = HealthConnectSdkStatus.sdkAvailable;
  Map<HealthDataType, bool?> granted = {};
  Map<HealthDataType, bool?>? grantedAfterRequest;
  final hasPermissionsCalls =
      <(List<HealthDataType>, List<HealthDataAccess>?)>[];
  final requestCalls = <(List<HealthDataType>, List<HealthDataAccess>?)>[];
  int? totalSteps;
  final stepsCalls = <(DateTime, DateTime)>[];
  List<HealthDataPoint> points = [];
  final dataCalls = <(List<HealthDataType>, DateTime, DateTime)>[];
  Object? readError;
  Object? requestError;
  bool installThrows = false;

  @override
  Future<void> configure() async {
    configureCalls++;
    if (configureError != null) throw configureError!;
  }

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async =>
      sdkStatus;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    hasPermissionsCalls.add((types, permissions));
    if (readError != null) throw readError!;
    return granted[types.single];
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    requestCalls.add((types, permissions));
    if (requestError != null) throw requestError!;
    if (grantedAfterRequest != null) granted = grantedAfterRequest!;
    return true;
  }

  @override
  Future<void> installHealthConnect() async {
    if (installThrows) throw StateError('x');
  }

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async {
    stepsCalls.add((startTime, endTime));
    if (readError != null) throw readError!;
    return totalSteps;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    dataCalls.add((types, startTime, endTime));
    if (readError != null) throw readError!;
    return points;
  }
}

HealthDataPoint _sleep(DateTime from, DateTime to) => HealthDataPoint(
  uuid: 'u',
  value: NumericHealthValue(numericValue: 0),
  type: HealthDataType.SLEEP_SESSION,
  unit: HealthDataUnit.MINUTE,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: 's',
  sourceName: 'n',
);

Matcher _readException(HealthErrorKind kind) =>
    throwsA(isA<HealthReadException>().having((e) => e.kind, 'kind', kind));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeHealth fake;
  late HealthConnectRepository repo;
  final start = DateTime(2026, 10, 5);
  final end = DateTime(2026, 10, 6);

  setUp(() {
    fake = _FakeHealth();
    repo = HealthConnectRepository(health: fake);
  });

  group('checkAvailability', () {
    test('SDK の状態を変換する', () async {
      final cases = <HealthConnectSdkStatus?, HealthAvailability>{
        HealthConnectSdkStatus.sdkAvailable: HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
            HealthAvailability.updateRequired,
        HealthConnectSdkStatus.sdkUnavailable: HealthAvailability.notInstalled,
        null: HealthAvailability.notInstalled,
      };
      for (final entry in cases.entries) {
        fake.sdkStatus = entry.key;
        expect(await repo.checkAvailability(), entry.value);
      }
    });
  });

  group('checkPermissions', () {
    test('歩数のみ許可', () async {
      fake.granted = {
        HealthDataType.STEPS: true,
        HealthDataType.SLEEP_SESSION: false,
      };
      expect(await repo.checkPermissions(), (
        steps: PermissionStatus.granted,
        sleep: PermissionStatus.denied,
      ));
    });

    test('null は未許可', () async {
      fake.granted = {
        HealthDataType.STEPS: null,
        HealthDataType.SLEEP_SESSION: true,
      };
      expect(await repo.checkPermissions(), (
        steps: PermissionStatus.denied,
        sleep: PermissionStatus.granted,
      ));
    });

    test('種別ごとに個別に問い合わせる', () async {
      await repo.checkPermissions();
      expect(fake.hasPermissionsCalls, hasLength(2));
      expect(fake.hasPermissionsCalls[0].$1, [HealthDataType.STEPS]);
      expect(fake.hasPermissionsCalls[0].$2, [HealthDataAccess.READ]);
      expect(fake.hasPermissionsCalls[1].$1, [HealthDataType.SLEEP_SESSION]);
      expect(fake.hasPermissionsCalls[1].$2, [HealthDataAccess.READ]);
    });
  });

  group('requestPermissions', () {
    test('リクエスト後の状態を返す', () async {
      fake.granted = {
        HealthDataType.STEPS: false,
        HealthDataType.SLEEP_SESSION: false,
      };
      fake.grantedAfterRequest = {
        HealthDataType.STEPS: true,
        HealthDataType.SLEEP_SESSION: true,
      };
      expect(await repo.requestPermissions(), (
        steps: PermissionStatus.granted,
        sleep: PermissionStatus.granted,
      ));
      expect(fake.requestCalls.single.$1, [
        HealthDataType.STEPS,
        HealthDataType.SLEEP_SESSION,
      ]);
      expect(fake.requestCalls.single.$2, [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ]);
    });
  });

  group('readTotalSteps', () {
    test('合計を返し、引数がそのまま渡る', () async {
      fake.totalSteps = 8432;
      expect(await repo.readTotalSteps(start, end), 8432);
      expect(fake.stepsCalls.single, (start, end));
    });

    test('0 は記録なしとして null', () async {
      fake.totalSteps = 0;
      expect(await repo.readTotalSteps(start, end), isNull);
    });

    test('null は readFailed', () async {
      fake.totalSteps = null;
      await expectLater(
        repo.readTotalSteps(start, end),
        _readException(HealthErrorKind.readFailed),
      );
    });
  });

  group('readSleepSessions', () {
    test('UTC をローカル時刻に変換する', () async {
      final from = DateTime.utc(2026, 10, 5, 14);
      final to = DateTime.utc(2026, 10, 5, 21);
      fake.points = [_sleep(from, to)];
      final result = await repo.readSleepSessions(start, end);
      expect(result, hasLength(1));
      expect(result.single.start.isUtc, isFalse);
      expect(result.single.end.isUtc, isFalse);
      expect(result.single.start.isAtSameMomentAs(from), isTrue);
      expect(result.single.end.isAtSameMomentAs(to), isTrue);
    });

    test('長さ 0 以下の点は破棄する', () async {
      final t = DateTime.utc(2026, 10, 5, 14);
      fake.points = [
        _sleep(t, t),
        _sleep(t, t.subtract(const Duration(hours: 1))),
        _sleep(t, t.add(const Duration(hours: 7))),
      ];
      final result = await repo.readSleepSessions(start, end);
      expect(result, hasLength(1));
      expect(result.single.start.isAtSameMomentAs(t.toLocal()), isTrue);
      expect(
        result.single.end.isAtSameMomentAs(
          t.add(const Duration(hours: 7)).toLocal(),
        ),
        isTrue,
      );
    });

    test('問い合わせ引数が渡る', () async {
      await repo.readSleepSessions(start, end);
      expect(fake.dataCalls.single.$1, [HealthDataType.SLEEP_SESSION]);
      expect(fake.dataCalls.single.$2, start);
      expect(fake.dataCalls.single.$3, end);
    });

    test('戻り値は不変', () async {
      fake.points = [
        _sleep(DateTime.utc(2026, 10, 5, 14), DateTime.utc(2026, 10, 5, 21)),
      ];
      final result = await repo.readSleepSessions(start, end);
      expect(() => result.add(result.first), throwsUnsupportedError);
    });
  });

  group('例外の変換', () {
    test('UnsupportedError は unavailable', () async {
      fake.readError = UnsupportedError('x');
      await expectLater(
        repo.readTotalSteps(start, end),
        _readException(HealthErrorKind.unavailable),
      );
      await expectLater(
        repo.readSleepSessions(start, end),
        _readException(HealthErrorKind.unavailable),
      );
      await expectLater(
        repo.checkPermissions(),
        _readException(HealthErrorKind.unavailable),
      );
    });

    test('HealthException は readFailed', () async {
      fake.readError = HealthException(HealthDataType.STEPS, 'x');
      await expectLater(
        repo.readSleepSessions(start, end),
        _readException(HealthErrorKind.readFailed),
      );
    });

    test('その他の例外は readFailed', () async {
      fake.readError = StateError('x');
      await expectLater(
        repo.readTotalSteps(start, end),
        _readException(HealthErrorKind.readFailed),
      );
    });

    test('configure の失敗は readFailed', () async {
      fake.configureError = StateError('x');
      await expectLater(
        repo.checkAvailability(),
        _readException(HealthErrorKind.readFailed),
      );
    });

    test('requestPermissions: UnsupportedError は unavailable', () async {
      fake.readError = UnsupportedError('x');
      await expectLater(
        repo.requestPermissions(),
        _readException(HealthErrorKind.unavailable),
      );
    });

    test('requestPermissions: HealthException は readFailed', () async {
      fake.requestError = HealthException(HealthDataType.STEPS, 'x');
      await expectLater(
        repo.requestPermissions(),
        _readException(HealthErrorKind.readFailed),
      );
    });

    test('configure の UnsupportedError は unavailable', () async {
      fake.configureError = UnsupportedError('x');
      await expectLater(
        repo.checkAvailability(),
        _readException(HealthErrorKind.unavailable),
      );
    });

    test('configure 失敗後は再試行せず readFailed のまま', () async {
      fake.configureError = StateError('x');
      fake.totalSteps = 1;
      await expectLater(
        repo.checkAvailability(),
        _readException(HealthErrorKind.readFailed),
      );
      await expectLater(
        repo.readTotalSteps(start, end),
        _readException(HealthErrorKind.readFailed),
      );
      expect(fake.configureCalls, 1);
    });
  });

  test('並行呼び出しでも configure は 1 回だけ', () async {
    fake.totalSteps = 100;
    await Future.wait([
      repo.checkAvailability(),
      repo.checkPermissions(),
      repo.readTotalSteps(start, end),
    ]);
    expect(fake.configureCalls, 1);
  });

  test('configure は 1 回だけ', () async {
    fake.totalSteps = 1;
    await repo.checkAvailability();
    await repo.checkPermissions();
    await repo.readTotalSteps(start, end);
    await repo.readSleepSessions(start, end);
    expect(fake.configureCalls, 1);
  });

  group('openHealthConnectStore', () {
    test('通常は true', () async {
      expect(await repo.openHealthConnectStore(), isTrue);
    });

    test('失敗時は false', () async {
      fake.installThrows = true;
      expect(await repo.openHealthConnectStore(), isFalse);
    });
  });

  group('openPermissionSettings', () {
    const channel = MethodChannel('health_pixcel/health_connect_settings');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('チャネルが true を返せば true', () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return true;
      });
      expect(await repo.openPermissionSettings(), isTrue);
      expect(methods, ['open']);
    });

    test('チャネルが false を返せば false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(await repo.openPermissionSettings(), isFalse);
    });
  });
}
