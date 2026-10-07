import 'package:health_pixcel/domain/models/health_status.dart';

/// 1 データ種別ぶんの取得結果。
sealed class MetricResult<T> {
  const MetricResult();
}

/// 取得できた。[days] は 7 件、新しい順。
class MetricLoaded<T> extends MetricResult<T> {
  const MetricLoaded(this.days);

  /// 取得した日別データ。
  final List<T> days;
}

/// 権限が許可されていない。
class MetricPermissionDenied<T> extends MetricResult<T> {
  const MetricPermissionDenied();
}

/// 読み取りに失敗した。
class MetricFailed<T> extends MetricResult<T> {
  const MetricFailed(this.kind);

  /// 失敗の種類。
  final HealthErrorKind kind;
}
