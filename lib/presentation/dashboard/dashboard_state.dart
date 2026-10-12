import 'package:health_pixcel/domain/models/daily_exercise.dart';
import 'package:health_pixcel/domain/models/daily_heart_rate.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/daily_weight.dart';
import 'package:health_pixcel/domain/models/date_range.dart';
import 'package:health_pixcel/domain/models/display_period.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';

/// ダッシュボードの画面状態。読み込み中は Riverpod の AsyncLoading で表す。
sealed class DashboardState {
  const DashboardState();
}

/// ヘルスコネクトが使えない(F4)。
class DashboardUnavailable extends DashboardState {
  const DashboardUnavailable(this.availability);

  /// notInstalled / updateRequired。
  final HealthAvailability availability;
}

/// すべてのデータ種別が未許可(F4)。
class DashboardNeedsPermission extends DashboardState {
  const DashboardNeedsPermission();
}

/// 少なくとも 1 種別が許可済み(F2 / F3 / F4)。
class DashboardReady extends DashboardState {
  const DashboardReady({
    required this.period,
    required this.range,
    required this.steps,
    required this.sleep,
    required this.heartRate,
    required this.weight,
    required this.exercise,
  });

  /// 表示期間。range.days.length == period.dayCount。
  final DisplayPeriod period;

  /// 表示する期間の日付範囲。
  final DateRange range;

  /// 歩数の取得結果。
  final MetricResult<DailySteps> steps;

  /// 睡眠の取得結果。
  final MetricResult<DailySleep> sleep;

  /// 心拍の取得結果。
  final MetricResult<DailyHeartRate> heartRate;

  /// 体重の取得結果。
  final MetricResult<DailyWeight> weight;

  /// 運動の取得結果。
  final MetricResult<DailyExercise> exercise;

  /// F4 のデータなし案内を出すかどうか(機能設計書「isAllEmpty の定義」)。
  bool get isAllEmpty {
    final steps = this.steps;
    final sleep = this.sleep;
    final heartRate = this.heartRate;
    final weight = this.weight;
    final exercise = this.exercise;
    if (steps is MetricFailed ||
        sleep is MetricFailed ||
        heartRate is MetricFailed ||
        weight is MetricFailed ||
        exercise is MetricFailed) {
      return false;
    }
    if (steps is! MetricLoaded<DailySteps> &&
        sleep is! MetricLoaded<DailySleep> &&
        heartRate is! MetricLoaded<DailyHeartRate> &&
        weight is! MetricLoaded<DailyWeight> &&
        exercise is! MetricLoaded<DailyExercise>) {
      return false;
    }
    final stepsEmpty = switch (steps) {
      MetricLoaded<DailySteps>(:final days) => days.every(
        (d) => d.steps == null,
      ),
      _ => true,
    };
    final sleepEmpty = switch (sleep) {
      MetricLoaded<DailySleep>(:final days) => days.every((d) => !d.hasRecord),
      _ => true,
    };
    final heartRateEmpty = switch (heartRate) {
      MetricLoaded<DailyHeartRate>(:final days) => days.every(
        (d) => d.stats == null,
      ),
      _ => true,
    };
    final weightEmpty = switch (weight) {
      MetricLoaded<DailyWeight>(:final days) => days.every((d) => d.kg == null),
      _ => true,
    };
    final exerciseEmpty = switch (exercise) {
      MetricLoaded<DailyExercise>(:final days) => days.every(
        (d) => !d.hasRecord,
      ),
      _ => true,
    };
    return stepsEmpty &&
        sleepEmpty &&
        heartRateEmpty &&
        weightEmpty &&
        exerciseEmpty;
  }
}
