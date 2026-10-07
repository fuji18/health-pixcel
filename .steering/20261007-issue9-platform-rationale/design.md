# 設計: プラットフォーム連携と利用目的画面(#9)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/architecture.md`「プラットフォーム統合(Android)」、`docs/functional-design.md`「起動理由の取得(LaunchAction)」「PermissionRationaleScreen の内容」「状態別の表示」「テスト戦略」、`docs/development-guidelines.md`「Kotlin(MainActivity)」。**食い違ったら本ファイルを優先**する(差分は §0)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- `docs/` は変更しない。コミットはしない(どちらも司令塔が行う)
- 作成・変更してよいのは次のファイルと本 steering の `tasklist.md` だけ。**`pubspec.yaml` / `AndroidManifest.xml` / `build.gradle.kts` / `scripts/` / `lib/domain/` / `lib/application/` / `test/fakes/` は変更しない**
  - 変更: `android/app/src/main/kotlin/io/github/fuji18/healthpixcel/MainActivity.kt`
  - 新規: `lib/data/platform_channels.dart`
  - 変更: `lib/data/health_connect_repository.dart`
  - 変更: `lib/presentation/providers.dart`
  - 新規: `lib/presentation/rationale/permission_rationale_screen.dart`
  - 変更: `lib/presentation/dashboard/dashboard_screen.dart`
  - 変更: `lib/app.dart`
  - 新規: `test/data/platform_channels_test.dart`
  - 変更: `test/data/health_connect_repository_test.dart`
  - 新規: `test/presentation/rationale/permission_rationale_screen_test.dart`
  - 変更: `test/presentation/dashboard/dashboard_screen_test.dart`
  - 変更: `test/app_test.dart`
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)。Riverpod 3.4.3 のソースは `~/.pub-cache/hosted/pub.dev/{riverpod,flutter_riverpod}-3.4.3/`
- **devcontainer に Android SDK は無い。Kotlin はローカルでコンパイルできない**(CI のリリースビルドで確認する)。§1 のコードをそのまま書き、勝手に API を変えない
- import はすべて `package:health_pixcel/...`(相対 import 禁止)。健康データの値・例外内容を `print` / `debugPrint` / `log` に渡さない
- 各公開要素に 1 行の `///` doc コメント(既存コードに合わせる)。Kotlin も KDoc 1 行
- **色・文字サイズを直書きしない**(`lib/presentation/` で `Colors.` / `Color(` / `fontSize` / `FontWeight` 禁止)。余白はすべて 4 の倍数

## 0. 設計判断の記録(司令塔が決定済み)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| 起動理由の取得タイミング | `onCreate` で `super.onCreate` の**前に** `intent?.action` をフィールドに確定させ、`getLaunchAction` はそのフィールドを返す | 「`onCreate` 時点の `intent.action`」(architecture.md)。後から `intent` が差し替わっても影響を受けない |
| 設定画面チャネルの Dart 名 | `HealthConnectSettingsChannel`(メソッド `open()`) | docs に名前が無い。`LaunchChannel` と対にする |
| チャネルの差し替え | 両クラスとも `MethodChannel` をコンストラクタ引数(省略時は既定名の `const MethodChannel`)で受ける。`HealthConnectRepository` は `HealthConnectSettingsChannel? settingsChannel` を受ける | 既存の `Health? health` 注入と同じ形。テストは既定チャネルにモックハンドラを付けるので、実際には引数を使わなくてよい |
| チャネル失敗時 | Dart 側でも全例外を捕捉して `normal` / `false` を返す(`MissingPluginException` を含む) | Kotlin 側は例外を投げない方針だが、ウィジェットテスト等ネイティブが無い環境でも落ちないように |
| 判定中の画面 | `launchActionProvider` が `AsyncLoading` の間は `const Scaffold()`(空) | functional-design.md |
| 判定がエラー | `DashboardScreen` | `LaunchChannel` は例外を出さないが、防御的に `normal` 扱い |
| 利用目的画面の見出し | `AppBar` の `title` に「健康データの利用について」。`automaticallyImplyLeading: false`(戻る矢印を出さない) | 操作は「閉じる」のみ(functional-design.md)。システムの戻る操作はそのまま効く |
| 「閉じる」の分岐 | コンストラクタ引数 `closesApp`(既定 `false`)。`true` → `SystemNavigator.pop()`、`false` → `Navigator.of(context).pop()` | 起動理由で開いた場合だけアプリを閉じる |
| 「詳しく見る」 | `DashboardNeedsPermission` の `StatusMessage` の **3 つ目**の `StatusAction`(`OutlinedButton` になる)。`Navigator.push` で `PermissionRationaleScreen()` を開く | #8 の申し送り。Ready の片方未許可セクションには足さない(functional-design.md「状態別の表示」) |

