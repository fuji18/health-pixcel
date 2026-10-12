/// 読み取るデータの種別(権限はこの単位で扱う)。
enum HealthMetric { steps, sleep, heartRate, weight }

/// データ種別ごとの権限状態(許可済みの種別の集合)。値で比較できる。
class HealthPermissions {
  /// [granted] は許可済みの種別。
  const HealthPermissions(this.granted);

  /// 許可済みの種別。
  final Set<HealthMetric> granted;

  /// [metric] が許可済みか。
  bool isGranted(HealthMetric metric) => granted.contains(metric);

  /// どの種別も許可されていないか。
  bool get noneGranted => granted.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is HealthPermissions &&
      other.granted.length == granted.length &&
      other.granted.containsAll(granted);

  @override
  int get hashCode => Object.hashAllUnordered(granted);
}

/// ヘルスコネクト自体の利用可否。
enum HealthAvailability {
  /// 利用可能。
  available,

  /// 利用不可(minSdk 34 では OS 統合のため通常は起こらない。防御的に扱う)。
  notInstalled,

  /// ヘルスコネクトの更新が必要。
  updateRequired,
}

/// アプリの起動理由(起動インテントの action から決まる)。
enum LaunchAction {
  /// ランチャー等からの通常起動。
  normal,

  /// ヘルスコネクトの権限画面から「利用目的」を開いた。
  permissionRationale,
}

/// 読み取り失敗の種類。
enum HealthErrorKind { unavailable, readFailed }
