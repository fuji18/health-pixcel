# 設計: Flutter プロジェクト生成と Android 構成(#3)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。

## 前提

- Flutter は `~/flutter/bin/flutter`(3.47.6)。PATH に無ければフルパスで呼ぶ
- devcontainer に Android SDK は無い。`flutter build apk` は**実行しない**(CI が担う)。`flutter create` の Android SDK 関連の警告は無視してよい
- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- コミットはしない(司令塔が行う)

## 1. 生成

```bash
~/flutter/bin/flutter create --project-name health_pixcel --org io.github.fuji18 --platforms=android .
```

直後に `git status` / `git diff` を確認し、次のとおり処置する。

| ファイル | 処置 |
| --- | --- |
| `README.md` | `git checkout -- README.md` で戻す(最終的に `git diff --exit-code README.md` が 0 であること) |
| `.gitignore`(ルート) | 生成された内容を一時ファイルに退避 → `git checkout -- .gitignore` で戻す → 退避した生成版と比べ、**既存に無い項目だけ**を既存の `# Flutter / Dart` 節の末尾に追記する(下記の注意を除く) |
| `analysis_options.yaml` | §5 の内容で全置換 |
| `lib/main.dart` / `test/widget_test.dart` | §6 で置き換え(`test/widget_test.dart` は削除) |
| `.metadata` | 生成のまま残す(コミット対象。Flutter のマイグレーションが使う) |
| `*.iml` | 生成版 `.gitignore` に `*.iml` があるので、上の統合で除外対象になる。コミットしない |
| `android/.gitignore` | 生成のまま |

`.gitignore` 統合の注意:
- 既存行と意味が同じ項目(`build/` と `/build/`、`.idea/`、`.dart_tool/` など)は追記しない
- `pubspec.lock` を除外する行は入れない(コミットする)
- `.metadata` を除外する行は入れない
- 生成版のコメント行・`# Miscellaneous` 等の見出しは持ち込まない。項目行だけ

## 2. パッケージ名を `io.github.fuji18.healthpixcel` に揃える

1. `android/app/build.gradle.kts` の `namespace` と `applicationId` を `"io.github.fuji18.healthpixcel"` に
2. `MainActivity.kt` を `android/app/src/main/kotlin/io/github/fuji18/health_pixcel/` から `android/app/src/main/kotlin/io/github/fuji18/healthpixcel/` へ `git mv` ではなく通常の移動(未追跡のため)で移し、空になった `health_pixcel/` ディレクトリを削除
3. `package` 宣言を `io.github.fuji18.healthpixcel` に
4. 確認: `grep -rn 'health_pixcel' android/` の結果に、Gradle の `namespace`/`applicationId`・Kotlin の `package`・ディレクトリ名が**残っていない**こと(マニフェストの `android:label="health_pixcel"` と `settings.gradle.kts` 等のプロジェクト名は残ってよい)

## 3. `android/app/build.gradle.kts`

- `minSdk = flutter.minSdkVersion` を `minSdk = 34` に変える
- それ以外(`compileSdk` / `targetSdk` / `ndkVersion` / 署名設定 / Kotlin の JVM ターゲット)は生成のまま

## 4. マニフェストと MainActivity

### 4.1 `android/app/src/main/AndroidManifest.xml`

生成されたファイルを土台に、次を**加える**。生成物の既存要素(`<application>` の `android:label` / `android:icon`、`MainActivity` の属性群・`meta-data`、`flutterEmbedding` の `meta-data`、`<queries>` 内の `PROCESS_TEXT` intent)は**そのまま残す**。

1. `<manifest>` 直下、`<application>` より前に:
   ```xml
   <!-- ヘルスコネクト: 読み取り権限のみ(PRD F1) -->
   <uses-permission android:name="android.permission.health.READ_STEPS"/>
   <uses-permission android:name="android.permission.health.READ_SLEEP"/>
   ```
2. `<application>` に `android:allowBackup="false"` を追加(クラウドバックアップの遮断。architecture.md「バックアップ戦略」)
3. `MainActivity` の LAUNCHER の `<intent-filter>` の後に:
   ```xml
   <!-- 権限の利用目的(androidx 版ヘルスコネクトの action。health パッケージの README の指定どおり残す。Android 14+ では下の alias が使われる) -->
   <intent-filter>
       <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
   </intent-filter>
   ```