## 1. `MainActivity.kt`(全置き換え)

```kotlin
package io.github.fuji18.healthpixcel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.health.connect.HealthConnectManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** health パッケージの権限リクエストを受けるため FlutterFragmentActivity を継承する。 */
class MainActivity : FlutterFragmentActivity() {
    /** コールドスタート時の起動理由("normal" / "permissionRationale")。onNewIntent は扱わない。 */
    private var launchAction = LAUNCH_NORMAL

    override fun onCreate(savedInstanceState: Bundle?) {
        launchAction = when (intent?.action) {
            ACTION_SHOW_PERMISSIONS_RATIONALE,
            Intent.ACTION_VIEW_PERMISSION_USAGE -> LAUNCH_PERMISSION_RATIONALE
            else -> LAUNCH_NORMAL
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> result.success(openHealthConnectSettings())
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, LAUNCH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchAction" -> result.success(launchAction)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * このアプリの権限画面 → ヘルスコネクトのホームの順に開く。どちらも開けなければ false。
     * パッケージ可視性の制限で resolveActivity は当てにならないため、startActivity の例外で判定する。
     */
    private fun openHealthConnectSettings(): Boolean =
        tryStartActivity(
            Intent(HealthConnectManager.ACTION_MANAGE_HEALTH_PERMISSIONS)
                .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName),
        ) || tryStartActivity(Intent(HealthConnectManager.ACTION_HEALTH_HOME_SETTINGS))

    /** 開けたら true。ActivityNotFoundException / SecurityException は false。 */
    private fun tryStartActivity(intent: Intent): Boolean =
        try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }

    private companion object {
        const val SETTINGS_CHANNEL = "health_pixcel/health_connect_settings"
        const val LAUNCH_CHANNEL = "health_pixcel/launch"
        const val ACTION_SHOW_PERMISSIONS_RATIONALE =
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
        const val LAUNCH_NORMAL = "normal"
        const val LAUNCH_PERMISSION_RATIONALE = "permissionRationale"
    }
}
```

- `resolveActivity` / `queryIntentActivities` / `packageManager` を**使わない**
- ログ出力(`Log.*`)を入れない

## 2. `lib/data/platform_channels.dart`(新規)

```dart
import 'package:flutter/services.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

/// 起動理由の取得(MethodChannel `health_pixcel/launch`)。
class LaunchChannel {
  /// [channel] はテスト用。省略時は `health_pixcel/launch`。
  const LaunchChannel({MethodChannel channel = const MethodChannel('health_pixcel/launch')})
    : _channel = channel;

  final MethodChannel _channel;

  /// 起動理由。未知の値・失敗時は [LaunchAction.normal]。
  Future<LaunchAction> getLaunchAction() async {
    try {
      final value = await _channel.invokeMethod<String>('getLaunchAction');
      return switch (value) {
        'permissionRationale' => LaunchAction.permissionRationale,
        _ => LaunchAction.normal,
      };
    } catch (_) {
      return LaunchAction.normal;
    }
  }
}

/// ヘルスコネクトの設定画面を開く(MethodChannel `health_pixcel/health_connect_settings`)。
class HealthConnectSettingsChannel {
  /// [channel] はテスト用。省略時は `health_pixcel/health_connect_settings`。
  const HealthConnectSettingsChannel({
    MethodChannel channel = const MethodChannel('health_pixcel/health_connect_settings'),
  }) : _channel = channel;

  final MethodChannel _channel;

  /// 開けたら true。開けなかった・失敗時は false。
  Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } catch (_) {
      return false;
    }
  }
}
```

