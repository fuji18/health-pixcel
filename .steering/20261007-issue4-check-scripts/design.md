# 設計: アプリ検証スクリプト 3 本(#4)

<!-- status: ready -->

実装者はこのファイルと `tasklist.md` だけで作業を完遂できる。ここに無い判断が要ったら停止して報告すること。仕様の原文は `docs/repository-structure.md`「scripts/(アプリの検証スクリプト)」。本ファイルはそれを実装可能な粒度に落としたもので、**食い違ったら本ファイルを優先**する(差分は §0 に列挙済み)。

## 前提

- 作業ツリーに `.codex/config.toml` の変更と `.agents/` `.codex/agents/` `.codex/hooks.json` `.codex/hooks/` の未追跡ファイルがあるが、**本作業と無関係。触らない・戻さない**
- コミットはしない(司令塔が行う)
- `ci.yml` / `package.json` / `docs/` / `lib/` は変更しない
- devcontainer に Android SDK と shellcheck は無い。`check-release-permissions.sh` はフェイクの SDK・APK で確認する(§5)
- Flutter は `~/flutter/bin/flutter`(PATH に無ければフルパスで呼ぶ)

## 0. docs の仕様から決めた点(設計判断の記録)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| シェル | shebang は `#!/bin/sh`、`set -eu`。bash 固有構文(配列・`[[ ]]`・`pipefail`・`local` 以外の拡張・`$'..'`)は使わない。`local` も使わない | docs「POSIX シェル」。CI・npm は `bash scripts/x.sh` で呼ぶが、どちらでも動くようにする |
| 「許可リストは配列で定義」 | POSIX に配列は無いため、スクリプト冒頭の**改行区切りの文字列変数** `ALLOWED_PERMISSIONS` で定義する | 同上 |
| GNU 拡張 | `grep -r` / `--include` / `grep -E` の `\b` は使ってよい(`\b` は避けて文字クラスで書く)。`sort -V` を使ってよい | Git Bash・ubuntu はどちらも GNU grep / coreutils |
| 検査ルート | 3 本とも `ROOT="${CHECK_ROOT:-<スクリプトの親ディレクトリ>}"` に `cd` してから相対パスで検査する。`CHECK_ROOT` はフィクスチャ検証用 | カレントディレクトリに依存させない・サンプル入力で検証可能にする |
| 存在しないディレクトリ | 層ディレクトリ(`lib/domain/` 等)が無ければ、そのルールは 0 件扱い(エラーにしない)。`lib/` 自体が無ければ `exit 2` | 現時点で `lib/` は `main.dart` と `app.dart` だけ |
| コメント行 | コメント内の一致も違反として扱う(除外しない) | 保守的に倒す。必要なら `allow` で明示させる |
| `allow` 注記 | `check-privacy.sh` だけが対応。行末が `// privacy-check: allow(<1 文字以上の理由>)`(後ろに空白のみ可)の行を除外。`allow()` は除外しない。`check-layer-imports.sh` は除外を持たない | docs の仕様どおり(除外はプライバシー検査のみ) |
| aapt2 の選び方 | `build-tools/` 直下のディレクトリを `sort -V` で並べ、**`aapt2` か `aapt2.exe` を持つもののうち最新**を使う | 中途半端なインストールで最新ディレクトリに aapt2 が無い場合に誤検知で止めない |
| 権限 0 件 | `aapt2` の出力に `uses-permission` 行が 1 つも無ければ `exit 2`(「権限一覧を取得できませんでした」) | マニフェストは `READ_STEPS` を必ず宣言する。0 件は出力形式の変化・解析失敗の可能性が高く、素通しにしない(フェイルクローズ) |

## 1. 共通の作法

- 配置: `scripts/check-release-permissions.sh` / `scripts/check-layer-imports.sh` / `scripts/check-privacy.sh`。改行 LF(`.gitattributes` が `eol=lf`)、実行ビット付き(`chmod +x`。git 上も `100755` になるよう `git update-index --chmod=+x` は**しない**でよい — 司令塔が `git add` 時に確認する。`chmod +x` だけ行う)
- 冒頭コメント: 1〜3 行で目的と終了コード、仕様の参照先(`docs/repository-structure.md`「scripts/」)を書く
- ルート解決(3 本共通):

  ```sh
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  ROOT=${CHECK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}
  cd "$ROOT"
  ```

