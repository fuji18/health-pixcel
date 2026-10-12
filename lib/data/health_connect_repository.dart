import 'package:health/health.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/data/platform_channels.dart';
import 'package:health_pixcel/domain/heart_rate_summary.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';
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

  /// 読み取るデータ種別と、その種別の読み取りに要る health の型。
  /// 運動記録は health 13.3.2 が距離・消費カロリー・歩数も読むため 4 型すべてが要る(design.md「前提」)。
  static const _types = {
    HealthMetric.steps: [HealthDataType.STEPS],
    HealthMetric.sleep: [HealthDataType.SLEEP_SESSION],
    HealthMetric.heartRate: [HealthDataType.HEART_RATE],
    HealthMetric.weight: [HealthDataType.WEIGHT],
    HealthMetric.exercise: [
      HealthDataType.WORKOUT,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.STEPS,
    ],
  };

  /// リクエスト・問い合わせする型(重複なし。_types の出現順)。
  static final _requestTypes = {for (final types in _types.values) ...types}
      .toList(growable: false);

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
      _requestTypes,
      permissions: [for (final _ in _requestTypes) HealthDataAccess.READ],
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

  @override
  Future<List<ExerciseSession>> readExerciseSessions(
    DateTime start,
    DateTime end,
  ) => _guard(() async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: start,
      endTime: end,
    );
    // 距離・消費カロリーなど WorkoutHealthValue の中身は読まない(表示しない。PRD)
    return List<ExerciseSession>.unmodifiable([
      for (final p in points)
        if (p.dateTo.isAfter(p.dateFrom))
          ExerciseSession(start: p.dateFrom.toLocal(), end: p.dateTo.toLocal()),
    ]);
  });

  Future<HealthPermissions> _readPermissions() async {
    // 型ごとに個別に問い合わせる。null / false は未許可
    final grantedTypes = <HealthDataType>{};
    for (final type in _requestTypes) {
      final ok = await _health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
      if (ok == true) grantedTypes.add(type);
    }
    // 種別は、読み取りに要る型がすべて許可済みのときだけ許可
    return HealthPermissions(
      Set.unmodifiable({
        for (final entry in _types.entries)
          if (grantedTypes.containsAll(entry.value)) entry.key,
      }),
    );
  }
}
