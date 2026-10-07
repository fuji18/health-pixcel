/// 歩数・睡眠それぞれの権限状態。
enum PermissionStatus { granted, denied }

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
