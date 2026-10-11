import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/data/shared_preferences_goal_repository.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('未保存なら目標なし', () async {
    expect(await SharedPreferencesGoalRepository().load(), const Goals());
  });

  test('保存した値を新しいインスタンスで読める', () async {
    await SharedPreferencesGoalRepository().save(
      const Goals(steps: 8000, sleepMinutes: 450),
    );
    expect(
      await SharedPreferencesGoalRepository().load(),
      const Goals(steps: 8000, sleepMinutes: 450),
    );
  });

  test('null で保存すると削除される', () async {
    final repo = SharedPreferencesGoalRepository();
    await repo.save(const Goals(steps: 8000, sleepMinutes: 450));
    await repo.save(const Goals());
    expect(await SharedPreferencesGoalRepository().load(), const Goals());
  });

  test('片方だけ保存できる', () async {
    await SharedPreferencesGoalRepository().save(const Goals(steps: 5000));
    expect(
      await SharedPreferencesGoalRepository().load(),
      const Goals(steps: 5000),
    );
  });

  test('範囲外の保存値は null として扱う', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'goal.steps': 5,
          'goal.sleep_minutes': 5000,
        });
    expect(await SharedPreferencesGoalRepository().load(), const Goals());
  });
}
