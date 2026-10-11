import 'package:health_pixcel/data/goal_repository.dart';
import 'package:health_pixcel/domain/models/goals.dart';

class FakeGoalRepository implements GoalRepository {
  Goals stored = const Goals();
  Exception? loadError;
  Exception? saveError;
  Goals? saved;
  int saveCalls = 0;

  @override
  Future<Goals> load() async {
    final error = loadError;
    if (error != null) throw error;
    return stored;
  }

  @override
  Future<void> save(Goals goals) async {
    saveCalls++;
    final error = saveError;
    if (error != null) throw error;
    saved = goals;
    stored = goals;
  }
}
