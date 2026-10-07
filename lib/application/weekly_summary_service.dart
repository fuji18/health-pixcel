import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/date_range_builder.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/date_range.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/domain/sleep_assignment.dart';

/// 直近 7 日の歩数・睡眠を組み立てる(機能設計書「WeeklySummaryService」)。
class WeeklySummaryService {
  /// リポジトリと時計から作る。
  WeeklySummaryService(this._repository, this._clock);

  final HealthRepository _repository;
  final DateTime Function() _clock;

  /// 時計を 1 回だけ読んで [DateRange] を作る。
  DateRange currentRange() => buildDateRange(_clock());

  /// 7 日分の歩数。1 日でも [HealthReadException] が出たら [MetricFailed]。
  Future<MetricResult<DailySteps>> loadSteps(DateRange range) async {
    try {
      final values = await Future.wait([
        for (var i = 0; i < range.days.length; i++)
          _repository.readTotalSteps(
            range.days[i],
            i == 0 ? range.now : nextDay(range.days[i]),
          ),
      ]);
      return MetricLoaded(
        List<DailySteps>.unmodifiable([
          for (var i = 0; i < range.days.length; i++)
            DailySteps(
              date: range.days[i],
              steps: values[i] == 0 ? null : values[i],
              isToday: i == 0,
            ),
        ]),
      );
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }

  /// 7 日分の睡眠。読み取り区間は [range.oldestDay - 1 日, range.now](機能設計書 A3)。
  Future<MetricResult<DailySleep>> loadSleep(DateRange range) async {
    final oldest = range.oldestDay;
    try {
      final sessions = await _repository.readSleepSessions(
        DateTime(oldest.year, oldest.month, oldest.day - 1),
        range.now,
      );
      return MetricLoaded(assignSleepToDays(range, sessions));
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }
}
