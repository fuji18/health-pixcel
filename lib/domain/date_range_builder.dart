import 'package:health_pixcel/domain/models/date_range.dart';

/// [now] を含む直近 [dayCount] 日の範囲を返す。
///
/// [now] はローカル時刻に変換して保持する。日付はすべてローカルの 00:00。
DateRange buildDateRange(DateTime now, {int dayCount = 7}) {
  assert(dayCount > 0, 'dayCount は 1 以上');
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  // 日の減算は DateTime(y, m, d - i) で行う(Duration の減算は夏時間で 00:00 からずれる。機能設計書 A1)
  final days = List<DateTime>.unmodifiable([
    for (var i = 0; i < dayCount; i++)
      DateTime(today.year, today.month, today.day - i),
  ]);
  return DateRange(now: local, today: today, days: days);
}

/// [day] の翌日 00:00(ローカル)。読み取り区間 `[day, nextDay(day))` の終端に使う。
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
