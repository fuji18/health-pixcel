import 'package:health/health.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/data/platform_channels.dart';
import 'package:health_pixcel/domain/heart_rate_summary.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/heart_rate_stats.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
import 'package:health_pixcel/domain/weight_summary.dart';

/// [HealthRepository] の Android 実装(ヘルスコネクト。`health` パッケージ経由)。
class HealthConnectRepository implements HealthRepository {
  /// [health] / [settingsChannel] はテストでフェイクを注入するための引数。
  HealthConnectRepository({
    Health? health,
    HealthConnectSettingsChannel? settingsChannel,
  }) : _health = health ?? Health(),
       _settingsChannel =
           settingsChannel ?? const HealthConnectSettingsChannel();

  final Health _health;
  final HealthConnectSettingsChannel _settingsChannel;

  /// 読み取るデータ種別と health の型の対応。
  static const _types = {
    HealthMetric.steps: HealthDataType.STEPS,
    HealthMetric.sleep: HealthDataType.SLEEP_SESSION,
    HealthMetric.heartRate: HealthDataType.HEART_RATE,
    HealthMetric.weight: HealthDataType.WEIGHT,
  };

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
  Future<HealthPermissions> checkPermissions() => _guard(_readPermissions);

  @override
  Future<HealthPermissions> requestPermissions() => _guard(() async {
    await _health.requestAuthorization(
      _types.values.toList(),
      permissions: [for (final _ in _types.values) HealthDataAccess.READ],
    );
    return _readPermissions();
  });

  @override
  Future<bool> openPermissionSettings() => _settingsChannel.open();

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

  @override
  Future<HeartRateStats?> readHeartRate(DateTime start, DateTime end) =>
      _guard(() async {
        final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.HEART_RATE],
          startTime: start,
          endTime: end,
        );
        // 区間をまたぐレコードは丸ごと返るため、標本の時刻で [start, end) に絞る
        return summarizeHeartRate([
          for (final p in points)
            if (!p.dateFrom.isBefore(start) && p.dateFrom.isBefore(end))
              if (p.value case NumericHealthValue(:final numericValue))
                numericValue,
        ]);
      });

  @override
  Future<double?> readLatestWeight(DateTime start, DateTime end) =>
      _guard(() async {
        final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.WEIGHT],
          startTime: start,
          endTime: end,
        );
        // 心拍と同じく、記録の時刻で [start, end) に絞る
        return pickLatestWeight([
          for (final p in points)
            if (!p.dateFrom.isBefore(start) && p.dateFrom.isBefore(end))
              if (p.value case NumericHealthValue(:final numericValue))
                (at: p.dateFrom, kg: numericValue),
        ]);
      });

  Future<HealthPermissions> _readPermissions() async {
    // 種別ごとに許可を判別するため、個別に問い合わせる。null / false は未許可
    final granted = <HealthMetric>{};
    for (final entry in _types.entries) {
      final ok = await _health.hasPermissions(
        [entry.value],
        permissions: const [HealthDataAccess.READ],
      );
      if (ok == true) granted.add(entry.key);
    }
    return HealthPermissions(Set.unmodifiable(granted));
  }
}
