import 'package:health/health.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

/// [HealthRepository] の Android 実装(ヘルスコネクト。`health` パッケージ経由)。
class HealthConnectRepository implements HealthRepository {
  /// [health] はテストでフェイクを注入するための引数。省略時は `Health()`。
  HealthConnectRepository({Health? health}) : _health = health ?? Health();

  final Health _health;

  // late final なので初回アクセス時に 1 度だけ configure() が走る(functional-design.md)。
  late final Future<void> _configured = _health.configure();

  /// configure 済みにしてから [body] を実行し、例外を [HealthReadException] に変換する。
  /// 元の例外はログにも戻り値にも残さない。
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      await _configured;
      return await body();
    } on HealthReadException {
      rethrow;
    } on UnsupportedError {
      // ヘルスコネクト利用不可(health が投げる)
      throw const HealthReadException(HealthErrorKind.unavailable);
    } catch (_) {
      throw const HealthReadException(HealthErrorKind.readFailed);
    }
  }

  @override
  Future<HealthAvailability> checkAvailability() => _guard(() async {
    final status = await _health.getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.updateRequired,
      HealthConnectSdkStatus.sdkUnavailable ||
      null => HealthAvailability.notInstalled,
    };
  });

  @override
  Future<({PermissionStatus steps, PermissionStatus sleep})>
  checkPermissions() => _guard(_readPermissions);

  @override
  Future<({PermissionStatus steps, PermissionStatus sleep})>
  requestPermissions() => _guard(() async {
    await _health.requestAuthorization(
      const [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION],
      permissions: const [HealthDataAccess.READ, HealthDataAccess.READ],
    );
    return _readPermissions();
  });

  /// 暫定実装。常に false を返す。
  @override
  Future<bool> openPermissionSettings() async {
    // #9 で MethodChannel(health_pixcel/health_connect_settings)の実装に置き換える
    return false;
  }

  @override
  Future<bool> openHealthConnectStore() async {
    try {
      await _configured;
      await _health.installHealthConnect();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 記録なし(0)は null、取得失敗(null)は [HealthReadException] を投げる。
  @override
  Future<int?> readTotalSteps(DateTime start, DateTime end) => _guard(() async {
    final steps = await _health.getTotalStepsInInterval(start, end);
    // health 13.3.2 は記録なしで 0、ネイティブ例外で null を返すため、
    // null は失敗、0 は記録なしとして区別する。
    if (steps == null) {
      throw const HealthReadException(HealthErrorKind.readFailed);
    }
    return steps == 0 ? null : steps;
  });

  @override
  Future<List<SleepSession>> readSleepSessions(DateTime start, DateTime end) =>
      _guard(() async {
        final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.SLEEP_SESSION],
          startTime: start,
          endTime: end,
        );
        return List<SleepSession>.unmodifiable([
          for (final p in points)
            if (p.dateTo.isAfter(p.dateFrom))
              SleepSession(
                start: p.dateFrom.toLocal(),
                end: p.dateTo.toLocal(),
              ),
        ]);
      });

  Future<({PermissionStatus steps, PermissionStatus sleep})>
  _readPermissions() async {
    // 片方だけ許可を判別するため、種別ごとに個別に問い合わせる
    final steps = await _health.hasPermissions(
      const [HealthDataType.STEPS],
      permissions: const [HealthDataAccess.READ],
    );
    final sleep = await _health.hasPermissions(
      const [HealthDataType.SLEEP_SESSION],
      permissions: const [HealthDataAccess.READ],
    );
    return (steps: _toStatus(steps), sleep: _toStatus(sleep));
  }

  /// null / false は未許可として扱う。
  static PermissionStatus _toStatus(bool? granted) =>
      granted == true ? PermissionStatus.granted : PermissionStatus.denied;
}
