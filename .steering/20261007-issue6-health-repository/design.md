# 設計: データ層 HealthConnectRepository(#6)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/functional-design.md`「HealthRepository」「HealthConnectRepository」(本チケットで更新済み)。**食い違ったら本ファイルを優先**する(差分は §0)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- `docs/` の変更は司令塔が済ませている。**`docs/` は変更しない**
- コミットはしない(司令塔が行う)
- 変更してよいのは次の 3 ファイルの新規作成と、本 steering の `tasklist.md` だけ。`pubspec.yaml`(`health: ^13.3.2` は導入済み)/ `lib/domain/` / `lib/main.dart` / `scripts/` は変更しない
  - `lib/data/health_repository.dart`
  - `lib/data/health_connect_repository.dart`
  - `test/data/health_connect_repository_test.dart`
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)
- `health` 13.3.2 のソースは `~/.pub-cache/hosted/pub.dev/health-13.3.2/` にある。シグネチャを確かめたいときはここを読む

## 0. 設計判断の記録(司令塔が決定済み)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| 歩数の `null` | **`HealthReadException(readFailed)` を投げる**。`0` は記録なしとして `null` を返す | `health` 13.3.2 の Kotlin 実装は記録なしで `0`、ネイティブ例外で `null` を返す。Issue の受け入れ条件(`null` も記録なし)から変更。ユーザー承認済み |
| テスト | `Health` をコンストラクタで注入し、`test/data/` でフェイクを使って変換規則をテストする | 受け入れ条件(変換規則)を機械的に検証するため。docs も更新済み |
| 例外変換の適用範囲 | `checkAvailability` / `checkPermissions` / `requestPermissions` / `readTotalSteps` / `readSleepSessions` の 5 つ | 上位層に `health` の例外型を漏らさない |
| `openPermissionSettings` | 本チケットでは **常に `false` を返す**(#9 で MethodChannel 実装に置き換える) | スコープ外。`false` は「開けなかった」= 画面がスナックバーを出すだけの安全側 |
| `configure()` 失敗 | `_configured` が失敗した Future のまま残り、以後の呼び出しはすべて `readFailed` になる | 端末情報の取得失敗は一時的な障害ではない。再試行の仕組みは作らない |

## 1. `lib/data/health_repository.dart`

import は `package:health_pixcel/domain/models/health_status.dart` と `package:health_pixcel/domain/models/sleep_session.dart` の 2 つだけ(flutter も health も import しない)。

```dart
/// ヘルスデータ基盤へのアクセス(データ層の抽象)。
///
/// 上位層はこの型にだけ依存する。プラットフォーム固有の例外は
/// [HealthReadException] に変換して投げる。
abstract interface class HealthRepository {
  /// ヘルスデータ基盤の利用可否。
  Future<HealthAvailability> checkAvailability();

  /// 歩数・睡眠それぞれの権限状態。
  Future<({PermissionStatus steps, PermissionStatus sleep})> checkPermissions();

  /// 歩数・睡眠の READ 権限をまとめてリクエストし、リクエスト後の状態を返す。
  Future<({PermissionStatus steps, PermissionStatus sleep})> requestPermissions();

  /// ヘルスコネクトのアプリ権限設定画面を開く(ダイアログが出なくなった場合の逃げ道)。
  /// 開けなかった場合は false を返す。
  Future<bool> openPermissionSettings();

  /// ヘルスコネクトの入手・更新ページ(Play ストア)を開く。開けなかった場合は false を返す。
  Future<bool> openHealthConnectStore();

  /// [start, end) の歩数合計。記録なしは null。失敗時は [HealthReadException] を投げる。
  Future<int?> readTotalSteps(DateTime start, DateTime end);

  /// [start, end) と重なる睡眠セッション(start / end はローカル時刻)。
  /// 失敗時は [HealthReadException] を投げる。
  Future<List<SleepSession>> readSleepSessions(DateTime start, DateTime end);
}

/// ヘルスデータの読み取り失敗。メッセージに健康データの値を含めない。
class HealthReadException implements Exception {
  const HealthReadException(this.kind);

  /// 失敗の種類。
  final HealthErrorKind kind;
}
```

- `toString()` は実装しない

## 2. `lib/data/health_connect_repository.dart`

import(この順):

```dart
import 'package:health/health.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';
```

### 2.1 クラスの骨格

```dart
/// [HealthRepository] の Android 実装(ヘルスコネクト。`health` パッケージ経由)。
class HealthConnectRepository implements HealthRepository {
  /// [health] はテストでフェイクを注入するための引数。省略時は `Health()`。
  HealthConnectRepository({Health? health}) : _health = health ?? Health();

  final Health _health;

  // late final なので初回アクセス時に 1 度だけ configure() が走る(functional-design.md)。
  late final Future<void> _configured = _health.configure();
  ...
}
```

### 2.2 例外の変換(private ヘルパー)

```dart
  /// configure 済みにしてから [body] を実行し、例外を [HealthReadException] に変換する。
  /// 元の例外はログにも戻り値にも残さない。
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      await _configured;
      return await body();
    } on HealthReadException {
      rethrow;
    } on UnsupportedError {
      // ヘルスコネクト利用不可(health が投げる)
      throw const HealthReadException(HealthErrorKind.unavailable);
    } catch (_) {
      throw const HealthReadException(HealthErrorKind.readFailed);
    }
  }
```

- `print` / `debugPrint` / `log` は一切使わない。`catch (e)` で変数を受けない(`_` にする)

### 2.3 各メソッド

| メソッド | 実装 |
| --- | --- |
| `checkAvailability` | `_guard` の中で `_health.getHealthConnectSdkStatus()` を呼び、`switch` 式で変換: `HealthConnectSdkStatus.sdkAvailable` → `available` / `HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired` → `updateRequired` / `HealthConnectSdkStatus.sdkUnavailable` と `null` → `notInstalled` |
| `checkPermissions` | `_guard(_readPermissions)` |
| `requestPermissions` | `_guard` の中で `await _health.requestAuthorization(const [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION], permissions: const [HealthDataAccess.READ, HealthDataAccess.READ]);`(戻り値の bool は使わない)→ `return _readPermissions();` |
| `openPermissionSettings` | `async => false`。直前に `// #9 で MethodChannel(health_pixcel/health_connect_settings)の実装に置き換える` とコメント |
| `openHealthConnectStore` | `try { await _configured; await _health.installHealthConnect(); return true; } catch (_) { return false; }`(`_guard` は使わない) |
| `readTotalSteps` | `_guard` の中で `final steps = await _health.getTotalStepsInInterval(start, end);` → `null` なら `throw const HealthReadException(HealthErrorKind.readFailed);` → `0` なら `null`、それ以外は `steps` を返す。`null` / `0` の扱いの理由を「なぜ」コメントで 1〜2 行書く(§0 の 1 行目) |
| `readSleepSessions` | `_guard` の中で `_health.getHealthDataFromTypes(types: const [HealthDataType.SLEEP_SESSION], startTime: start, endTime: end)` を呼び、各点を変換した `List<SleepSession>.unmodifiable([...])` を返す。変換: `dateTo.isAfter(dateFrom)` を満たす点だけ `SleepSession(start: p.dateFrom.toLocal(), end: p.dateTo.toLocal())` にする(満たさない点は捨てる)。順序は入力のまま |

`_readPermissions`(private、`_guard` を通さない。呼び出し元が `_guard` 内で呼ぶ):

```dart
  Future<({PermissionStatus steps, PermissionStatus sleep})> _readPermissions() async {
    // 片方だけ許可を判別するため、種別ごとに個別に問い合わせる
    final steps = await _health.hasPermissions(
      const [HealthDataType.STEPS],
      permissions: const [HealthDataAccess.READ],
    );
    final sleep = await _health.hasPermissions(
      const [HealthDataType.SLEEP_SESSION],
      permissions: const [HealthDataAccess.READ],
    );
    return (steps: _toStatus(steps), sleep: _toStatus(sleep));
  }

  /// null / false は未許可として扱う。
  static PermissionStatus _toStatus(bool? granted) =>
      granted == true ? PermissionStatus.granted : PermissionStatus.denied;
```

- 公開メソッドには `@override` を付ける。ドキュメントコメントは抽象側にあるので、実装側は補足があるもの(`readTotalSteps` の null/0、`openPermissionSettings` の暫定)だけ書く

## 3. `test/data/health_connect_repository_test.dart`

### 3.1 フェイク

`package:flutter_test/flutter_test.dart` の `Fake` を使う。

```dart
class _FakeHealth extends Fake implements Health {
  int configureCalls = 0;
  Object? configureError;                    // 非 null なら configure() がこれを投げる
  HealthConnectSdkStatus? sdkStatus = HealthConnectSdkStatus.sdkAvailable;
  Map<HealthDataType, bool?> granted = {};   // hasPermissions の戻り値(種別ごと)
  Map<HealthDataType, bool?>? grantedAfterRequest; // 非 null なら requestAuthorization 後に granted を差し替える
  final hasPermissionsCalls = <(List<HealthDataType>, List<HealthDataAccess>?)>[];
  final requestCalls = <(List<HealthDataType>, List<HealthDataAccess>?)>[];
  int? totalSteps;
  final stepsCalls = <(DateTime, DateTime)>[];
  List<HealthDataPoint> points = [];
  final dataCalls = <(List<HealthDataType>, DateTime, DateTime)>[];
  Object? readError;   // 非 null なら hasPermissions / getTotalStepsInInterval / getHealthDataFromTypes がこれを投げる
  bool installThrows = false;
  ...
}
```

override するメソッドとシグネチャ(`health` 13.3.2 と完全一致させる):

- `Future<void> configure()` — `configureCalls++`。`configureError` があれば投げる
- `Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus()` — `sdkStatus` を返す
- `Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions})` — 呼び出しを記録 → `readError` があれば投げる → `granted[types.single]` を返す
- `Future<bool> requestAuthorization(List<HealthDataType> types, {List<HealthDataAccess>? permissions})` — 呼び出しを記録 → `grantedAfterRequest` があれば `granted` を差し替え → `true`
- `Future<void> installHealthConnect()` — `installThrows` なら `StateError('x')` を投げる
- `Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true})` — 記録 → `readError` があれば投げる → `totalSteps`
- `Future<List<HealthDataPoint>> getHealthDataFromTypes({required List<HealthDataType> types, Map<HealthDataType, HealthDataUnit>? preferredUnits, required DateTime startTime, required DateTime endTime, List<RecordingMethod> recordingMethodsToFilter = const []})` — 記録 → `readError` があれば投げる → `points`

注意: `Fake` は override していないメソッドで `UnimplementedError`(= `UnsupportedError` のサブクラス)を投げ、`_guard` が `unavailable` に変換してしまう。**上記 7 メソッドは必ず override する。**

睡眠のデータ点のヘルパー:

```dart
HealthDataPoint _sleep(DateTime from, DateTime to) => HealthDataPoint(
  uuid: 'u',
  value: NumericHealthValue(numericValue: 0),
  type: HealthDataType.SLEEP_SESSION,
  unit: HealthDataUnit.MINUTE,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: 's',
  sourceName: 'n',
);
```

### 3.2 テストケース(`group` ごと。`setUp` で `fake = _FakeHealth(); repo = HealthConnectRepository(health: fake);`)

例外の検証は `expect(() => repo.xxx(...), throwsA(isA<HealthReadException>().having((e) => e.kind, 'kind', HealthErrorKind.readFailed)))` の形。

1. **checkAvailability**: `sdkAvailable` → `available` / `sdkUnavailableProviderUpdateRequired` → `updateRequired` / `sdkUnavailable` → `notInstalled` / `null` → `notInstalled`
2. **checkPermissions**:
   - `granted = {STEPS: true, SLEEP_SESSION: false}` → `(steps: granted, sleep: denied)`
   - `granted = {STEPS: null, SLEEP_SESSION: true}` → `(steps: denied, sleep: granted)`
   - `hasPermissionsCalls` が 2 件で、それぞれ `[STEPS]` / `[SLEEP_SESSION]` と `[HealthDataAccess.READ]`
3. **requestPermissions**: `granted` を両方 `false`、`grantedAfterRequest = {STEPS: true, SLEEP_SESSION: true}` → 戻り値が両方 `granted`。`requestCalls.single` が `[STEPS, SLEEP_SESSION]` と `[READ, READ]`
4. **readTotalSteps**:
   - `8432` → `8432`、引数の `start` / `end` がそのまま渡る
   - `0` → `null`
   - `null` → `HealthReadException(readFailed)`
5. **readSleepSessions**:
   - UTC のデータ点(`DateTime.utc(2026, 10, 5, 14)` 〜 `DateTime.utc(2026, 10, 5, 21)`)→ 1 件。`start.isUtc` / `end.isUtc` が `false` で、`start.isAtSameMomentAs(元の dateFrom)` / `end` も同様
   - `dateTo == dateFrom` の点と `dateTo < dateFrom` の点は破棄され、正常な点だけ残る(3 点入れて 1 件)
   - `dataCalls.single` の types が `[SLEEP_SESSION]`、start / end が引数どおり
   - 戻り値のリストに `add` すると `UnsupportedError`(不変)
6. **例外の変換**:
   - `readError = UnsupportedError('x')` → `readTotalSteps` / `readSleepSessions` / `checkPermissions` が `unavailable`
   - `readError = HealthException(HealthDataType.STEPS, 'x')` → `readSleepSessions` が `readFailed`
   - `readError = StateError('x')` → `readTotalSteps` が `readFailed`
   - `configureError = StateError('x')` → `checkAvailability` が `readFailed`
7. **configure は 1 回だけ**: `checkAvailability` → `checkPermissions` → `readTotalSteps` → `readSleepSessions` を順に呼んだ後、`configureCalls == 1`
8. **openHealthConnectStore**: 通常 → `true` / `installThrows = true` → `false`
9. **openPermissionSettings**: `false`

## 4. 完了条件(すべて通す)

```bash
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
```

`dart format` で差分が出たら `dart format lib test` で整形してから再確認する。

## 5. 検収指摘の対応(テストの追加のみ。実装コードは変更しない)

`test/data/health_connect_repository_test.dart` に次を追加する。

1. フェイクに `Object? requestError;`(非 null なら `requestAuthorization` が記録の後にこれを投げる)を足す
2. 「例外の変換」group に追加:
   - `readError = UnsupportedError('x')` → `requestPermissions` が `unavailable`(`hasPermissions` 経由)
   - `requestError = HealthException(HealthDataType.STEPS, 'x')` → `requestPermissions` が `readFailed`
   - `sdkStatus` はそのままで `configureError = UnsupportedError('x')` → `checkAvailability` が `unavailable`(`_guard` が `configure` の例外も変換すること)
   - `configureError = StateError('x')` のとき、`checkAvailability` と `readTotalSteps` の**両方**が `readFailed` で、`configureCalls == 1`(再試行しない)
3. 「readSleepSessions」の破棄テスト: 件数に加えて、残った 1 件の `start` / `end` が正常な点の `dateFrom.toLocal()` / `dateTo.toLocal()` と `isAtSameMomentAs` であることを確認する
4. 「configure は 1 回だけ」group に追加: `Future.wait([repo.checkAvailability(), repo.checkPermissions(), repo.readTotalSteps(a, b)])` の後に `configureCalls == 1`(`totalSteps` は `100` などにしておく)

`toLocal` の検証(`isUtc == false`)は変えない(入力が `DateTime.utc` なので TZ によらず `toLocal()` を外せば落ちる)。完了条件は §4 と同じ。
