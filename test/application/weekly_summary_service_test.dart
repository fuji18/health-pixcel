import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/application/weekly_summary_service.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

import '../fakes/fake_health_repository.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10, 30);
  var clockCalls = 0;
  DateTime clock() {
    clockCalls++;
    return now;
  }

  late FakeHealthRepository fake;
  late WeeklySummaryService service;

  setUp(() {
    fake = FakeHealthRepository();
    clockCalls = 0;
    service = WeeklySummaryService(fake, clock);
  });

  test('currentRange が時計を 1 回読む', () {
    final r = service.currentRange();
    expect(r.today, DateTime(2026, 10, 6));
    expect(r.now, now);
    expect(clockCalls, 1);
  });

  test('歩数: 7 日分・新しい順・今日の終端が range.now', () async {
    fake.steps[DateTime(2026, 10, 6)] = 8432;
    fake.steps[DateTime(2026, 10, 4)] = 0;
    final r = service.currentRange();
    final result = await service.loadSteps(r);
    final loaded = result as MetricLoaded<DailySteps>;
    final days = loaded.days;
    expect(days.length, 7);
    expect(days[0].date, DateTime(2026, 10, 6));
    expect(days[0].steps, 8432);
    expect(days[0].isToday, isTrue);
    expect(days[1].steps, isNull);
    expect(days[1].isToday, isFalse);
    expect(days[2].steps, isNull);
    expect(days[6].date, DateTime(2026, 9, 30));
    expect(fake.stepsCalls.length, 7);
    expect(fake.stepsCalls, contains((DateTime(2026, 10, 6), now)));
    expect(
      fake.stepsCalls,
      contains((DateTime(2026, 10, 5), DateTime(2026, 10, 6))),
    );
    expect(
      fake.stepsCalls,
      contains((DateTime(2026, 9, 30), DateTime(2026, 10, 1))),
    );
  });

  test('歩数: 1 日失敗 → MetricFailed', () async {
    fake.stepsErrors[DateTime(2026, 10, 3)] = HealthErrorKind.readFailed;
    final result = await service.loadSteps(service.currentRange());
    expect(
      (result as MetricFailed<DailySteps>).kind,
      HealthErrorKind.readFailed,
    );
  });

  test('歩数: unavailable はそのまま返す', () async {
    fake.stepsErrors[DateTime(2026, 10, 3)] = HealthErrorKind.unavailable;
    final result = await service.loadSteps(service.currentRange());
    expect(
      (result as MetricFailed<DailySteps>).kind,
      HealthErrorKind.unavailable,
    );
  });

  test('睡眠: 読み取り区間と振り分け', () async {
    fake.sleepSessions = [
      SleepSession(
        start: DateTime(2026, 10, 5, 23),
        end: DateTime(2026, 10, 6, 7),
      ),
    ];
    final result = await service.loadSleep(service.currentRange());
    final days = (result as MetricLoaded<DailySleep>).days;
    expect(days[0].sessions.length, 1);
    expect(days[1].hasRecord, isFalse);
    expect(fake.sleepCalls, [(DateTime(2026, 9, 29), now)]);
  });

  test('睡眠: 失敗 → MetricFailed', () async {
    fake.sleepError = HealthErrorKind.readFailed;
    final result = await service.loadSleep(service.currentRange());
    expect(
      (result as MetricFailed<DailySleep>).kind,
      HealthErrorKind.readFailed,
    );
  });

  test('currentRange(dayCount: 30)', () {
    final r = service.currentRange(dayCount: 30);
    expect(r.days.length, 30);
    expect(r.oldestDay, DateTime(2026, 9, 7));
    expect(clockCalls, 1);
  });

  test('歩数: 30 日分', () async {
    final result = await service.loadSteps(service.currentRange(dayCount: 30));
    final days = (result as MetricLoaded<DailySteps>).days;
    expect(days.length, 30);
    expect(days[0].isToday, isTrue);
    expect(days[29].date, DateTime(2026, 9, 7));
    expect(fake.stepsCalls.length, 30);
    expect(
      fake.stepsCalls,
      containsAll([
        (DateTime(2026, 9, 7), DateTime(2026, 9, 8)),
        (DateTime(2026, 10, 6), now),
      ]),
    );
  });

  test('睡眠: 30 日分の読み取り区間', () async {
    final result = await service.loadSleep(service.currentRange(dayCount: 30));
    expect((result as MetricLoaded<DailySleep>).days.length, 30);
    expect(fake.sleepCalls, [(DateTime(2026, 9, 6), now)]);
  });

  test('時計は 1 回しか読まれない', () async {
    final r = service.currentRange();
    await service.loadSteps(r);
    await service.loadSleep(r);
    expect(clockCalls, 1);
  });
}
