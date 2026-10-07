# 設計: アプリ層・状態管理(#7)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/functional-design.md`「WeeklySummaryService」「DashboardController」「エンティティ: DashboardState」と `docs/architecture.md`「状態管理(Riverpod)」。**食い違ったら本ファイルを優先**する(差分は §0)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- `docs/` は変更しない(司令塔が行う)。コミットはしない(司令塔が行う)
- 新規作成してよいのは次の 8 ファイルだけ。ほかに変更してよいのは本 steering の `tasklist.md` のみ。`pubspec.yaml`(`flutter_riverpod: ^3.4.3` は導入済み)/ `lib/domain/` / `lib/data/` / `lib/main.dart` / `lib/app.dart` / `scripts/` は変更しない
  - `lib/application/weekly_summary_service.dart`
  - `lib/presentation/providers.dart`
  - `lib/presentation/dashboard/dashboard_state.dart`
  - `lib/presentation/dashboard/dashboard_controller.dart`
  - `test/fakes/fake_health_repository.dart`
  - `test/application/weekly_summary_service_test.dart`
  - `test/presentation/dashboard/dashboard_state_test.dart`
  - `test/presentation/dashboard/dashboard_controller_test.dart`
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)。Riverpod 3.4.3 のソースは `~/.pub-cache/hosted/pub.dev/riverpod-3.4.3/` にある
- import はすべて `package:health_pixcel/...`(相対 import 禁止)。健康データの値を `print` / `debugPrint` / `log` に渡さない。`toString()` を実装しない
- 各公開要素に 1 行の `///` doc コメントを付ける(既存の `lib/domain/` に合わせる)

## 0. 設計判断の記録(司令塔が決定済み)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| `openSettings()` / `openStore()` | **`Future<bool>` を返す**(リポジトリの戻り値をそのまま返す。例外は `false`)。スナックバーは画面(#8)が戻り値を見て出す | コントローラーは `BuildContext` / `ScaffoldMessenger` を持たない。docs も更新する |
| `requestPermissions()` の `AsyncLoading` | `state = const AsyncLoading<DashboardState>()` を代入する。Riverpod 3 はこれを自動で `copyWithPrevious` するため**前回の値は残る**が、`isLoading == true` になり、`when()` の既定(`skipLoadingOnReload: false`)ではローディング表示になる。テストは `isLoading` だけを見る(`hasValue` は見ない) | Riverpod 3.4.3 の `asyncTransition` の仕様(ソースで確認) |
| 破棄後の状態更新 | `await` の後に `state` を代入する前には必ず `if (!ref.mounted) return;` を置く | 破棄後の代入は例外になる |
| 歩数 `0` | サービスでも `0` を `null`(記録なし)として扱う | 機能設計書のテスト戦略「歩数の `null`/`0` → 記録なし」。リポジトリが変換済みでも防御的に重ねる |
| `HealthReadException` 以外の例外 | `WeeklySummaryService` は捕捉しない(そのまま外に出す)。`DashboardController._fetch()` の最上位で捕捉する | 想定外の例外は `_fetch()` 手順 7 の扱い |
| Riverpod 3 の自動リトライ | `main.dart` は変更しない。`_fetch()` が例外を外に出さないため `build()` は失敗せず、リトライは走らない。テスト(§7 の「想定外の例外」)で `hasError == false` を確認する | architecture.md「Riverpod 3 の既定動作の確認」の確認事項 |
| フェイク | `test/fakes/fake_health_repository.dart` に置く(#8 のウィジェットテストでも使う) | `docs/repository-structure.md` の配置 |

## 1. `lib/application/weekly_summary_service.dart`

import: `health_repository.dart`(data)、`domain/date_range_builder.dart`、`domain/sleep_assignment.dart`、`domain/models/{date_range,daily_steps,daily_sleep,metric_result}.dart`。**`flutter` / `flutter_riverpod` は import しない。**

```dart
/// 直近 7 日の歩数・睡眠を組み立てる(機能設計書「WeeklySummaryService」)。
class WeeklySummaryService {
  WeeklySummaryService(this._repository, this._clock);

  final HealthRepository _repository;
  final DateTime Function() _clock;

  /// 時計を 1 回だけ読んで [DateRange] を作る。
  DateRange currentRange() => buildDateRange(_clock());

  /// 7 日分の歩数。1 日でも [HealthReadException] が出たら [MetricFailed]。
  Future<MetricResult<DailySteps>> loadSteps(DateRange range) async {
    try {
      final values = await Future.wait([
        for (var i = 0; i < range.days.length; i++)
          _repository.readTotalSteps(
            range.days[i],
            i == 0 ? range.now : nextDay(range.days[i]),
          ),
      ]);
      return MetricLoaded(List<DailySteps>.unmodifiable([
        for (var i = 0; i < range.days.length; i++)
          DailySteps(
            date: range.days[i],
            steps: values[i] == 0 ? null : values[i],
            isToday: i == 0,
          ),
      ]));
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }

  /// 7 日分の睡眠。読み取り区間は [range.oldestDay - 1 日, range.now](機能設計書 A3)。
  Future<MetricResult<DailySleep>> loadSleep(DateRange range) async {
    final oldest = range.oldestDay;
    try {
      final sessions = await _repository.readSleepSessions(
        DateTime(oldest.year, oldest.month, oldest.day - 1),
        range.now,
      );
      return MetricLoaded(assignSleepToDays(range, sessions));
    } on HealthReadException catch (e) {
      return MetricFailed(e.kind);
    }
  }
}
```

- `range.days[0]` が今日。今日の終端は `range.now`、それ以外は `nextDay(d)`。時計は `currentRange()` でしか読まない
- `Future.wait` は全件の完了を待ってから最初のエラーを投げる(既定の `eagerError: false`)。それで良い

## 2. `lib/presentation/providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/application/weekly_summary_service.dart';
import 'package:health_pixcel/data/health_connect_repository.dart';
import 'package:health_pixcel/data/health_repository.dart';

/// 現在時刻。テストで固定値に差し替える。
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// ヘルスデータへのアクセス。テストでフェイクに差し替える。
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthConnectRepository(),
);