- 終了コード: `0` = 違反なし / `1` = 違反あり / `2` = 検査を実行できない(前提不足・内部エラー)
- 出力: 違反と結果は **stdout**、`exit 2` の理由は **stderr**。メッセージは日本語
- `grep` の終了コード: `0` = 一致 / `1` = 不一致 / `2` 以上 = エラー。`set -e` で一致なしが落ちないよう、`grep ... || rc=$?` の形で受け、`rc >= 2` なら stderr に理由を出して `exit 2`
- `.dart` 以外は検査しない(`--include='*.dart'`)

## 2. `check-layer-imports.sh`

### 2.1 ルール表

各ルールは「ラベル / 検索範囲 / 除外パス / 拡張正規表現(`grep -E`)」。検索範囲が存在しなければスキップ。検索は `grep -rnE --include='*.dart' <正規表現> <範囲>`。出力行は `lib/xxx.dart:12:import ...` 形式(`grep -rn` のまま)。

| # | ラベル(出力に使う) | 範囲 | 除外(結果行の先頭パスで除く) | 正規表現 |
| --- | --- | --- | --- | --- |
| L1 | `package:health/ は lib/data/ 以外で使えません` | `lib` | `lib/data/` 配下 | `package:health/` |
| L2 | `lib/domain/ は Flutter / Riverpod に依存できません` | `lib/domain` | — | `package:(flutter|flutter_riverpod)/` |
| L3 | `lib/application/ は Flutter / Riverpod に依存できません` | `lib/application` | — | `package:(flutter|flutter_riverpod)/` |
| L4 | `lib/domain/ は他の層を import できません` | `lib/domain` | — | `package:health_pixcel/(application|data|presentation)/` |
| L5 | `lib/application/ は presentation/ を import できません` | `lib/application` | — | `package:health_pixcel/presentation/` |
| L6 | `lib/data/ は application/ / presentation/ を import できません` | `lib/data` | — | `package:health_pixcel/(application|presentation)/` |
| L7 | `health_connect_repository.dart / platform_channels.dart は lib/data/ と lib/presentation/providers.dart 以外から import できません` | `lib` | `lib/data/` 配下と `lib/presentation/providers.dart` | `^[[:space:]]*(import|export)[[:space:]]+['"][^'"]*(health_connect_repository|platform_channels)\.dart['"]` |
| L8 | `相対 import は使えません(package:health_pixcel/ で書いてください)` | `lib` | — | `^[[:space:]]*(import|export)[[:space:]]+['"]\.\.?/` |

- 補足: L1 の `package:health/` は `package:health_pixcel/` に一致しない(直後が `/`)。L2/L3 の `package:flutter/` は `package:flutter_riverpod/` と別に書いているが 1 本の正規表現でよい
- 除外の実装: grep 結果を `grep -v -e '^lib/data/' -e '^lib/presentation/providers\.dart:'` のように**行頭のパス部**で除く(L1 は `^lib/data/` のみ、L7 は両方)
- `part` 指令は L8 の対象外(`import|export` のみ)

### 2.2 出力形式と終了

違反があったルールごとに:

```
[NG] <ラベル>
lib/domain/foo.dart:3:import 'package:flutter/material.dart';
```

全ルールを最後まで実行してから終了する(最初の違反で止めない)。

- 違反 1 件以上: 最後に `レイヤー検査: <N> 件の違反` を出して `exit 1`(N = 違反行の総数)
- 0 件: `レイヤー検査: OK` を出して `exit 0`
- `lib/` が無い: stderr に `lib/ が見つかりません(<ROOT>)` → `exit 2`

## 3. `check-privacy.sh`

### 3.1 ルール表

範囲は全ルール `lib`(P7 のみ `lib/domain`)。正規表現は `grep -E`。

