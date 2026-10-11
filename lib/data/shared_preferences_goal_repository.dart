import 'package:health_pixcel/data/goal_repository.dart';
import 'package:health_pixcel/domain/goal_input.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:shared_preferences/shared_preferences.dart'; // privacy-check: allow(目標値の保存。健康データは保存しない)

const _stepsKey = 'goal.steps';
const _sleepMinutesKey = 'goal.sleep_minutes';

/// 目標値を shared_preferences(Android は DataStore)に保存する実装。
class SharedPreferencesGoalRepository implements GoalRepository {
  SharedPreferencesAsync? _prefs;

  SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

  @override
  Future<Goals> load() async {
    try {
      final values = await Future.wait([
        _store.getInt(_stepsKey),
        _store.getInt(_sleepMinutesKey),
      ]);
      final steps = values[0];
      final sleep = values[1];
      return Goals(
        steps: steps != null && steps >= minStepsGoal && steps <= maxStepsGoal
            ? steps
            : null,
        sleepMinutes:
            sleep != null &&
                sleep >= minSleepGoalMinutes &&
                sleep <= maxSleepGoalMinutes
            ? sleep
            : null,
      );
    } on Exception catch (_) {
      throw const GoalStorageException();
    }
  }

  @override
  Future<void> save(Goals goals) async {
    try {
      await _write(_stepsKey, goals.steps);
      await _write(_sleepMinutesKey, goals.sleepMinutes);
    } on Exception catch (_) {
      throw const GoalStorageException();
    }
  }

  Future<void> _write(String key, int? value) =>
      value == null ? _store.remove(key) : _store.setInt(key, value);
}
