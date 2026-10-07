# 設計: ドメイン層(日付範囲・睡眠の帰属・表示フォーマット)(#5)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/functional-design.md`「データモデル定義」「アルゴリズム設計」A1・A3・A4。本ファイルはそれを実装可能な粒度に落としたもので、**食い違ったら本ファイルを優先**する(差分は §0)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- コミットはしない(司令塔が行う)
- 変更してよいのは `lib/domain/` と `test/domain/` の新規ファイル、および本 steering の `tasklist.md` だけ。`pubspec.yaml` / `lib/main.dart` / `docs/` / `scripts/` は変更しない(`intl` は導入済み)
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)

## 0. docs から決めた点(設計判断の記録)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| `==` / `hashCode` | **どのモデルにも実装しない** | 要件に無い。重複除去は `(start, end)` の record をキーにする(A3)。テストは個々のフィールドか同一インスタンスで比較する |
| リストの不変性 | コンストラクタではコピーしない(`const` コンストラクタを保つ)。**生成関数側**(`buildDateRange` / `assignSleepToDays`)が `List.unmodifiable(...)` で包んで渡す | 「ドメインモデルは不変」を、生成経路で担保する |
| `DateRange.oldestDay` | `days.last` を返す getter | `days` は新しい順なので末尾が最古 |
| `HealthErrorKind` の置き場 | `health_status.dart`(enum 4 つを同居) | `docs/repository-structure.md` の配置どおり。`metric_result.dart` がこれを import する |
| フォーマット関数の名前・引数 | §5 の 5 関数 | docs は形式だけを定めているため |
| 時間の端数 | `Duration.inMinutes`(秒は切り捨て)。0 分は `0分` | 「1 時間未満は `m分`」の規則をそのまま適用 |
| 歩数の区切り | `NumberFormat('#,##0', 'ja')` | ロケールデータの初期化が不要で、`8,432` を確実に出す |
| `initializeDateFormatting('ja')` | 本チケットでは **`main()` に入れない**(#8 で入れる)。テストの `setUpAll` でのみ呼ぶ | フォーマット関数を画面で使い始めるのは #8。スコープ外 |

## 1. ファイル一覧

```
lib/domain/
├── models/
│   ├── date_range.dart
│   ├── daily_steps.dart
│   ├── sleep_session.dart
│   ├── daily_sleep.dart
│   ├── metric_result.dart
│   └── health_status.dart
├── date_range_builder.dart
├── sleep_assignment.dart
└── formatters.dart

test/domain/
├── models/daily_sleep_test.dart
├── date_range_builder_test.dart
├── sleep_assignment_test.dart
└── formatters_test.dart
```

### 共通の作法

- import はすべて**パッケージ import**(`package:health_pixcel/domain/...`)。相対 import 禁止(lint `always_use_package_imports`)
- `lib/domain/` で import してよいのは `package:intl/...` と `package:health_pixcel/domain/...` だけ。`dart:core` 以外の `dart:` ライブラリも不要
- **`toString()` を実装しない**(`scripts/check-privacy.sh` が検出する)。`print` / `debugPrint` / `log` も使わない
- フィールドはすべて `final`、コンストラクタは `const`。`dynamic` と `!` は使わない
- 公開クラス・関数・getter には `///` コメント(何を返すか・null の意味・前提)を書く。インラインコメントは「なぜ」と機能設計書の節番号

## 2. モデル(`lib/domain/models/`)

### 2.1 `date_range.dart`

```dart
/// 直近 7 日(今日を含む)の範囲。日付はローカルタイムゾーンの 00:00。
///
/// [buildDateRange] で生成する(機能設計書 A1)。
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
```

### 2.2 `daily_steps.dart`

```dart
class DailySteps {
  const DailySteps({required this.date, required this.steps, required this.isToday});
  final DateTime date;   // 対象日の 00:00(ローカル)
  final int? steps;      // その日の歩数合計。null = 記録なし(0 も null にするのは A2 の責務。ここでは検査しない)
  final bool isToday;    // true = 表示時点までの途中値
}
```
(コメントは `///` のフィールド doc にする)

### 2.3 `sleep_session.dart`

```dart
class SleepSession {
  const SleepSession({required this.start, required this.end});
  final DateTime start;  // 就寝時刻(ローカル)
  final DateTime end;    // 起床時刻(ローカル)。start より後(満たさないものは #6 のデータ層で破棄する)
  Duration get duration => end.difference(start);
}
```

### 2.4 `daily_sleep.dart`

```dart
class DailySleep {
  const DailySleep({required this.date, required this.sessions});
  final DateTime date;                 // 帰属日(起床日)の 00:00(ローカル)
  final List<SleepSession> sessions;   // 就寝時刻の昇順。空 = 記録なし
  bool get hasRecord => sessions.isNotEmpty;
  /// sessions の duration の合計。空なら Duration.zero
  Duration get total => sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
}
```

### 2.5 `health_status.dart`

機能設計書「取得結果と権限状態」の enum 4 つを、値・順序・コメントとも原文どおりに書く:

- `PermissionStatus { granted, denied }`
- `HealthAvailability { available, notInstalled, updateRequired }`
- `LaunchAction { normal, permissionRationale }`
- `HealthErrorKind { unavailable, readFailed }`

### 2.6 `metric_result.dart`

```dart
import 'package:health_pixcel/domain/models/health_status.dart';

/// 1 データ種別ぶんの取得結果。
sealed class MetricResult<T> {
  const MetricResult();
}

/// 取得できた。[days] は 7 件、新しい順。
class MetricLoaded<T> extends MetricResult<T> {
  const MetricLoaded(this.days);
  final List<T> days;
}

/// 権限が許可されていない。
class MetricPermissionDenied<T> extends MetricResult<T> {
  const MetricPermissionDenied();
}

/// 読み取りに失敗した。
class MetricFailed<T> extends MetricResult<T> {
  const MetricFailed(this.kind);
  final HealthErrorKind kind;
}
```

## 3. `lib/domain/date_range_builder.dart`(A1)

```dart
/// [now] を含む直近 7 日の範囲を返す。
///
/// [now] はローカル時刻に変換して保持する。日付はすべてローカルの 00:00。
DateRange buildDateRange(DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  // 日の減算は DateTime(y, m, d - i) で行う(Duration の減算は夏時間で 00:00 からずれる。機能設計書 A1)
  final days = List<DateTime>.unmodifiable([
    for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day - i),
  ]);
  return DateRange(now: local, today: today, days: days);
}

/// [day] の翌日 00:00(ローカル)。読み取り区間 `[day, nextDay(day))` の終端に使う。
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
```

## 4. `lib/domain/sleep_assignment.dart`(A3)

```dart
/// [sessions] を起床日(end のローカル日付)ごとに振り分け、[range] の 7 日分を新しい順で返す。
///
/// - range に含まれない日に起床したセッションは捨てる
/// - 同一の start / end を持つセッションは 1 件にまとめる(書き込み元の重複対策)
/// - 各日のセッションは start の昇順。セッションがない日は空リスト
List<DailySleep> assignSleepToDays(DateRange range, List<SleepSession> sessions) {
  final unique = {for (final s in sessions) (s.start, s.end): s}.values;
  final byDay = <DateTime, List<SleepSession>>{};
  for (final s in unique) {
    final end = s.end.toLocal();
    final day = DateTime(end.year, end.month, end.day);
    byDay.putIfAbsent(day, () => []).add(s);
  }
  return List<DailySleep>.unmodifiable([
    for (final d in range.days)
      DailySleep(
        date: d,
        sessions: List<SleepSession>.unmodifiable(
          [...?byDay[d]]..sort((a, b) => a.start.compareTo(b.start)),
        ),
      ),
  ]);
}
```

- 重複判定の `(s.start, s.end)` は record。`DateTime` の `==` は瞬間と `isUtc` で比較される(すべてローカルなので問題ない)
- 「range に含まれない日を捨てる」は、`range.days` だけをループすることで実現している(別途フィルタ不要)

## 5. `lib/domain/formatters.dart`(A4)

`import 'package:intl/intl.dart';` を使う。**日付・時刻の関数は事前に `initializeDateFormatting('ja')` が必要**(未初期化だと `intl` が例外を投げる)ことを doc コメントに書く。

| 関数 | 実装 | 例 |
| --- | --- | --- |
| `String formatDate(DateTime date)` | `DateFormat('M/d(E)', 'ja').format(date)` | `10/6(火)` |
| `String formatDayLabel(DateTime date, {required DateTime today})` | `date` が `today` と同日なら `'今日 ${formatDate(date)}'`、`DateTime(today.year, today.month, today.day - 1)` と同日なら `'昨日 ${formatDate(date)}'`、それ以外は `formatDate(date)` | `今日 10/6(火)` / `昨日 10/5(月)` / `10/4(日)` |
| `String formatSteps(int steps)` | `'${NumberFormat('#,##0', 'ja').format(steps)} 歩'` | `8,432 歩` |
| `String formatTime(DateTime time)` | `DateFormat('HH:mm', 'ja').format(time)` | `23:45` / `06:57` |
| `String formatDuration(Duration duration)` | `final minutes = duration.inMinutes; final h = minutes ~/ 60; final m = minutes % 60;` → `h == 0` なら `'$m分'`、`m == 0` なら `'$h時間'`、それ以外 `'$h時間$m分'` | `7時間12分` / `45分` / `8時間` / `0分` |

- 「同日」は年・月・日の一致で判定する private 関数 `bool _isSameDay(DateTime a, DateTime b)` を置く(`date` / `today` が 00:00 でなくても動くように)
- 括弧 `(` `)`・スペースはすべて**半角**。区切りは `,`(半角)
- `formatDuration` は負の値を想定しない(`SleepSession` は end > start が保証される)。doc コメントにその旨を書く

## 6. テスト(`test/domain/`)

作法: テスト名は日本語で「条件 → 期待結果」、Arrange / Act / Assert を空行で区切る、`group` は関数名単位。数値は架空。`import 'package:flutter_test/flutter_test.dart';` を使う(テストからの flutter_test 依存はレイヤー検査の対象外)。

### 6.1 `date_range_builder_test.dart`

`group('buildDateRange')`:

| テスト | 入力 `now` | 期待 |
| --- | --- | --- |
| 通常日 → 今日から 6 日前まで新しい順 | `DateTime(2026, 10, 6, 9, 30)` | `today == DateTime(2026,10,6)`、`days == [10/6, 10/5, 10/4, 10/3, 10/2, 10/1, 9/30]`(すべて 2026 年)、`oldestDay == DateTime(2026, 9, 30)` |
| 月またぎ → 前月の日付が入る | `DateTime(2026, 10, 3, 12)` | `days == [10/3, 10/2, 10/1, 9/30, 9/29, 9/28, 9/27]` |
| 年またぎ → 前年の日付が入る | `DateTime(2026, 1, 3, 12)` | `days == [2026-01-03, 01-02, 01-01, 2025-12-31, 12-30, 12-29, 12-28]` |
| 23:59 → 今日は同じ日 | `DateTime(2026, 10, 6, 23, 59, 59)` | `today == DateTime(2026, 10, 6)`、`days.first == DateTime(2026, 10, 6)` |
| 全日が 00:00 | 上記 4 入力すべて(ループ) | `days.length == 7`、各要素の `hour/minute/second/millisecond/microsecond` がすべて 0 |
| `now` が保持される | `DateTime(2026, 10, 6, 23, 59, 59)` | `range.now == 入力` |

`days` の比較は `expect(range.days, [DateTime(...), ...])`(`DateTime` の `==` で比較される)。

`group('nextDay')`: `DateTime(2026, 10, 6)` → `DateTime(2026, 10, 7)` / `DateTime(2026, 10, 31)` → `DateTime(2026, 11, 1)` / `DateTime(2026, 12, 31)` → `DateTime(2027, 1, 1)`。

### 6.2 `sleep_assignment_test.dart`

共通: `final range = buildDateRange(DateTime(2026, 10, 6, 9));`(days = 10/6 … 9/30)

| テスト | セッション | 期待 |
| --- | --- | --- |
| 日付をまたぐ睡眠 → 起床日に入る | 10/5 23:30 → 10/6 06:30 | `result[0].date == 10/6`、`result[0].sessions == [session]`(同一インスタンス)、`result[1].hasRecord == false` |
| 起床がちょうど 00:00 → その日に入る | 10/5 22:00 → 10/6 00:00 | `result[0].sessions.length == 1` |
| 最古日に起床 → 最古日に入る | 9/29 23:00 → 9/30 06:00 | `result[6].date == 9/30`、`result[6].sessions.length == 1` |
| 最古日より前に起床 → 除外される | 9/28 23:00 → 9/29 06:00 | 7 日とも `hasRecord == false` |
| 同日 2 件(夜 + 昼寝)→ 就寝時刻の昇順 | 昼寝 10/5 13:00 → 13:40 と 夜 10/4 23:00 → 10/5 06:00 を**この順(逆順)で**渡す | `result[1].sessions == [夜, 昼寝]` |
| 重複(同一 start / end の別インスタンス)→ 1 件 | 10/5 23:00 → 10/6 06:00 を 2 インスタンス | `result[0].sessions.length == 1` |
| セッションなし → 7 日分の空リスト | `[]` | `result.length == 7`、`result.map((d) => d.date)` が `range.days` と一致、全日 `sessions` が空 |

リストの比較 `expect(list, [a, b])` は要素の `==`(= 同一性)で比較される。モデルに `==` は無いので、期待値には**渡したのと同じインスタンス**を使う。

### 6.3 `models/daily_sleep_test.dart`

- `total` → 各セッションの duration の合計(7h + 40m = 7h40m)
- セッションが空 → `total == Duration.zero`、`hasRecord == false`

### 6.4 `formatters_test.dart`

`setUpAll(() => initializeDateFormatting('ja'));`(`import 'package:intl/date_symbol_data_local.dart';`)

| 関数 | 入力 | 期待 |
| --- | --- | --- |
| `formatDayLabel` | `DateTime(2026,10,6)`, today: `DateTime(2026,10,6)` | `今日 10/6(火)` |
| 〃 | `DateTime(2026,10,5)`, today 同上 | `昨日 10/5(月)` |
| 〃 | `DateTime(2026,10,4)`, today 同上 | `10/4(日)` |
| 〃 | `DateTime(2026,1,1)`(木), today: `DateTime(2026,1,2)` | `昨日 1/1(木)`(年またぎでなく月初の昨日判定) |
| `formatSteps` | `8432` / `1` / `12345678` | `8,432 歩` / `1 歩` / `12,345,678 歩` |
| `formatTime` | `DateTime(2026,10,5,23,45)` / `DateTime(2026,10,6,6,57)` | `23:45` / `06:57` |
| `formatDuration` | 7h12m / 45m / 8h / 7h12m59s / zero | `7時間12分` / `45分` / `8時間` / `7時間12分` / `0分` |

曜日の確認済み: 2026-10-04 = 日、10-05 = 月、10-06 = 火、2026-01-01 = 木。

## 7. 完了条件(実装者が自分で回す)

```bash
cd /workspaces/health-pixcel
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
```

すべて exit 0 で完了。format で差分が出たら `dart format lib test` で整形してよい。

## 8. 検収指摘の対応(code-reviewer 1 巡目)

テストだけを追加する。`lib/` は変更しない。

### 8.1 不変性のテスト(§0「リストの不変性」の担保)

- `date_range_builder_test.dart` の `group('buildDateRange')` に追加: `days を変更しようとする → UnsupportedError`。`expect(() => range.days.add(DateTime(2026, 10, 7)), throwsUnsupportedError);`
- `sleep_assignment_test.dart` に追加: `戻り値と各日の sessions を変更しようとする → UnsupportedError`。セッション 1 件(10/5 23:30 → 10/6 06:30)で呼び、`expect(() => result.add(result.first), throwsUnsupportedError);` と `expect(() => result.first.sessions.add(session), throwsUnsupportedError);`

### 8.2 未来日の除外

- `sleep_assignment_test.dart` に追加: `今日より後に起床 → 除外される`。セッション 10/6 23:00 → 10/7 06:00(range は §6.2 共通のもの)。期待: 7 日とも `hasRecord == false`

### 8.3 採らない指摘

- 重複キーの `isUtc` 差・`start` を `toLocal()` しない非対称: データ層(#6)が全 `DateTime` を `toLocal()` してから渡す規約(development-guidelines「型とモデル」)で担保する。#6 の design に申し送る