| # | ラベル | 範囲 | 正規表現 |
| --- | --- | --- | --- |
| P1 | `ログ出力(print / debugPrint / dart:developer)` | `lib` | `(^|[^A-Za-z0-9_])print[[:space:]]*\(` と `debugPrint[[:space:]]*\(` と `dart:developer` |
| P2 | `ファイル・入出力(dart:io / path_provider)` | `lib` | `dart:io` と `path_provider` |
| P3 | `共有・クリップボード(Clipboard / share_plus / Share.)` | `lib` | `Clipboard` と `share_plus` と `(^|[^A-Za-z0-9_])Share\.` |
| P4 | `通信(http / dio / HttpClient / WebSocket)` | `lib` | `package:http/` と `package:dio/` と `HttpClient` と `WebSocket` |
| P5 | `保存(shared_preferences / sqflite / hive / isar)` | `lib` | `package:shared_preferences/` と `package:sqflite/` と `package:hive` と `package:isar` |
| P6 | `ロガー(logging / logger)` | `lib` | `package:logging/` と `package:logger/` |
| P7 | `lib/domain/ の toString() 実装` | `lib/domain` | `String[[:space:]]+toString[[:space:]]*\(` |

- 1 ルールに複数パターンがある場合は `grep -rnE --include='*.dart' -e <p1> -e <p2> ... <範囲>` で 1 回に検索する
- `dart:io` は `dart:io'` / `dart:io"` 以外(例: `dart:isolate`)には一致しないこと。`dart:io` は `dart:isolate` の部分文字列ではないのでそのままでよい
- `allow` 除外: grep 結果から、行末が `// privacy-check: allow(<理由>)` の行を除く。除外の正規表現(grep 結果の行全体に対して `grep -vE`):

  ```
  //[[:space:]]*privacy-check:[[:space:]]*allow\([^)]+\)[[:space:]]*$
  ```

  `allow()`(理由が空)は `[^)]+` に一致しないので除外されない

### 3.2 出力形式と終了

§2.2 と同じ形(`[NG] <ラベル>` + 該当行)。最後の行は `プライバシー検査: <N> 件の違反` / `プライバシー検査: OK`。`allow` で除外した行が 1 件以上あれば、OK/NG の行の直前に `(privacy-check: allow で除外: <M> 件)` を出す(PR レビューで確認させるため)。`lib/` が無ければ `exit 2`(§2.2 と同じ文言)。

## 4. `check-release-permissions.sh`

### 4.1 冒頭の定義

```sh
# 許可リスト(改行区切り)。変更するときは先に docs/product-requirements.md「セキュリティ・プライバシー」に理由を書く
ALLOWED_PERMISSIONS='
android.permission.health.READ_STEPS
android.permission.health.READ_SLEEP
io.github.fuji18.healthpixcel.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
'
APK=build/app/outputs/flutter-apk/app-release.apk
```

### 4.2 処理順(この順で判定し、最初に当たった `exit 2` で止める)

1. **APK の存在**: `$APK` が通常ファイルでなければ stderr に `リリース APK がありません: <APK>。先にリリースビルドを実行してください(flutter build apk --release)` → `exit 2`
2. **鮮度**: 次のパスのうち**存在するもの**について `find <パス...> -type f -newer "$APK"` を実行し、1 件でもあれば stderr に `リリースビルドが古いため再ビルドしてください。APK より新しいファイル:` と該当パス(最大 10 件。`head -n 10`)を出して `exit 2`
   - `lib` / `android/app/src` / `android/app/build.gradle.kts` / `android/build.gradle.kts` / `android/settings.gradle.kts` / `android/gradle.properties` / `pubspec.yaml` / `pubspec.lock`
   - 存在するパスが 1 つも無ければ `find` を呼ばずに次へ
