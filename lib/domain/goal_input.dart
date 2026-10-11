/// 歩数の目標の下限・上限(両端を含む)。
const minStepsGoal = 1000;
const maxStepsGoal = 100000;

/// 睡眠時間の目標の下限・上限(分。両端を含む)。
const minSleepGoalMinutes = 180;
const maxSleepGoalMinutes = 720;

const _notNumberError = '数字で入力してください';
final _digitsOnly = RegExp(r'^[0-9]+$');

/// 入力の正規化: 前後の空白を除き、全角数字を半角に変換し、カンマを取り除く。
String _normalize(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else if (rune == 0x2C || rune == 0xFF0C) {
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// 歩数の入力を解析する。空なら目標なし(value も error も null)。
({int? value, String? error}) parseStepsGoal(String input) {
  final text = _normalize(input);
  if (text.isEmpty) return (value: null, error: null);
  if (!_digitsOnly.hasMatch(text)) {
    return (value: null, error: _notNumberError);
  }
  final value = int.tryParse(text);
  if (value == null || value < minStepsGoal || value > maxStepsGoal) {
    return (value: null, error: '1,000〜100,000 歩の範囲で入力してください');
  }
  return (value: value, error: null);
}

/// 睡眠時間の入力(時間・分)を解析する。minutes は合計分。
({int? minutes, String? hoursError, String? minutesError}) parseSleepGoal(
  String hours,
  String minutes,
) {
  final h = _normalize(hours);
  final m = _normalize(minutes);
  if (h.isEmpty && m.isEmpty) {
    return (minutes: null, hoursError: null, minutesError: null);
  }
  final hoursInvalid = h.isNotEmpty && !_digitsOnly.hasMatch(h);
  final minutesInvalid = m.isNotEmpty && !_digitsOnly.hasMatch(m);
  if (hoursInvalid || minutesInvalid) {
    return (
      minutes: null,
      hoursError: hoursInvalid ? _notNumberError : null,
      minutesError: minutesInvalid ? _notNumberError : null,
    );
  }
  if (h.isEmpty) {
    return (minutes: null, hoursError: '時間を入力してください', minutesError: null);
  }
  final minutePart = m.isEmpty ? 0 : int.tryParse(m);
  if (minutePart == null || minutePart >= 60) {
    return (minutes: null, hoursError: null, minutesError: '0〜59 分で入力してください');
  }
  final hourPart = int.tryParse(h);
  final total = hourPart == null ? null : hourPart * 60 + minutePart;
  if (total == null ||
      total < minSleepGoalMinutes ||
      total > maxSleepGoalMinutes) {
    return (
      minutes: null,
      hoursError: '3〜12 時間の範囲で入力してください',
      minutesError: null,
    );
  }
  return (minutes: total, hoursError: null, minutesError: null);
}