(整形は `dart format` に任せる)

## 3. `lib/data/health_connect_repository.dart`(変更)

- `import 'package:health_pixcel/data/platform_channels.dart';` を足す
- コンストラクタ: `HealthConnectRepository({Health? health, HealthConnectSettingsChannel? settingsChannel}) : _health = health ?? Health(), _settingsChannel = settingsChannel ?? const HealthConnectSettingsChannel();`。doc コメントを「[health] / [settingsChannel] はテストでフェイクを注入するための引数。」に直す
- フィールド `final HealthConnectSettingsChannel _settingsChannel;` を足す
- `openPermissionSettings` を次に置き換える(「暫定実装」のコメントと `// #9 で…` のコメントは消す)。`_configured` は待たない:

```dart
  @override
  Future<bool> openPermissionSettings() => _settingsChannel.open();
```

## 4. `lib/presentation/providers.dart`(追記)

- import 追加: `package:health_pixcel/data/platform_channels.dart` と `package:health_pixcel/domain/models/health_status.dart`
- 末尾に:

```dart
/// 起動理由。HealthPixcelApp が最初の画面を決めるために使う。テストで差し替える。
final launchActionProvider = FutureProvider<LaunchAction>(
  (ref) => const LaunchChannel().getLaunchAction(),
);
```

## 5. `lib/presentation/rationale/permission_rationale_screen.dart`(新規)

```dart
/// 権限の利用目的の説明画面(ヘルスコネクトの「利用目的」と案内画面の「詳しく見る」の表示先)。
class PermissionRationaleScreen extends StatelessWidget {
  const PermissionRationaleScreen({super.key, this.closesApp = false});

  /// true なら「閉じる」でアプリを閉じる(ヘルスコネクトから起動された場合)。false なら前の画面に戻る。
  final bool closesApp;
}
```

本文の項目はファイル内の private 定数で持つ(ラベル, 本文)。**文言は一字一句この通り**:

| ラベル | 本文 |
| --- | --- |
| `読み取るデータ` | `歩数・睡眠(就寝・起床時刻)` |
| `使い道` | `直近 7 日の歩数と睡眠を、このアプリの画面に表示するためだけに使います` |
| `送信` | `データを端末の外に送信しません(このアプリはインターネットに接続する権限を持っていません)` |
| `保存・書き込み` | `データをアプリ内に保存せず、ヘルスコネクトへの書き込みも行いません` |
| `取り消し` | `権限はヘルスコネクトの設定からいつでも取り消せます` |

```dart
const _items = [
  (label: '読み取るデータ', body: '歩数・睡眠(就寝・起床時刻)'),
  ...
];
```

`build()`:

- `Scaffold`
  - `appBar: AppBar(title: const Text('健康データの利用について'), automaticallyImplyLeading: false)`
  - `body: ListView(padding: const EdgeInsets.all(16), children: [...])`
    - 各項目: `Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: textTheme.titleSmall), const SizedBox(height: 4), Text(body, style: textTheme.bodyLarge)]))`
    - 最後に `const SizedBox(height: 8)` と `Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () => _close(context), child: const Text('閉じる')))`
- `textTheme` は `Theme.of(context).textTheme`

```dart
  void _close(BuildContext context) {
    if (closesApp) {
      SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }
```

(`SystemNavigator` は `package:flutter/services.dart`)

## 6. `lib/presentation/dashboard/dashboard_screen.dart`(変更)

- import 追加: `package:health_pixcel/presentation/rationale/permission_rationale_screen.dart`
- `DashboardNeedsPermission()` の `actions` の末尾に `StatusAction('詳しく見る', _openRationale)` を足す(3 つ目)
- メソッド追加(`_openSettings` の直前に置く):

