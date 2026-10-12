import 'dart:async';

import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/models/exercise_session.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/heart_rate_stats.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

/// テスト用の HealthRepository。各フィールドで戻り値・失敗・待機を差し替える。
class FakeHealthRepository implements HealthRepository {
  /// checkAvailability の戻り値。availabilityQueue が空でないときはそちらを先頭から使う。
  HealthAvailability availability = HealthAvailability.available;

  /// availability より優先して先頭から消費する戻り値。
  final availabilityQueue = <HealthAvailability>[];

  /// 非 null なら checkAvailability がこれを投げる。
  Exception? availabilityError;

  /// checkAvailability の呼び出し回数。
  int checkAvailabilityCalls = 0;

  /// checkPermissions の戻り値。
  HealthPermissions permissions = const HealthPermissions({
    HealthMetric.steps,
    HealthMetric.sleep,
    HealthMetric.heartRate,
    HealthMetric.weight,
    HealthMetric.exercise,
  });

  /// 非 null なら checkPermissions がこれを投げる。
  Exception? permissionsError;

  /// 非 null なら checkPermissions は呼ばれた時点の permissions を取ってから、これの完了を待って返す。
  Completer<void>? permissionsGate;

  /// checkPermissions の呼び出し回数。
  int checkPermissionsCalls = 0;

  /// 非 null なら requestPermissions の後に permissions をこれで置き換える。
  HealthPermissions? permissionsAfterRequest;

  /// 非 null なら requestPermissions はこれの完了を待つ(ダイアログ表示中を表す)。
  Completer<void>? requestGate;

  /// 非 null なら requestPermissions がこれを投げる(requestGate の後)。
  Exception? requestError;

  /// requestPermissions の呼び出し回数。
  int requestPermissionsCalls = 0;

  /// openPermissionSettings の戻り値。
  bool openSettingsResult = true;

  /// openPermissionSettings の呼び出し回数。
  int openSettingsCalls = 0;

  /// openHealthConnectStore の戻り値。
  bool openStoreResult = true;

  /// openHealthConnectStore の呼び出し回数。
  int openStoreCalls = 0;

  /// 日付(00:00)→ 歩数。キーが無い日は null(記録なし)。
  final steps = <DateTime, int>{};

  /// 日付(00:00)→ その日の readTotalSteps が投げる HealthReadException の種類。
  final stepsErrors = <DateTime, HealthErrorKind>{};

  /// readTotalSteps の呼び出し履歴(start, end)。
  final stepsCalls = <(DateTime, DateTime)>[];

  /// 日付(00:00)→ 心拍の集計値。キーが無い日は null(記録なし)。
  final heartRates = <DateTime, HeartRateStats>{};

  /// 日付(00:00)→ その日の readHeartRate が投げる HealthReadException の種類。
  final heartRateErrors = <DateTime, HealthErrorKind>{};

  /// readHeartRate の呼び出し履歴(start, end)。
  final heartRateCalls = <(DateTime, DateTime)>[];

  /// 日付(00:00)→ 体重(kg)。キーが無い日は null(記録なし)。
  final weights = <DateTime, double>{};

  /// 日付(00:00)→ その日の readLatestWeight が投げる HealthReadException の種類。
  final weightErrors = <DateTime, HealthErrorKind>{};

  /// readLatestWeight の呼び出し履歴(start, end)。
  final weightCalls = <(DateTime, DateTime)>[];

  /// readSleepSessions の戻り値。
  List<SleepSession> sleepSessions = [];

  /// 非 null なら readSleepSessions が HealthReadException(sleepError) を投げる。
  HealthErrorKind? sleepError;

  /// readSleepSessions の呼び出し履歴(start, end)。
  final sleepCalls = <(DateTime, DateTime)>[];

  /// readExerciseSessions の戻り値。
  List<ExerciseSession> exerciseSessions = [];

  /// 非 null なら readExerciseSessions が HealthReadException(exerciseError) を投げる。
  HealthErrorKind? exerciseError;

  /// readExerciseSessions の呼び出し履歴(start, end)。
  final exerciseCalls = <(DateTime, DateTime)>[];

  /// 非 null なら readTotalSteps / readSleepSessions / readHeartRate / readLatestWeight / readExerciseSessions はこれの完了を待つ(読み込み中を表す)。
  Completer<void>? readGate;

  @override
  Future<HealthAvailability> checkAvailability() async {
    checkAvailabilityCalls++;
    final error = availabilityError;
    if (error != null) throw error;
    if (availabilityQueue.isNotEmpty) return availabilityQueue.removeAt(0);
    return availability;
  }

  @override
  Future<HealthPermissions> checkPermissions() async {
    checkPermissionsCalls++;
    final error = permissionsError;
    if (error != null) throw error;
    final p = permissions;
    await permissionsGate?.future;
    return p;
  }

  @override
  Future<HealthPermissions> requestPermissions() async {
    requestPermissionsCalls++;
    await requestGate?.future;
    final error = requestError;
    if (error != null) throw error;
    final after = permissionsAfterRequest;
    if (after != null) permissions = after;
    return permissions;
  }

  @override
  Future<bool> openPermissionSettings() async {
    openSettingsCalls++;
    return openSettingsResult;
  }

  @override
  Future<bool> openHealthConnectStore() async {
    openStoreCalls++;
    return openStoreResult;
  }

  @override
  Future<int?> readTotalSteps(DateTime start, DateTime end) async {
    stepsCalls.add((start, end));
    await readGate?.future;
    final kind = stepsErrors[start];
    if (kind != null) throw HealthReadException(kind);
    return steps[start];
  }

  @override
  Future<List<SleepSession>> readSleepSessions(
    DateTime start,
    DateTime end,
  ) async {
    sleepCalls.add((start, end));
    await readGate?.future;
    final kind = sleepError;
    if (kind != null) throw HealthReadException(kind);
    return sleepSessions;
  }

  @override
  Future<HeartRateStats?> readHeartRate(DateTime start, DateTime end) async {
    heartRateCalls.add((start, end));
    await readGate?.future;
    final kind = heartRateErrors[start];
    if (kind != null) throw HealthReadException(kind);
    return heartRates[start];
  }

  @override
  Future<double?> readLatestWeight(DateTime start, DateTime end) async {
    weightCalls.add((start, end));
    await readGate?.future;
    final kind = weightErrors[start];
    if (kind != null) throw HealthReadException(kind);
    return weights[start];
  }

  @override
  Future<List<ExerciseSession>> readExerciseSessions(
    DateTime start,
    DateTime end,
  ) async {
    exerciseCalls.add((start, end));
    await readGate?.future;
    final kind = exerciseError;
    if (kind != null) throw HealthReadException(kind);
    return exerciseSessions;
  }
}