4. `MainActivity` の `</activity>` の直後(`<application>` 内)に:
   ```xml
   <!-- Android 14+: ヘルスコネクトの権限画面の「利用目的」リンク先 -->
   <activity-alias
       android:name="ViewPermissionUsageActivity"
       android:exported="true"
       android:targetActivity=".MainActivity"
       android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
       <intent-filter>
           <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
           <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
       </intent-filter>
   </activity-alias>
   ```
5. 生成済みの `<queries>` 要素の中に(PROCESS_TEXT の `<intent>` の後へ)追加。`<queries>` を 2 つに分けない:
   ```xml
   <!-- ヘルスコネクトの状態確認(getSdkStatus)と権限の利用目的表示。health パッケージの README の指定どおり -->
   <package android:name="com.google.android.apps.healthdata"/>
   <intent>
       <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
   </intent>
   ```

ヘルスコネクト権限は上の 2 つだけ。`ACTIVITY_RECOGNITION` / `INTERNET` / その他の権限は main に**宣言しない**。

### 4.2 `android/app/src/release/AndroidManifest.xml`(新規)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <!-- 依存パッケージ経由で混入した INTERNET 権限もマージ時に除去する(PRD 最重要要件) -->
    <uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>
</manifest>
```

`debug/` / `profile/` の `AndroidManifest.xml` は生成のまま変更しない。

### 4.3 `MainActivity.kt`

```kotlin
package io.github.fuji18.healthpixcel

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

MethodChannel は書かない(#9)。

## 5. `analysis_options.yaml`(全置換)

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - avoid_print                  # 健康データのログ出力防止(flutter_lints に含まれるが明示する)
    - always_use_package_imports   # レイヤー検査を grep で行うため相対 import を禁止
    - prefer_final_locals
    - prefer_const_constructors
    - unawaited_futures            # Future の握りつぶし防止
    - avoid_dynamic_calls
```

**追記(検収時の判断)**: `flutter pub get` / `pub add` / `pub remove` を実行するたびに、Flutter 3.47 のツールが `analyzer: exclude: [build/**, android/**]` を自動で追記する。戻しても次の `pub get` でまた足されるため、この `exclude` は**受け入れる**。`build/` と `android/` には解析対象の Dart コードが無いため、lint の結果は変わらない。`development-guidelines.md`「analysis_options.yaml」との差分は、この 1 ブロックだけとする。

## 6. `pubspec.yaml` と Dart コード

### 6.1 依存

```bash
~/flutter/bin/flutter pub add health:^13.3.2 flutter_riverpod:^3.4.3 intl:^0.20.2
~/flutter/bin/flutter pub remove cupertino_icons
```

- `intl:^0.20.2` が解決できないときに限り、`intl` だけ制約なしの `flutter pub add intl` で入れ直す(architecture.md「pub get が解決できる範囲に合わせる」)。その場合は解決したバージョンを報告に書く
- `cupertino_icons` は Android 専用・Material のみのため外す(依存を増やさない)
- `flutter_lints`(dev)は生成のまま。それ以外の依存は**足さない**
- `description` / `version` / `environment` / `publish_to: 'none'` / `flutter: uses-material-design: true` は生成のまま。生成物の英語コメントは残してよい
- 実行後 `~/flutter/bin/flutter pub deps --style=compact` を実行し、**direct / transitive のパッケージ名一覧**を報告に含める(司令塔が「ネットワーク通信・解析 SDK を含まない」ことを確認するため)

### 6.2 `lib/main.dart`(全置換)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/app.dart';

void main() {
  runApp(const ProviderScope(child: HealthPixcelApp()));
}
```

### 6.3 `lib/app.dart`(新規)

```dart
import 'package:flutter/material.dart';

/// アプリのルート。最初の画面の選択は画面を作るチケットで足す。
class HealthPixcelApp extends StatelessWidget {
  const HealthPixcelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold());
  }
}
```

### 6.4 `test/app_test.dart`(新規。`test/widget_test.dart` は削除)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/app.dart';

void main() {
  testWidgets('HealthPixcelApp が MaterialApp を表示する', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthPixcelApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

## 7. 検証(実装者が回す)

```bash
~/flutter/bin/flutter analyze
~/flutter/bin/dart format --output=none --set-exit-if-changed .
~/flutter/bin/flutter test
git diff --exit-code README.md
grep -c 'android.permission.health' android/app/src/main/AndroidManifest.xml   # 2
grep -n 'tools:node="remove"' android/app/src/release/AndroidManifest.xml
git status --short   # pubspec.lock が未追跡として出ること、*.iml が出ないこと
```

失敗が `analysis_options.yaml` の規則に起因する場合は、§6 のコードをその規則に合うよう最小限直してよい(規則側は変えない)。
