/// 直近 7 日(今日を含む)の範囲。日付はローカルタイムゾーンの 00:00。
///
/// `buildDateRange` で生成する(機能設計書 A1)。
class DateRange {
  const DateRange({required this.now, required this.today, required this.days});

  /// 範囲を決めた時点の現在時刻(ローカル)。今日の読み取りの終端に使う。
  final DateTime now;

  /// 今日の 00:00(ローカル)。
  final DateTime today;

  /// 新しい順の 7 日分 `[today, today-1, ..., today-6]`。
  final List<DateTime> days;

  /// 最古の日(today - 6 日)。
  DateTime get oldestDay => days.last;
}
