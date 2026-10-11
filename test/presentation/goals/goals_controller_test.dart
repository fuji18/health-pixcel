import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/data/goal_repository.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:health_pixcel/presentation/goals/goals_controller.dart';
import 'package:health_pixcel/presentation/providers.dart';

import '../../fakes/fake_goal_repository.dart';

ProviderContainer makeContainer(FakeGoalRepository fake) {
  final container = ProviderContainer(
    overrides: [goalRepositoryProvider.overrideWithValue(fake)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(goalsControllerProvider, (_, _) {});
  return container;
}

void main() {
  test('読み込み成功', () async {
    final fake = FakeGoalRepository()
      ..stored = const Goals(steps: 8000, sleepMinutes: 450);
    final container = makeContainer(fake);
    expect(
      await container.read(goalsControllerProvider.future),
      const Goals(steps: 8000, sleepMinutes: 450),
    );
  });

  test('読み込み失敗は目標なし', () async {
    final fake = FakeGoalRepository()..loadError = const GoalStorageException();
    final container = makeContainer(fake);
    expect(await container.read(goalsControllerProvider.future), const Goals());
  });

  test('保存成功で状態が置き換わる', () async {
    final fake = FakeGoalRepository();
    final container = makeContainer(fake);
    await container.read(goalsControllerProvider.future);
    final ok = await container
        .read(goalsControllerProvider.notifier)
        .save(const Goals(steps: 5000));
    expect(ok, isTrue);
    expect(
      container.read(goalsControllerProvider).value,
      const Goals(steps: 5000),
    );
  });

  test('保存失敗は false で状態不変', () async {
    final fake = FakeGoalRepository()..saveError = const GoalStorageException();
    final container = makeContainer(fake);
    await container.read(goalsControllerProvider.future);
    final ok = await container
        .read(goalsControllerProvider.notifier)
        .save(const Goals(steps: 5000));
    expect(ok, isFalse);
    expect(container.read(goalsControllerProvider).value, const Goals());
  });
}