3. **SDK の解決**: 次の順に候補を作り、**最初に「空でなく、ディレクトリとして存在する」もの**を `SDK` とする。どれも当たらなければ stderr に `Android SDK が見つかりません。探した場所:` と、各候補を `ANDROID_HOME=<値または(未設定)>` / `ANDROID_SDK_ROOT=<値または(未設定)>` / `android/local.properties の sdk.dir=<値または(なし)>` の 3 行で出して `exit 2`
   1. `$ANDROID_HOME`
   2. `$ANDROID_SDK_ROOT`
   3. `android/local.properties` の `sdk.dir`: `sed -n 's/^sdk\.dir=//p' android/local.properties | head -n 1` で取り、`\r` を除去(`tr -d '\r'`)し、エスケープを外す(`\:` → `:`、`\\` → `\`。sed で `s/\\:/:/g; s/\\\\/\\/g` の順)。その結果が `^[A-Za-z]:` で始まり、かつ `command -v cygpath` が成功するときだけ `cygpath -u` で変換する
4. **aapt2 の選択**: `"$SDK/build-tools"` 直下のディレクトリ名を `ls -1 | sort -V` で昇順に並べ、後ろから見て `aapt2` または `aapt2.exe` が実行可能(`-x`)な最初のものを使う。見つからなければ stderr に `aapt2 が見つかりません。探した場所: <SDK>/build-tools/*/aapt2(.exe)`(`build-tools` が無ければその旨も)を出して `exit 2`
5. **権限一覧の取得**: `"$AAPT2" dump permissions "$APK"` を実行し、出力を変数に取る(`tr -d '\r'`)。終了コードが 0 以外なら stderr に `aapt2 dump permissions が失敗しました` と aapt2 の出力を出して `exit 2`
6. **抽出**: 出力のうち `^uses-permission` で始まる行(`uses-permission-sdk-23:` も含む)から `name='([^']+)'` の値を取り出す(`sed -n "s/^uses-permission[^:]*: name='\([^']*\)'.*/\1/p"`)。重複は `sort -u` で除く。0 件なら stderr に `権限一覧を取得できませんでした(aapt2 の出力に uses-permission がありません)` と出力全文を出して `exit 2`
7. **表示**: `使用 aapt2: <パス>` と `APK の権限:` に続けて抽出した権限を 1 行ずつ(行頭 2 スペース)stdout に出す
8. **判定**(全件見てから終了):
   - `android.permission.INTERNET` があれば `[NG] INTERNET 権限が含まれています(PRD 最重要要件違反: リリース APK は外部と通信できてはならない)` を出す
   - 許可リストに無い権限(INTERNET を含む)ごとに `[NG] 許可リストにない権限: <名前>` を出す。許可リストとの照合は `printf '%s\n' "$ALLOWED_PERMISSIONS" | grep -qxF "$perm"`
   - NG が 1 件以上: 最後に `権限検査: NG(許可リストを変更する場合は先に docs/product-requirements.md「セキュリティ・プライバシー」に理由を追記してください)` → `exit 1`
   - 0 件: `権限検査: OK(INTERNET なし・すべて許可リスト内)` → `exit 0`

## 5. 確認手順(実装者が実行し、結果を報告に含める)

フィクスチャはスクラッチ領域に作る(`F=$(mktemp -d)`)。**リポジトリ内にフィクスチャを置かない。** 各ケースで終了コードと出力の要点を記録する。

### 5.1 実プロジェクト

- `bash scripts/check-layer-imports.sh; echo $?` → `0`
- `bash scripts/check-privacy.sh; echo $?` → `0`
- `npm run lint` → 成功し、出力に `レイヤー検査: OK` と `プライバシー検査: OK` が含まれる
- `sh scripts/check-layer-imports.sh` / `sh scripts/check-privacy.sh` でも `0`(POSIX sh(dash)で動くこと)

### 5.2 `check-layer-imports.sh`(`CHECK_ROOT=$F`)

`$F/lib/` に次を置き、各ルールが 1 回ずつ当たることを確認する(L1〜L8 すべてが `[NG]` で出て `exit 1`):

- `lib/domain/a.dart`: `import 'package:flutter/material.dart';`(L2)/ `import 'package:health_pixcel/data/x.dart';`(L4)
- `lib/application/b.dart`: `import 'package:flutter_riverpod/flutter_riverpod.dart';`(L3)/ `import 'package:health_pixcel/presentation/y.dart';`(L5)
- `lib/data/c.dart`: `import 'package:health/health.dart';`(L1 に**当たらない**こと)/ `import 'package:health_pixcel/application/z.dart';`(L6)
- `lib/presentation/d.dart`: `import 'package:health/health.dart';`(L1)/ `import 'package:health_pixcel/data/health_connect_repository.dart';`(L7)/ `import '../domain/a.dart';`(L8)
- `lib/presentation/providers.dart`: `import 'package:health_pixcel/data/platform_channels.dart';`(L7 に**当たらない**こと)

続けて違反を全部消したクリーンなフィクスチャ(上の当たらない 2 ファイルだけ残す)で `exit 0`。`lib/` の無い `CHECK_ROOT` で `exit 2`。

### 5.3 `check-privacy.sh`(`CHECK_ROOT=$F`)

`$F/lib/` に P1〜P7 それぞれ 1 行以上当たるファイルを置き `exit 1` を確認する。加えて次の境界を確認:

- `debugPrint('x');` が P1 に 1 回だけ出る(`print(` 側の正規表現に二重に当たらない)
- `blueprint(x)` は P1 に当たらない
- `print('x'); // privacy-check: allow(テスト用)` は除外され、`(privacy-check: allow で除外: 1 件)` が出る
- `print('x'); // privacy-check: allow()` は除外されない
- `lib/application/e.dart` の `String toString()` は P7 に当たらない(`lib/domain/` のみ)

クリーンなフィクスチャで `exit 0`、`lib/` 無しで `exit 2`。

### 5.4 `check-release-permissions.sh`(`CHECK_ROOT=$F`、フェイク SDK)

フェイク aapt2 は、環境変数 `FAKE_OUT` の内容を出力する sh スクリプトとして `$S/build-tools/34.0.0/aapt2` に置く(`chmod +x`)。`$S/build-tools/35.0.0/`(aapt2 なし)も作り、34.0.0 が選ばれることを確認する。APK は `mkdir -p $F/build/app/outputs/flutter-apk && touch .../app-release.apk`。

| ケース | 条件 | 期待 |
| --- | --- | --- |
| a | APK なし | `exit 2`・「先にリリースビルド」 |
| b | `$F/pubspec.yaml` を APK より新しくする(`touch -d '+1 minute'` 等。または APK を `touch -d '-1 hour'`) | `exit 2`・該当パスが出る |
| c | `ANDROID_HOME` / `ANDROID_SDK_ROOT` 未設定(`env -u`)・`local.properties` なし | `exit 2`・探した 3 箇所が出る |
| d | `ANDROID_HOME=$S` だが `build-tools` 配下に aapt2 なし | `exit 2`・探した場所が出る |
| e | `local.properties` に `sdk.dir=<$S>`(環境変数は未設定) | SDK が解決される(以降のケースと同じ判定に進む) |
| f | `FAKE_OUT` = `package: io.github.fuji18.healthpixcel` + READ_STEPS / READ_SLEEP / DYNAMIC_RECEIVER の `uses-permission: name='...'` + `permission: io.github.fuji18.healthpixcel.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | `exit 0` |
| g | f に `uses-permission: name='android.permission.INTERNET'` を追加 | `exit 1`・INTERNET の明示メッセージ + 許可リスト外として名前 |
| h | f に `uses-permission: name='android.permission.ACTIVITY_RECOGNITION'` を追加 | `exit 1`・名前が出る |
| i | `FAKE_OUT` = `package: x` のみ | `exit 2`・権限一覧を取得できない |
| j | フェイク aapt2 が `exit 1` する | `exit 2`・aapt2 失敗 |

ケース f は `sh scripts/check-release-permissions.sh` でも `exit 0` になること。

## 6. 完了条件

- §5 の全ケースが期待どおり
- `bash -n` と `sh -n` で 3 本とも構文エラーなし
- `dart format --output=none --set-exit-if-changed .` と `flutter analyze` が通る(Dart は変更していないが念のため)
- 報告に、§5 の各ケースの結果(終了コード)を表で含める

## 7. 検収指摘による改訂(code-reviewer 1 巡目)

§2〜§4 のうち下記に当たる箇所は、本節を優先する。

### 7.1 `check-release-permissions.sh`

1. **抽出のフェイルクローズ化(must-fix)**: §4.2 手順 6 を次で置き換える
   - 解析対象は aapt2 の **stdout のみ**(stderr は別の一時ファイル/変数に取り、手順 5 の失敗メッセージでだけ出す)。一時ファイルを使う場合は `mktemp` で作り `trap` で消す
   - `^uses-[A-Za-z0-9-]*permission` で始まる行(`uses-permission:` / `uses-permission-sdk-23:` / `uses-implied-permission:` など)を**権限行**とする。`package:` / `permission:`(アプリ自身の権限宣言)など、それ以外の行は無視する
   - 各権限行から `name=` の値を取り出す。単引用符・二重引用符の両方を受け付ける(`name='X'` / `name="X"`)
   - **値を取り出せなかった権限行、または値が空の権限行が 1 行でもあれば** stderr に `aapt2 の出力を解釈できない行があります:` とその行を出して `exit 2`
   - 権限行が 0 行なら従来どおり `exit 2`
2. **SDK 候補のフォールスルー(should-fix)**: §4.2 手順 3・4 を統合する。候補(`ANDROID_HOME` → `ANDROID_SDK_ROOT` → `local.properties`)を順に見て、**ディレクトリが存在し、かつ §4.2 手順 4 の方法で aapt2 が見つかった最初の候補**を使う。どの候補でも見つからなければ、各候補の値と結果(`(未設定)` / `(ディレクトリなし)` / `(aapt2 なし)`)を 1 行ずつ出して `exit 2`(エラー文言は「Android SDK または aapt2 が見つかりません。探した場所:」)

### 7.2 `check-privacy.sh`

1. P1 の `debugPrint[[:space:]]*\(` を `debugPrint[A-Za-z]*[[:space:]]*\(` に変える(`debugPrintThrottled` / `debugPrintSynchronously` を捕捉)。`print` のティアオフ(`foo(print)`)は対象外のまま(誤検知が多いため。レビューと `avoid_print` に任せる)
2. **`eval` を廃止する**: `grep` の引数は `set --` で積み上げて `"$@"` で渡す(例: `set -- -rnE --include='*.dart'; for p in ...; do set -- "$@" -e "$p"; done; set -- "$@" "$scope"; grep "$@"`)。パターン列は改行区切りの変数から `while IFS= read -r` で読むか、ルールごとに直接 `set --` を書く。どちらでもよい

### 7.3 `check-layer-imports.sh`

1. L7 の正規表現を、行頭の `import|export` に依存しない `['"][^'"]*(health_connect_repository|platform_channels)\.dart['"]` に変える(`import` と URI が改行で分かれた形も捕捉する)
2. L8 は既存の正規表現に加えて `^[[:space:]]*['"]\.\.?/[^'"]*\.dart['"]`(URI だけの行)も `-e` で検索する

### 7.4 追加確認(§5 に加える)

- 7.1-1: `FAKE_OUT` に (i) `uses-permission: name="android.permission.INTERNET"` を含む → `exit 1`(INTERNET を検出)、(ii) `uses-permission: name=''` を含む → `exit 2`、(iii) `uses-permission: foo` を含む → `exit 2`、(iv) フェイク aapt2 が stderr に警告を出しつつ正常出力(case f と同じ内容)→ `exit 0`
- 7.1-2: `ANDROID_HOME` が build-tools の無い既存ディレクトリ、`local.properties` が正しいフェイク SDK → `exit 0`(case f の出力で)
- 7.2-1: `debugPrintThrottled('z');` が P1 に当たる
- 7.3: `import\n  'package:health_pixcel/data/health_connect_repository.dart';`(2 行に分割)が L7 に、`import\n  '../a.dart';` が L8 に当たる
- §5 の既存ケース(5.1〜5.4)を全部再実行し、退行が無いこと