/// 直近 7 日の組み立て。
final weeklySummaryServiceProvider = Provider<WeeklySummaryService>(
  (ref) => WeeklySummaryService(
    ref.watch(healthRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
```

- `launchActionProvider` は #9 で足す。ここには書かない

## 3. `lib/presentation/dashboard/dashboard_state.dart`

```dart
/// ダッシュボードの画面状態。読み込み中は Riverpod の AsyncLoading で表す。
sealed class DashboardState {
  const DashboardState();
}

/// ヘルスコネクトが使えない(F4)。
class DashboardUnavailable extends DashboardState {
  const DashboardUnavailable(this.availability);

  /// notInstalled / updateRequired。
  final HealthAvailability availability;
}

/// 歩数・睡眠の両方が未許可(F4)。
class DashboardNeedsPermission extends DashboardState {
  const DashboardNeedsPermission();
}

/// 少なくとも片方が許可済み(F2 / F3 / F4)。
class DashboardReady extends DashboardState {
  const DashboardReady({
    required this.range,
    required this.steps,
    required this.sleep,
  });

  /// 表示する 7 日。
  final DateRange range;

  /// 歩数の取得結果。
  final MetricResult<DailySteps> steps;

  /// 睡眠の取得結果。
  final MetricResult<DailySleep> sleep;

  /// F4 のデータなし案内を出すかどうか(機能設計書「isAllEmpty の定義」)。
  bool get isAllEmpty {
    final steps = this.steps;
    final sleep = this.sleep;
    if (steps is MetricFailed || sleep is MetricFailed) return false;
    if (steps is! MetricLoaded<DailySteps> &&
        sleep is! MetricLoaded<DailySleep>) {
      return false;
    }
    final stepsEmpty = switch (steps) {
      MetricLoaded(:final days) => days.every((d) => d.steps == null),
      _ => true,
    };
    final sleepEmpty = switch (sleep) {
      MetricLoaded(:final days) => days.every((d) => !d.hasRecord),
      _ => true,
    };
    return stepsEmpty && sleepEmpty;
  }
}
```

- `==` / `hashCode` / `toString` は実装しない。`switch` の型推論で analyze が警告を出したら、パターンを `MetricLoaded<DailySteps>(:final days)` のように型引数付きにする(意味は同じ)

## 4. `lib/presentation/dashboard/dashboard_controller.dart`

import: `flutter_riverpod`、`health_pixcel/data/health_repository.dart`(抽象のみ。**`health_connect_repository.dart` は import しない**)、`presentation/providers.dart`、`presentation/dashboard/dashboard_state.dart`、`domain/models/{date_range,daily_steps,daily_sleep,health_status,metric_result}.dart`。

```dart
/// 画面状態のプロバイダー。
final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// 利用可否が available 以外のときは権限を取得しないため null。
typedef _Snapshot = ({
  HealthAvailability availability,
  ({PermissionStatus steps, PermissionStatus sleep})? permissions,
});

/// ダッシュボードの状態遷移(機能設計書「DashboardController」)。
class DashboardController extends AsyncNotifier<DashboardState> {
  Future<DashboardState>? _inFlight;
  bool _requestingPermission = false;
  _Snapshot? _lastSnapshot;

  @override
  Future<DashboardState> build() => _fetch();
  ...
}
```

依存は**各メソッド内で** `ref.read(healthRepositoryProvider)` / `ref.read(weeklySummaryServiceProvider)` で取る(`watch` しない。フィールドにも保持しない)。

### 4.1 `refresh()`

```dart
/// 前回の値を表示したまま読み直す(引っぱって更新・「再読み込み」)。
Future<void> refresh() async {
  final next = await _fetch();
  if (!ref.mounted) return;
  state = AsyncData(next);
}
```

### 4.2 `requestPermissions()`

```dart
/// 権限をリクエストし、許可後の状態で読み直す。
Future<void> requestPermissions() async {
  final repository = ref.read(healthRepositoryProvider);
  _requestingPermission = true;
  try {
    await repository.requestPermissions();
  } catch (_) {
    // 失敗しても画面はエラーにせず、権限状態を読み直して表示する
  } finally {
    _requestingPermission = false;
  }
  if (!ref.mounted) return;
  state = const AsyncLoading<DashboardState>();
  final next = await _fetch(force: true);
  if (!ref.mounted) return;
  state = AsyncData(next);
}
```

### 4.3 `onResumed()`

```dart
/// フォアグラウンド復帰時。利用可否・権限が前回と変わっていれば読み直す。
Future<void> onResumed() async {
  if (_requestingPermission) return;
  final repository = ref.read(healthRepositoryProvider);
  final _Snapshot current;
  try {
    final availability = await repository.checkAvailability();
    current = (
      availability: availability,
      permissions: availability == HealthAvailability.available
          ? await repository.checkPermissions()
          : null,
    );
  } catch (_) {
    if (!ref.mounted) return;
    await refresh();
    return;
  }
  if (!ref.mounted) return;
  if (current != _lastSnapshot) await refresh();
}
```

- レコードは値で比較される(入れ子のレコードも)。`_lastSnapshot == null` なら必ず異なる → `refresh()`

### 4.4 `openSettings()` / `openStore()`

```dart
/// ヘルスコネクトの権限設定画面を開く。開けなかったら false(画面がスナックバーを出す)。
Future<bool> openSettings() async {
  try {
    return await ref.read(healthRepositoryProvider).openPermissionSettings();
  } catch (_) {
    return false;
  }
}
```

`openStore()` も同じ形で `openHealthConnectStore()` を呼ぶ。状態は変えない。

### 4.5 `_fetch({bool force = false})`(多重実行の扱い)

```dart
Future<DashboardState> _fetch({bool force = false}) async {
  final running = _inFlight;
  if (running != null) {
    if (!force) return running;   // 合流する
    await running;                // 古い結果は捨てる(_fetchBody は例外を出さない)
  }
  late final Future<DashboardState> future;
  future = _fetchBody().whenComplete(() {
    if (identical(_inFlight, future)) _inFlight = null;
  });
  _inFlight = future;
  return future;
}
```

- `if (!force) return running;` は最初の `await` より前にあるため同期的に判定される(合流が確実に起きる)

### 4.6 `_fetchBody()`(本体。例外を外に出さない)

```dart
Future<DashboardState> _fetchBody() async {
  final repository = ref.read(healthRepositoryProvider);
  final service = ref.read(weeklySummaryServiceProvider);
  DateRange? range;
  try {
    // 1. 利用可否
    final availability = await repository.checkAvailability();
    if (availability != HealthAvailability.available) {
      _lastSnapshot = (availability: availability, permissions: null);
      return DashboardUnavailable(availability);
    }
    // 2. 権限
    final permissions = await repository.checkPermissions();
    _lastSnapshot = (
      availability: HealthAvailability.available,
      permissions: permissions,
    );
    final stepsGranted = permissions.steps == PermissionStatus.granted;
    final sleepGranted = permissions.sleep == PermissionStatus.granted;
    // 3. 両方未許可
    if (!stepsGranted && !sleepGranted) return const DashboardNeedsPermission();
    // 4. 許可済みの種別だけ並行に読む
    final r = range = service.currentRange();
    var (steps, sleep) = await (
      stepsGranted
          ? service.loadSteps(r)
          : Future.value(const MetricPermissionDenied<DailySteps>()),
      sleepGranted
          ? service.loadSleep(r)
          : Future.value(const MetricPermissionDenied<DailySleep>()),
    ).wait;
    // 5. 読み込み中の unavailable は利用可否を再確認する
    if (_isUnavailable(steps) || _isUnavailable(sleep)) {
      final again = await repository.checkAvailability();
      if (again != HealthAvailability.available) {
        _lastSnapshot = (availability: again, permissions: null);
        return DashboardUnavailable(again);
      }
      if (_isUnavailable(steps)) steps = const MetricFailed(HealthErrorKind.readFailed);
      if (_isUnavailable(sleep)) sleep = const MetricFailed(HealthErrorKind.readFailed);
    }
    // 6.
    return DashboardReady(range: r, steps: steps, sleep: sleep);
  } catch (_) {
    // 7. 想定外の例外。値をログに出さない。次の復帰で必ず読み直すため snapshot を捨てる
    _lastSnapshot = null;
    return DashboardReady(
      range: range ?? service.currentRange(),
      steps: const MetricFailed(HealthErrorKind.readFailed),
      sleep: const MetricFailed(HealthErrorKind.readFailed),
    );
  }
}

static bool _isUnavailable(MetricResult<Object?> result) =>
    result is MetricFailed && result.kind == HealthErrorKind.unavailable;
```

- `(f1, f2).wait`(Dart 3 のレコードの `wait`)は片方が失敗すると `ParallelWaitError` を投げるが、`catch (_)` で捕捉されるので良い
- `_isUnavailable` の引数型で analyze が警告するなら、`MetricResult<DailySteps>` 用と `MetricResult<DailySleep>` 用に分けず、`MetricResult<dynamic>` ではなく `Object` を受けて `result is MetricFailed && result.kind == ...` とする(`strict-raw-types` に注意。`MetricFailed<Object?>` でのパターン一致にしてもよい)
- `var (steps, sleep) = ...` の再代入で型が合わない警告が出たら、`MetricResult<DailySteps> steps` / `MetricResult<DailySleep> sleep` を明示して分割代入する

## 5. `test/fakes/fake_health_repository.dart`

本番コードから参照しない。`flutter_test` の `Fake` は使わず、`HealthRepository` を**全メソッド実装**する(#8 でも使うため)。

```dart
/// テスト用の HealthRepository。各フィールドで戻り値・失敗・待機を差し替える。
class FakeHealthRepository implements HealthRepository {
  /// checkAvailability の戻り値。availabilityQueue が空でないときはそちらを先頭から使う。
  HealthAvailability availability = HealthAvailability.available;
  final availabilityQueue = <HealthAvailability>[];
  /// 非 null なら checkAvailability がこれを投げる。
  Object? availabilityError;
  int checkAvailabilityCalls = 0;

  /// checkPermissions の戻り値。
  ({PermissionStatus steps, PermissionStatus sleep}) permissions =
      (steps: PermissionStatus.granted, sleep: PermissionStatus.granted);
  /// 非 null なら checkPermissions がこれを投げる。
  Object? permissionsError;
  /// 非 null なら checkPermissions は「呼ばれた時点の permissions」を取ってから、これの完了を待って返す。
  Completer<void>? permissionsGate;
  int checkPermissionsCalls = 0;

  /// 非 null なら requestPermissions の後に permissions をこれで置き換える。
  ({PermissionStatus steps, PermissionStatus sleep})? permissionsAfterRequest;
  /// 非 null なら requestPermissions はこれの完了を待つ(ダイアログ表示中を表す)。
  Completer<void>? requestGate;
  /// 非 null なら requestPermissions がこれを投げる(requestGate の後)。
  Object? requestError;
  int requestPermissionsCalls = 0;

  bool openSettingsResult = true;
  int openSettingsCalls = 0;
  bool openStoreResult = true;
  int openStoreCalls = 0;

  /// 日付(00:00)→ 歩数。キーが無い日は null(記録なし)。
  final steps = <DateTime, int>{};
  /// 日付(00:00)→ その日の readTotalSteps が投げる HealthReadException の種類。
  final stepsErrors = <DateTime, HealthErrorKind>{};
  final stepsCalls = <(DateTime, DateTime)>[];

  List<SleepSession> sleepSessions = [];
  /// 非 null なら readSleepSessions が HealthReadException(sleepError) を投げる。
  HealthErrorKind? sleepError;
  final sleepCalls = <(DateTime, DateTime)>[];

  /// 非 null なら readTotalSteps / readSleepSessions はこれの完了を待つ(読み込み中を表す)。
  Completer<void>? readGate;
}
```

各メソッドの実装:

| メソッド | 実装 |
| --- | --- |
| `checkAvailability` | `checkAvailabilityCalls++` → `availabilityError` が非 null なら `throw availabilityError!` → `availabilityQueue` が空でなければ `removeAt(0)` を返す、空なら `availability` |
| `checkPermissions` | `checkPermissionsCalls++` → `permissionsError` が非 null なら throw → `final p = permissions;` → `await permissionsGate?.future;` → `return p` |
| `requestPermissions` | `requestPermissionsCalls++` → `await requestGate?.future;` → `requestError` が非 null なら throw → `permissionsAfterRequest` が非 null なら `permissions` を置き換え → `return permissions` |
| `openPermissionSettings` | `openSettingsCalls++` → `return openSettingsResult` |
| `openHealthConnectStore` | `openStoreCalls++` → `return openStoreResult` |
| `readTotalSteps(start, end)` | `stepsCalls.add((start, end))` → `await readGate?.future;` → `stepsErrors[start]` が非 null なら `throw HealthReadException(kind)` → `return steps[start]` |
| `readSleepSessions(start, end)` | `sleepCalls.add((start, end))` → `await readGate?.future;` → `sleepError` が非 null なら throw → `return sleepSessions` |

`throw availabilityError!` が analyze で `only_throw_errors` 等に当たる場合は、フィールド型を `Exception?` にしてよい(テストで使うのは `StateError` ではなく `Exception('x')` とする)。

## 6. `test/application/weekly_summary_service_test.dart`

固定時刻 `final now = DateTime(2026, 10, 6, 10, 30);`。時計は呼び出し回数を数える:

```dart
var clockCalls = 0;
DateTime clock() { clockCalls++; return now; }
```

`setUp` で `fake = FakeHealthRepository(); clockCalls = 0; service = WeeklySummaryService(fake, clock);`

| テスト | 手順と期待 |
| --- | --- |
| `currentRange` が時計を 1 回読む | `final r = service.currentRange();` → `r.today == DateTime(2026,10,6)` / `r.now == now` / `clockCalls == 1` |
| 歩数: 7 日分・新しい順・今日の終端が `range.now` | `fake.steps[DateTime(2026,10,6)] = 8432; fake.steps[DateTime(2026,10,4)] = 0;` → `loadSteps(r)` が `MetricLoaded`。`days.length == 7`、`days[0].date == DateTime(2026,10,6)` / `steps == 8432` / `isToday == true`、`days[1].steps == null`(キーなし = null)/ `isToday == false`、`days[2].steps == null`(0 → 記録なし)、`days[6].date == DateTime(2026,9,30)`。`fake.stepsCalls` は 7 件で、`(DateTime(2026,10,6), now)` と `(DateTime(2026,10,5), DateTime(2026,10,6))` と `(DateTime(2026,9,30), DateTime(2026,10,1))` を含む |
| 歩数: 1 日失敗 → `MetricFailed` | `fake.stepsErrors[DateTime(2026,10,3)] = HealthErrorKind.readFailed;` → `MetricFailed` で `kind == readFailed` |
| 歩数: `unavailable` はそのまま返す | `stepsErrors[...] = unavailable` → `MetricFailed` で `kind == unavailable` |
| 睡眠: 読み取り区間と振り分け | `fake.sleepSessions = [SleepSession(start: DateTime(2026,10,5,23), end: DateTime(2026,10,6,7))];` → `MetricLoaded`。`days[0].sessions.length == 1`、`days[1].hasRecord == false`。`fake.sleepCalls == [(DateTime(2026,9,29), now)]` |
| 睡眠: 失敗 → `MetricFailed` | `fake.sleepError = readFailed` → `MetricFailed(readFailed)` |
| 時計は 1 回しか読まれない | `currentRange()` → `loadSteps(r)` → `loadSleep(r)` の後で `clockCalls == 1` |

## 7. `test/presentation/dashboard/dashboard_controller_test.dart`

### 7.1 共通の準備

```dart
final now = DateTime(2026, 10, 6, 10, 30);
const granted = PermissionStatus.granted;
const denied = PermissionStatus.denied;

late FakeHealthRepository fake;

ProviderContainer makeContainer() {
  final container = ProviderContainer.test(
    overrides: [
      healthRepositoryProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  // Riverpod 3 は購読者のいないプロバイダーを一時停止するため、常に購読しておく
  container.listen(dashboardControllerProvider, (_, _) {});
  return container;
}

/// 保留中のマイクロタスクを流す
Future<void> pump() => Future<void>.delayed(Duration.zero);
```

`setUp(() => fake = FakeHealthRepository());`。初回の読み込み完了は `await container.read(dashboardControllerProvider.future);` で待つ。コントローラーは `container.read(dashboardControllerProvider.notifier)`、状態は `container.read(dashboardControllerProvider)`。

`ProviderContainer.test` / `overrideWithValue` / `listen` のシグネチャが合わなければ `~/.pub-cache/hosted/pub.dev/riverpod-3.4.3/lib/` を読んで合わせる(意味を変えない範囲で)。

### 7.2 テストケース(すべて書く。名前は日本語でよい)

**初回の読み込み(build)**

| # | テスト | 準備 → 操作 → 期待 |
| --- | --- | --- |
| 1 | 初回は読み込み中 → 結果 | `makeContainer()` 直後の状態が `isLoading == true` → `await ...future` 後は `AsyncData` で値が `DashboardReady` |
| 2 | 利用不可 | `fake.availability = updateRequired` → 値が `DashboardUnavailable` で `availability == updateRequired`。`fake.checkPermissionsCalls == 0`、`stepsCalls` / `sleepCalls` が空 |
| 3 | 両方未許可 | `fake.permissions = (steps: denied, sleep: denied)` → `DashboardNeedsPermission`。`stepsCalls` / `sleepCalls` が空 |
| 4 | 片方未許可 | `(steps: granted, sleep: denied)` → `DashboardReady`、`steps is MetricLoaded`、`sleep is MetricPermissionDenied`、`sleepCalls` が空 |
| 5 | 読み取り失敗は片方だけ | `fake.stepsErrors[DateTime(2026,10,6)] = readFailed` → `steps` が `MetricFailed(readFailed)`、`sleep is MetricLoaded` |
| 6 | 読み込み中の `unavailable` → `DashboardUnavailable` | `fake.sleepError = unavailable; fake.availabilityQueue.addAll([available, notInstalled]);` → `DashboardUnavailable(notInstalled)` |
| 7 | 読み込み中の `unavailable` だが利用可能のまま → `readFailed` | `fake.sleepError = unavailable;`(queue なし)→ `DashboardReady`、`sleep` が `MetricFailed` で `kind == readFailed`、`steps is MetricLoaded` |
| 8 | 想定外の例外は外に出ない | `fake.availabilityError = Exception('x')` → 状態の `hasError == false`、値が `DashboardReady` で `steps` / `sleep` とも `MetricFailed(readFailed)`、`range.today == DateTime(2026,10,6)` |

**再読み込み(refresh)**

| # | テスト | 準備 → 操作 → 期待 |
| --- | --- | --- |
| 9 | `refresh()` 中に前回の値が残る | 初回完了後 `fake.readGate = Completer(); fake.steps[DateTime(2026,10,6)] = 100;` → `final f = controller.refresh(); await pump();` → 状態が `isLoading == false` で値が `DashboardReady`(前回値)→ `fake.readGate!.complete(); await f;` → 値の `steps` の `days[0].steps == 100` |
| 10 | `_fetch()` の多重呼び出しが 1 回に合流する | `fake.readGate = Completer();` → `makeContainer()`(build 開始)→ `await pump();` → `final a = controller.refresh(); final b = controller.refresh();` → `fake.readGate!.complete(); await Future.wait([a, b]);` → `fake.checkAvailabilityCalls == 1`、`fake.stepsCalls.length == 7` |

**権限リクエスト**

| # | テスト | 準備 → 操作 → 期待 |
| --- | --- | --- |
| 11 | 許可後の自動再読み込み | `permissions = (denied, denied); permissionsAfterRequest = (granted, granted);` → 初回 `DashboardNeedsPermission` → `fake.readGate = Completer(); final f = controller.requestPermissions(); await pump();` → 状態の `isLoading == true` → `readGate!.complete(); await f;` → `AsyncData` で `DashboardReady`、`steps` / `sleep` とも `MetricLoaded`。`requestPermissionsCalls == 1` |
| 12 | 権限ダイアログ中の `onResumed()` は無視される | 初回完了後 `fake.requestGate = Completer(); final f = controller.requestPermissions(); await pump(); final calls = fake.checkAvailabilityCalls;` → `await controller.onResumed();` → `fake.checkAvailabilityCalls == calls` → `requestGate!.complete(); await f;` |
| 13 | `requestPermissions()` が例外 → フラグが戻り、エラーにならない | `fake.requestError = Exception('x')` → 初回完了後 `await controller.requestPermissions();`(例外が出ない)→ 状態の `hasError == false` で値が `DashboardReady` → `fake.availability = updateRequired; await controller.onResumed();` → 値が `DashboardUnavailable`(= `_requestingPermission` が false に戻っている) |
| 14 | 実行中の `refresh()` があるときの `requestPermissions()` → 許可後の状態で表示 | `permissions = (denied, denied); permissionsAfterRequest = (granted, granted);` → 初回 `DashboardNeedsPermission` → `final gate = Completer<void>(); fake.permissionsGate = gate; final r = controller.refresh(); await pump();`(refresh は「未許可」を取得した状態で待機)→ `final p = controller.requestPermissions(); await pump(); fake.permissionsGate = null; gate.complete(); await Future.wait([r, p]);` → 値が `DashboardReady` で `steps` / `sleep` とも `MetricLoaded` |

**フォアグラウンド復帰**

| # | テスト | 準備 → 操作 → 期待 |
| --- | --- | --- |
| 15 | 権限が変わらない復帰で再読み込みしない | 初回 `DashboardReady` 完了後 `final n = fake.stepsCalls.length;` → `await controller.onResumed();` → `fake.stepsCalls.length == n` |
| 16 | 権限なしで終わった後、何も変えずに復帰 → 再読み込みしない | `permissions = (denied, denied)` → 初回 `DashboardNeedsPermission`(`checkAvailabilityCalls == 1`)→ `await controller.onResumed();` → `checkAvailabilityCalls == 2`(復帰の確認の 1 回だけ。`_fetch` は走らない) |
| 17 | 利用不可で終わった後、更新して復帰 → 再読み込み | `availability = updateRequired` → 初回 `DashboardUnavailable` → `fake.availability = available; await controller.onResumed();` → 値が `DashboardReady` |
| 18 | 権限が変わった復帰で再読み込み | 初回 `DashboardReady`(両方許可)→ `fake.permissions = (granted, denied); await controller.onResumed();` → 値の `sleep is MetricPermissionDenied` |
| 19 | 想定外の例外の後の復帰は必ず再読み込み | `availabilityError = Exception('x')` → 初回(両方 `MetricFailed`)→ `fake.availabilityError = null; await controller.onResumed();` → 値の `steps is MetricLoaded` |
| 20 | 復帰の確認中の例外 → 再読み込み | 初回 `DashboardReady` 完了後 `final n = fake.stepsCalls.length; fake.permissionsError = Exception('x'); await controller.onResumed();` → `hasError == false`、値が `DashboardReady` で `steps` / `sleep` とも `MetricFailed(readFailed)`(再読み込みが走り、#19 と同じ扱いになった) |

**設定・ストア**

| # | テスト | 準備 → 操作 → 期待 |
| --- | --- | --- |
| 21 | `openSettings()` はリポジトリの結果を返し、状態を変えない | 初回完了後 `fake.openSettingsResult = false;` → `await controller.openSettings() == false`、`openSettingsCalls == 1`、状態の値が同一インスタンス(`identical`) |
| 22 | `openStore()` も同様 | `openStoreResult = true` → `true`、`openStoreCalls == 1` |

## 8. `test/presentation/dashboard/dashboard_state_test.dart`(`isAllEmpty`)

`final range = buildDateRange(DateTime(2026, 10, 6, 10, 30));` を使い、7 日分のデータはテスト内のヘルパーで作る:

```dart
MetricLoaded<DailySteps> stepsOf(List<int?> values) => MetricLoaded([
  for (var i = 0; i < 7; i++)
    DailySteps(date: range.days[i], steps: values[i], isToday: i == 0),
]);
MetricLoaded<DailySleep> sleepOf({bool withRecordOnToday = false}) => MetricLoaded([
  for (var i = 0; i < 7; i++)
    DailySleep(
      date: range.days[i],
      sessions: i == 0 && withRecordOnToday
          ? [SleepSession(start: DateTime(2026, 10, 5, 23), end: DateTime(2026, 10, 6, 7))]
          : const [],
    ),
]);
const noSteps = [null, null, null, null, null, null, null];
```

| テスト | steps | sleep | 期待 |
| --- | --- | --- | --- |
| 片方未許可 + 片方全日記録なし | `MetricPermissionDenied()` | `sleepOf()` | `true` |
| 両方 Loaded・全日記録なし | `stepsOf(noSteps)` | `sleepOf()` | `true` |
| 歩数に記録あり | `stepsOf([8432, null, ...])` | `sleepOf()` | `false` |
| 睡眠に記録あり | `stepsOf(noSteps)` | `sleepOf(withRecordOnToday: true)` | `false` |
| 片方 `MetricFailed` | `MetricFailed(readFailed)` | `sleepOf()` | `false` |
| 両方未許可(Loaded が無い) | `MetricPermissionDenied()` | `MetricPermissionDenied()` | `false` |

## 9. 完了条件(すべて通す)

```bash
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
```

`dart format` で差分が出たら `dart format lib test` で整形してから再確認する。テストが通らないとき、**期待値をテストを通すためだけに書き換えない**。§4 の擬似コードどおりに書いても §7 のテストが通らない場合は、原因(Riverpod の挙動など)を書いて停止・報告する。

## 10. 検収指摘の対応(司令塔が決定済み)

### 10.1 `_fetch()` の直列化をループにする(§4.5 を置き換える)

`await running` の後、`_inFlight` が空いた隙に別の `_fetch()` が始まっていると本体が 2 本並走し、`_lastSnapshot` の不変条件が崩れる。確認し直すループにする。待っている間に破棄されたら、本体を始めずに待った結果を返す(破棄後の `ref.read` で例外を出さないため):

```dart
Future<DashboardState> _fetch({bool force = false}) async {
  while (_inFlight != null) {
    final running = _inFlight!;
    if (!force) return running;          // 合流する(最初の await より前なので同期的に判定される)
    final discarded = await running;     // 古い結果は捨てる
    if (!ref.mounted) return discarded;
  }
  late final Future<DashboardState> future;
  future = _fetchBody().whenComplete(() {
    if (identical(_inFlight, future)) _inFlight = null;
  });
  _inFlight = future;
  return future;
}
```

### 10.2 `requestPermissions()` の二重呼び出しを無視する

先頭に `if (_requestingPermission) return;` を置く(二重タップで先に終わった側の `finally` がフラグを下ろし、後続のダイアログ中に `onResumed()` が走るのを防ぐ)。doc コメントに「リクエスト中の再呼び出しは無視する」を足す。

### 10.3 テストの追加・強化(`dashboard_controller_test.dart`)

| # | 対象 | 変更 |
| --- | --- | --- |
| 14 | 既存「実行中の `refresh()` があるときの `requestPermissions()`」 | `final p = controller.requestPermissions(); await pump();` の**直後**(gate を外す前)に `expect(fake.checkPermissionsCalls, 2)` を足す(build の 1 回 + 待機中の refresh の 1 回。強制読み込みが古い読み込みの完了を待たずに始まっていれば 3 になる)。最後に `expect(fake.checkPermissionsCalls, 3)` と `expect(fake.stepsCalls.length, 7)` も足す |
| 16 | 既存「権限なしで終わった後、何も変えずに復帰」 | `expect(fake.stepsCalls, isEmpty)` と `expect(fake.sleepCalls, isEmpty)` を足す |
| 23 | 新規「`requestPermissions()` の二重呼び出しは 1 回だけリクエストする」 | 初回完了後 `fake.requestGate = Completer(); final a = controller.requestPermissions(); final b = controller.requestPermissions(); await pump();` → `requestPermissionsCalls == 1` → `requestGate!.complete(); await Future.wait([a, b]);` → `requestPermissionsCalls == 1` |
| 24 | 新規「読み込みを待っている間に破棄されても例外を出さない」 | `fake.readGate = Completer();` → `makeContainer()` → `await pump();`(build の読み込みが待機)→ `final f = controller.requestPermissions(); await pump();`(強制読み込みが build の完了待ち)→ `container.dispose();` → `fake.readGate!.complete();` → `await expectLater(f, completes);`。`ProviderContainer.test` の teardown での再 dispose が問題になる場合は、このテストだけ `ProviderContainer(...)` で作り自前で dispose する(override と listen は同じ) |
