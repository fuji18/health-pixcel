import 'package:intl/intl.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 日付を `10/6(火)` 形式にする。
///
/// 事前に `initializeDateFormatting('ja')` が必要(未初期化だと intl が例外を投げる)。
String formatDate(DateTime date) => DateFormat('M/d(E)', 'ja').format(date);

/// 日付ラベル。[today] と同日なら `今日 10/6(火)`、前日なら `昨日 10/5(月)`、それ以外は `10/4(日)`。
///
/// 事前に `initializeDateFormatting('ja')` が必要。
String formatDayLabel(DateTime date, {required DateTime today}) {
  if (_isSameDay(date, today)) return '今日 ${formatDate(date)}';
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (_isSameDay(date, yesterday)) return '昨日 ${formatDate(date)}';
  return formatDate(date);
}

/// 歩数を `8,432 歩` 形式にする(3 桁区切りは半角 `,`)。
String formatSteps(int steps) =>
    '${NumberFormat('#,##0', 'ja').format(steps)} 歩';

/// 時刻を `23:45` 形式(24 時間・ゼロ埋め)にする。
///
/// 事前に `initializeDateFormatting('ja')` が必要。
String formatTime(DateTime time) => DateFormat('HH:mm', 'ja').format(time);

/// 時間の長さを `7時間12分` / `45分` / `8時間` 形式にする。秒は切り捨て。
///
/// 負の値は想定しない(SleepSession は end > start が保証される)。
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m分';
  if (m == 0) return '$h時間';
  return '$h時間$m分';
}
