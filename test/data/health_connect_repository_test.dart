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

HealthDataPoint _heart(DateTime from, num bpm) => HealthDataPoint(
  uuid: 'u',
  value: NumericHealthValue(numericValue: bpm),
  type: HealthDataType.HEART_RATE,
  unit: HealthDataUnit.BEATS_PER_MINUTE,
  dateFrom: from,
  dateTo: from,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: 's',
  sourceName: 'n',
);

HealthDataPoint _weight(DateTime from, num kg) => HealthDataPoint(
  uuid: 'u',
  value: NumericHealthValue(numericValue: kg),
  type: HealthDataType.WEIGHT,
  unit: HealthDataUnit.KILOGRAM,
  dateFrom: from,
  dateTo: from,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: 's',
  sourceName: 'n',
);

HealthDataPoint _workout(DateTime from, DateTime to) => HealthDataPoint(
  uuid: 'u',
  value: WorkoutHealthValue(
    workoutActivityType: HealthWorkoutActivityType.RUNNING,
  ),
  type: HealthDataType.WORKOUT,
  unit: HealthDataUnit.NO_UNIT,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: 's',
  sourceName: 'n',
);

const _allTypes = [
  HealthDataType.STEPS,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.HEART_RATE,
  HealthDataType.WEIGHT,
  HealthDataType.WORKOUT,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.TOTAL_CALORIES_BURNED,
];

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
        HealthDataType.HEART_RATE: false,
      };
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({HealthMetric.steps}),
      );
    });

    test('null / false は未許可(心拍だけ未許可)', () async {
      fake.granted = {
        HealthDataType.STEPS: true,
        HealthDataType.SLEEP_SESSION: true,
        HealthDataType.HEART_RATE: null,
      };
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({HealthMetric.steps, HealthMetric.sleep}),
      );
      fake.granted[HealthDataType.HEART_RATE] = false;
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({HealthMetric.steps, HealthMetric.sleep}),
      );
    });

    test('体重だけ未許可', () async {
      fake.granted = {
        HealthDataType.STEPS: true,
        HealthDataType.SLEEP_SESSION: true,
        HealthDataType.HEART_RATE: true,
        HealthDataType.WEIGHT: false,
      };
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({
          HealthMetric.steps,
          HealthMetric.sleep,
          HealthMetric.heartRate,
        }),
      );
    });

    test('WORKOUT は許可・DISTANCE_DELTA だけ未許可 → 運動は未許可、歩数は許可', () async {
      fake.granted = {
        HealthDataType.STEPS: true,
        HealthDataType.WORKOUT: true,
        HealthDataType.DISTANCE_DELTA: false,
        HealthDataType.TOTAL_CALORIES_BURNED: true,
      };
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({HealthMetric.steps}),
      );
    });

    test('STEPS だけ未許可 → 歩数と運動が未許可', () async {
      fake.granted = {
        HealthDataType.STEPS: false,
        HealthDataType.WORKOUT: true,
        HealthDataType.DISTANCE_DELTA: true,
        HealthDataType.TOTAL_CALORIES_BURNED: true,
      };
      expect(await repo.checkPermissions(), const HealthPermissions({}));
    });

    test('7 型すべて許可 → 5 種とも許可', () async {
      fake.granted = {for (final t in _allTypes) t: true};
      expect(
        await repo.checkPermissions(),
        const HealthPermissions({
          HealthMetric.steps,
          HealthMetric.sleep,
          HealthMetric.heartRate,
          HealthMetric.weight,
          HealthMetric.exercise,
        }),
      );
    });

    test('型ごとに個別に問い合わせる', () async {
      await repo.checkPermissions();
      expect(fake.hasPermissionsCalls, hasLength(7));
      final types = [for (final c in fake.hasPermissionsCalls) c.$1];
      expect(types, [
        for (final t in _allTypes) [t],
      ]);
      for (final c in fake.hasPermissionsCalls) {
        expect(c.$2, [HealthDataAccess.READ]);
      }
    });
  });

  group('requestPermissions', () {
    test('リクエスト後の状態を返す', () async {
      fake.granted = {for (final t in _allTypes) t: false};
      fake.grantedAfterRequest = {for (final t in _allTypes) t: true};
      expect(
        await repo.requestPermissions(),
        const HealthPermissions({
          HealthMetric.steps,
          HealthMetric.sleep,
          HealthMetric.heartRate,
          HealthMetric.weight,
          HealthMetric.exercise,
        }),
      );
      expect(fake.requestCalls.single.$1, _allTypes);
      expect(fake.requestCalls.single.$2, [
        for (final _ in _allTypes) HealthDataAccess.READ,
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

  group('readHeartRate', () {
    test('区間内の標本だけで集計する', () async {
      fake.points = [
        _heart(start.subtract(const Duration(minutes: 1)), 200), // 区間の前
        _heart(start, 60), // start ちょうどは含む
        _heart(start.add(const Duration(hours: 3)), 100),
        _heart(end, 30), // end ちょうどは除外
      ];
      final stats = await repo.readHeartRate(start, end);
      expect(stats!.average, 80);
      expect(stats.min, 60);
      expect(stats.max, 100);
      expect(fake.dataCalls.single.$1, [HealthDataType.HEART_RATE]);
      expect(fake.dataCalls.single.$2, start);
      expect(fake.dataCalls.single.$3, end);
    });

    test('標本なし → null', () async {
      expect(await repo.readHeartRate(start, end), isNull);
    });

    test('例外の変換', () async {
      fake.readError = StateError('x');
      await expectLater(
        repo.readHeartRate(start, end),
        _readException(HealthErrorKind.readFailed),
      );
      fake.readError = UnsupportedError('x');
      await expectLater(
        repo.readHeartRate(start, end),
        _readException(HealthErrorKind.unavailable),
      );
    });
  });

  group('readLatestWeight', () {
    test('区間内の最新の記録を返す', () async {
      fake.points = [
        _weight(start.subtract(const Duration(minutes: 1)), 70), // 区間の前
        _weight(start, 65.0), // start ちょうどは含む
        _weight(start.add(const Duration(hours: 3)), 65.3),
        _weight(end, 60), // end ちょうどは除外
      ];
      expect(await repo.readLatestWeight(start, end), 65.3);
      expect(fake.dataCalls.single.$1, [HealthDataType.WEIGHT]);
      expect(fake.dataCalls.single.$2, start);
      expect(fake.dataCalls.single.$3, end);
    });

    test('start ちょうどだけ → その値', () async {
      fake.points = [_weight(start, 65)];
      expect(await repo.readLatestWeight(start, end), 65.0);
    });

    test('記録なし → null', () async {
      expect(await repo.readLatestWeight(start, end), isNull);
    });

    test('例外の変換', () async {
      fake.readError = StateError('x');
      await expectLater(
        repo.readLatestWeight(start, end),
        _readException(HealthErrorKind.readFailed),
      );
      fake.readError = UnsupportedError('x');
      await expectLater(
        repo.readLatestWeight(start, end),
        _readException(HealthErrorKind.unavailable),
      );
    });
  });

  group('readExerciseSessions', () {
    test('WORKOUT 型・指定区間で 1 回呼ぶ', () async {
      await repo.readExerciseSessions(start, end);
      expect(fake.dataCalls, hasLength(1));
      expect(fake.dataCalls.single.$1, [HealthDataType.WORKOUT]);
      expect(fake.dataCalls.single.$2, start);
      expect(fake.dataCalls.single.$3, end);
    });

    test('長さ 0 以下の記録を捨て、ローカル時刻にする', () async {
      final t = DateTime.utc(2026, 10, 5, 14);
      final to = t.add(const Duration(minutes: 45));
      fake.points = [
        _workout(t, t),
        _workout(t, t.subtract(const Duration(hours: 1))),
        _workout(t, to),
      ];
      final result = await repo.readExerciseSessions(start, end);
      expect(result, hasLength(1));
      expect(result.single.start.isUtc, isFalse);
      expect(result.single.end.isUtc, isFalse);
      expect(result.single.start.isAtSameMomentAs(t), isTrue);
      expect(result.single.end.isAtSameMomentAs(to), isTrue);
    });

    test('例外の変換', () async {
      fake.readError = StateError('x');
      await expectLater(
        repo.readExerciseSessions(start, end),
        _readException(HealthErrorKind.readFailed),
      );
      fake.readError = UnsupportedError('x');
      await expectLater(
        repo.readExerciseSessions(start, end),
        _readException(HealthErrorKind.unavailable),
      );
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
