import 'package:health_pixcel/domain/models/goals.dart';

/// 目標値の保存先(データ層の抽象)。上位層はこの型にだけ依存する。
abstract interface class GoalRepository {
  /// 保存済みの目標値。未保存の項目は null。失敗時は [GoalStorageException] を投げる。
  Future<Goals> load();

  /// 目標値を保存する。null の項目は保存済みの値を削除する。
  /// 失敗時は [GoalStorageException] を投げる。
  Future<void> save(Goals goals);
}

/// 目標値の読み書きの失敗。元の例外の内容は持たない。
class GoalStorageException implements Exception {
  const GoalStorageException();
}
