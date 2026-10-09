/// ダッシュボードの表示期間(機能設計書「DisplayPeriod」)。
enum DisplayPeriod {
  /// 直近 7 日。起動時の既定。
  week(7),

  /// 直近 30 日。
  month(30);

  const DisplayPeriod(this.dayCount);

  /// 今日を含む日数。
  final int dayCount;
}
