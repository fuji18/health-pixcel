import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/data/goal_repository.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:health_pixcel/presentation/providers.dart';

/// 目標値の状態。build() で読み込み、save() で保存して状態を置き換える。
final goalsControllerProvider = AsyncNotifierProvider<GoalsController, Goals>(
  GoalsController.new,
);

class GoalsController extends AsyncNotifier<Goals> {
  @override
  Future<Goals> build() async {
    try {
      return await ref.read(goalRepositoryProvider).load();
    } on GoalStorageException {
      return const Goals(); // 読めないときは目標なしとして扱う
    }
  }

  /// 保存する。成功なら true、GoalStorageException なら false(状態は変えない)。
  Future<bool> save(Goals goals) async {
    try {
      await ref.read(goalRepositoryProvider).save(goals);
    } on GoalStorageException {
      return false;
    }
    state = AsyncData(goals);
    return true;
  }
}