```dart
  void _openRationale() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PermissionRationaleScreen()),
  );
```

それ以外は変えない。

## 7. `lib/app.dart`(変更)

- `HealthPixcelApp` を `ConsumerWidget` に変える。doc コメントを「アプリのルート。起動理由(launchActionProvider)で最初の画面を決める。」に置き換える
- import 追加: `package:flutter_riverpod/flutter_riverpod.dart`、`package:health_pixcel/domain/models/health_status.dart`、`package:health_pixcel/presentation/providers.dart`、`package:health_pixcel/presentation/rationale/permission_rationale_screen.dart`。**`lib/data/` は import しない**

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget home = switch (ref.watch(launchActionProvider)) {
      AsyncLoading() => const Scaffold(),
      AsyncData(value: LaunchAction.permissionRationale) =>
        const PermissionRationaleScreen(closesApp: true),
      _ => const DashboardScreen(),
    };
    return MaterialApp(
      title: 'health-pixcel',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: home,
    );
  }
```

- `AsyncLoading()` のパターンがコンパイルできない場合に限り、`async.isLoading` / `async.value` の `if` で同等に書き換えてよい(挙動は上と同じにすること)

## 8. テスト

各テストファイルの `main()` 冒頭で、MethodChannel をモックするものは `TestWidgetsFlutterBinding.ensureInitialized();` を呼ぶ。モックは `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler)`、後片付けは `addTearDown(() => ...setMockMethodCallHandler(channel, null))`。

### 8.1 `test/data/platform_channels_test.dart`(新規)

`const launch = MethodChannel('health_pixcel/launch')` と `const settings = MethodChannel('health_pixcel/health_connect_settings')` にハンドラを付け、**引数なしの** `const LaunchChannel()` / `const HealthConnectSettingsChannel()` を使う(既定のチャネル名が正しいことも同時に確かめるため)。

`group('LaunchChannel')`:
1. `'permissionRationale'` → `LaunchAction.permissionRationale`。ハンドラに来た `call.method` が `'getLaunchAction'` であること
2. `'normal'` → `normal`
3. 未知の文字列 `'other'` → `normal`
4. `null` → `normal`
5. ハンドラが `PlatformException(code: 'x')` を投げる → `normal`
6. ハンドラ未設定(`MissingPluginException`)→ `normal`

`group('HealthConnectSettingsChannel')`:
1. `true` → `true`。`call.method` が `'open'`
2. `false` → `false`
3. `null` → `false`
4. `PlatformException` → `false`
5. ハンドラ未設定 → `false`

### 8.2 `test/data/health_connect_repository_test.dart`(変更)

末尾の `test('openPermissionSettings は false', ...)` を `group('openPermissionSettings')` に置き換える(既存の `repo` を使う):
1. `health_pixcel/health_connect_settings` のハンドラが `true` を返す → `true`、`call.method == 'open'`
2. ハンドラが `false` を返す → `false`

ファイル冒頭の `main()` に `TestWidgetsFlutterBinding.ensureInitialized();` が無ければ足す。

### 8.3 `test/presentation/rationale/permission_rationale_screen_test.dart`(新規)

`SystemChannels.platform` にモックハンドラを付け、受けた `call.method` をリストに記録する(`'SystemNavigator.pop'` を数える)。

1. **本文**: `MaterialApp(home: PermissionRationaleScreen())` で、見出し「健康データの利用について」、5 つのラベルと 5 つの本文(§5 の表の全文)、「閉じる」が `findsOneWidget`。戻る矢印(`find.byType(BackButton)`)が `findsNothing`
2. **前の画面に戻る**: `MaterialApp(home: Builder(...「開く」ボタンが Navigator.push で PermissionRationaleScreen() を開く...))` → 「開く」をタップ → `pumpAndSettle` → 「閉じる」をタップ → `pumpAndSettle` → `PermissionRationaleScreen` が `findsNothing`、「開く」が `findsOneWidget`、`SystemNavigator.pop` が 0 回
3. **アプリを閉じる**: `MaterialApp(home: PermissionRationaleScreen(closesApp: true))` → 「閉じる」をタップ → `SystemNavigator.pop` が 1 回。画面は残っている(`findsOneWidget`)

### 8.4 `test/presentation/dashboard/dashboard_screen_test.dart`(変更)

- ケース 5: `expect(find.text('詳しく見る'), findsNothing)` を `findsOneWidget` に反転
- ケース 17 を末尾に追加: `'17 詳しく見るから利用目的を開き、閉じるで戻る'`。`fake.permissions = bothDenied` → `pumpScreen` → `pumpAndSettle` → 「詳しく見る」をタップ → `pumpAndSettle` → `PermissionRationaleScreen` と「健康データの利用について」が `findsOneWidget` → 「閉じる」をタップ → `pumpAndSettle` → `PermissionRationaleScreen` が `findsNothing`、案内「歩数と睡眠を表示するには、ヘルスコネクトの読み取り権限が必要です」が `findsOneWidget`

### 8.5 `test/app_test.dart`(変更)

既存テストの `overrides` に `launchActionProvider.overrideWith((ref) async => LaunchAction.normal)` を足す(テスト名・他のアサーションはそのまま)。次の 2 つを追加:

1. `'起動理由が permissionRationale なら利用目的画面が最初に出る'`: `launchActionProvider` を `permissionRationale` で override → `pumpAndSettle` → `PermissionRationaleScreen` が `findsOneWidget`、`DashboardScreen` が `findsNothing`、`tester.widget<PermissionRationaleScreen>(...).closesApp` が `true`、`FakeHealthRepository` の `checkAvailability` が呼ばれていない(フェイクに呼び出し回数のフィールドが無ければこの 1 行は省く。`test/fakes/` は変更しない)
2. `'起動理由の判定中は空の画面を出す'`: `final completer = Completer<LaunchAction>();` で `overrideWith((ref) => completer.future)` → `pump()`(`pumpAndSettle` は使わない)→ `Scaffold` が `findsOneWidget`、`DashboardScreen` と `PermissionRationaleScreen` が `findsNothing` → 後片付けとして `completer.complete(LaunchAction.normal)` してから `pumpAndSettle`

## 9. 完了条件

次の 6 コマンドがすべて成功すること(Kotlin のコンパイルは CI に委ねる):

```bash
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
bash scripts/check-layer-imports.sh
bash scripts/check-privacy.sh
grep -nE 'resolveActivity|queryIntentActivities' android/app/src/main/kotlin -r; test $? -eq 1
```

## 10. 検収指摘の対応(司令塔が採用を決定済み)

### 10.1 項目ラベルを見出しにする(`permission_rationale_screen.dart`)

各項目のラベルの `Text(label, style: textTheme.titleSmall)` を `Semantics(header: true, child: Text(...))` で包む(#8 のセクション見出しと同じ扱い)。それ以外は変えない。

### 10.2 戻る矢印のテストを push 状態で行う(`permission_rationale_screen_test.dart`)

- ケース 1 の `expect(find.byType(BackButton), findsNothing)` を削除する(単独の `home` では `automaticallyImplyLeading` に関係なく矢印が出ないため、偽陰性)
- ケース 2 の「開く」をタップ → `pumpAndSettle` の直後(「閉じる」をタップする前)に `expect(find.byType(BackButton), findsNothing)` を足す
- ケース 1 に追加: `final handle = tester.ensureSemantics();` → 5 つのラベルそれぞれについて `expect(tester.getSemantics(find.text(label)), matchesSemantics(isHeader: true, label: label))` → テスト本体の末尾で `handle.dispose()`(#8 と同じく `addTearDown` は使わない)。`matchesSemantics` が他のフラグ不一致で落ちる場合は `containsSemantics(isHeader: true)` に替えてよい

### 10.3 見送り(実装不要)

- `onNewIntent` 非対応: Issue のスコープ外
- 判定中の空 `Scaffold` のちらつき: #10 の実機確認で見る
- チャネルの全例外捕捉: 設計どおり
