# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

```
CI quality ジョブ
  flutter build apk --release
  bash scripts/check-release-permissions.sh   (既存)
  bash scripts/report-apk-size.sh             (新規) → 標準出力(Markdown)をログとジョブサマリーへ
                                                         exit 1(目安超過)は ::warning:: に変換。CI は落とさない
```

`scripts/report-apk-size.sh` は既存の `scripts/check-*.sh` と同じく POSIX シェル(`#!/bin/sh` / `set -eu`)で書き、ubuntu(CI)と Git Bash(Windows)の両方で動かす。**参照実装は `scripts/check-release-permissions.sh`**(冒頭コメント・`SCRIPT_DIR` / `ROOT` / `CHECK_ROOT` の解決・`APK` 変数・`exit 2` の形)。

## 決定事項

| 項目 | 決定 |
|---|---|
| 測る対象 | CI が作る fat APK(`build/app/outputs/flutter-apk/app-release.apk`)。追加のビルド(`--split-per-abi`)はしない |
| 主指標 | **arm64-v8a 相当サイズ** = APK のファイルサイズ −(`lib/arm64-v8a/` 以外の `lib/<abi>/` 配下エントリの圧縮後サイズの合計)。Pixel 10 は arm64 で、ABI 分割した APK のサイズに近い値になる |
| 目安(初期値) | arm64-v8a 相当で **25MB 以下**。スクリプト冒頭の定数 `BUDGET_MB=25` に置く。CI の実測後に司令塔が見直す(tasklist フェーズ3) |
| 単位 | MB = 1,048,576 バイト(`flutter build` の出力と同じ)。表示は小数 1 桁。比較用にバイト数も出す |
| 超過時 | `exit 1`(目安超過)。CI では警告のみ(`::warning::`)で、ジョブは落とさない。目安は厳密な制約ではないため |
| 依存追加時の増加確認 | CI のジョブサマリーを main の最新 CI 実行と見比べる手順を docs に書く(自動差分はしない) |

## `scripts/report-apk-size.sh` の仕様

### 入出力

- 引数なし。対象は `APK=build/app/outputs/flutter-apk/app-release.apk`(`ROOT` 基準。`check-release-permissions.sh` と同じ解決)
- 標準出力: Markdown(下の出力例)。CI ではそのままジョブサマリーに追記する
- 終了コード: `0` = 目安以内 / `1` = 目安超過 / `2` = 検査不能
- 鮮度検査はしない(報告用のため。権限検査側が鮮度を見ている)

### 処理

1. APK が無ければ stderr に `リリース APK がありません: $APK。先にリリースビルドを実行してください(flutter build apk --release)` を出して `exit 2`
2. `command -v unzip` が無ければ stderr に `unzip が見つかりません` を出して `exit 2`
3. 全体サイズ: `wc -c < "$APK"`(前後の空白を `tr -d ' '` で除く)
4. エントリ一覧: `unzip -v "$APK"` を `awk` で読む。データ行は `NF >= 8 && $1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/` を満たす行。`$3` = 圧縮後サイズ、名前 = 第 8 フィールド以降を空白で連結したもの(ヘッダ・区切り線・末尾の合計行はこの条件で落ちる)
5. 各エントリを次の順で最初に一致した区分に振り分け、区分ごとに `$3` を合計する(1 回の `awk` で全区分を集計する):

   | 区分(表示名) | 一致条件(名前) |
   |---|---|
   | `Dart AOT(<abi>)` | `lib/<abi>/libapp.so` |
   | `Flutter エンジン(<abi>)` | `lib/<abi>/libflutter.so` |
   | `その他ネイティブ(<abi>)` | `lib/<abi>/` 配下のそれ以外 |
   | `Flutter アセット` | `assets/flutter_assets/` で始まる |
   | `DEX` | `classes*.dex`(ルート直下) |
   | `リソース` | `res/` で始まる、または `resources.arsc` |
   | `その他` | 上のいずれでもない(`META-INF/`・`AndroidManifest.xml`・`kotlin/` 等) |

   `<abi>` は `lib/` の次のパス要素(`arm64-v8a` / `armeabi-v7a` / `x86_64` 等)。ABI 名を決め打ちしない
6. `lib/arm64-v8a/` のエントリが 1 つも無ければ stderr に `arm64-v8a のネイティブライブラリがありません` を出して `exit 2`
7. arm64-v8a 相当 = 全体サイズ −(ABI が `arm64-v8a` 以外の `lib/` 区分の合計)
8. 出力(下の例)を標準出力に出す。表の行順: ABI ごとの 3 区分(ABI 名の昇順、各 ABI 内は Dart AOT → Flutter エンジン → その他ネイティブ。合計 0 の区分は出さない)→ Flutter アセット → DEX → リソース → その他。区分の値はすべて**圧縮後サイズ**
9. arm64-v8a 相当が `BUDGET_MB` を超えていれば(MB 換算後の比較は `awk` で行う。小数の比較をシェルでしない)stderr に `arm64-v8a 相当サイズ X MB が目安 25 MB を超えています(docs/architecture.md「パフォーマンス要件」)` を出して `exit 1`。超えていなければ `exit 0`

### 出力例(数値は例)

```markdown
### リリース APK サイズ

| 項目 | MB | バイト |
|---|---:|---:|
| APK 全体(fat) | 48.4 | 50749440 |
| **arm64-v8a 相当**(目安 25 MB 以下) | **20.1** | 21076992 |

内訳(圧縮後サイズ):

| 区分 | MB | バイト |
|---|---:|---:|
| Dart AOT(arm64-v8a) | 5.2 | 5452595 |
| Flutter エンジン(arm64-v8a) | 10.6 | 11114905 |
| Dart AOT(armeabi-v7a) | 4.6 | ... |
| ... | | |
| Flutter アセット | 0.3 | ... |
| DEX | 2.1 | ... |
| リソース | 0.6 | ... |
| その他 | 0.1 | ... |
```

### 冒頭コメントと定数

```sh
#!/bin/sh
# リリース APK のサイズと内訳を Markdown で出す。終了コード: 0=目安以内 / 1=目安超過 / 2=検査不能
# 仕様: docs/repository-structure.md「scripts/(アプリの検証スクリプト)」
set -eu
...
# 目安(arm64-v8a 相当、MB)。変えるときは docs/architecture.md「パフォーマンス要件」も合わせて直す
BUDGET_MB=25
APK=build/app/outputs/flutter-apk/app-release.apk
```

## CI(`.github/workflows/ci.yml`)の変更

`Release permission check` ステップの直後(`Dependency audit (harness)` の前)に追加する。他のステップは変えない。

```yaml
      # 目安(docs/architecture.md「パフォーマンス要件」)を超えても PR は止めない。依存追加時の比較用に内訳をジョブサマリーへ出す
      - name: Release APK size report
        if: steps.flutter.outputs.present == 'true'
        run: |
          rc=0
          bash scripts/report-apk-size.sh > "$RUNNER_TEMP/apk-size.md" || rc=$?
          cat "$RUNNER_TEMP/apk-size.md"
          cat "$RUNNER_TEMP/apk-size.md" >> "$GITHUB_STEP_SUMMARY"
          case "$rc" in
            0) ;;
            1) echo "::warning::リリース APK の arm64-v8a 相当サイズが目安を超えています(docs/architecture.md「パフォーマンス要件」)" ;;
            *) exit "$rc" ;;
          esac
```

## ドキュメントの変更(フェーズ2 は実装者、フェーズ3 は司令塔)

- `docs/repository-structure.md`「scripts/(アプリの検証スクリプト)」: 配置ファイルの木に `report-apk-size.sh   # リリース APK のサイズと内訳を出す(目安超過は警告)` を追加し、`check-layer-imports.sh` の仕様の後に「`report-apk-size.sh` の仕様」節(上の「入出力」「処理」を箇条書きで要約。区分の表は含める)を足す
- `docs/development-guidelines.md`:
  - 「プルリクエストプロセス > 作成前のチェック」に `- [ ] 依存を追加・更新した場合: CI のジョブサマリー「リリース APK サイズ」の arm64-v8a 相当を main の最新 CI 実行と比べ、増加量を PR 本文に書く(main の値は `gh run list --branch main --workflow ci.yml --limit 1` の実行のサマリーで見る)` を、権限検査の行の直後に追加する
  - 「品質の自動化」の CI コードブロック末尾に `bash scripts/report-apk-size.sh   # サイズの内訳をジョブサマリーへ(目安超過は警告のみ)` を追加する
- `docs/architecture.md`「パフォーマンス要件 > リソース使用量」の APK サイズ行は**司令塔が CI 実測後に書く**(実装者は触らない)

## 検証方法(実装者)

devcontainer には Android SDK が無くリリースビルドできないため、偽の APK(zip)で確かめる。作業ファイルはリポジトリ外(`mktemp -d`)に置き、終わったら消す。

1. `python3` の `zipfile` で、次のエントリを持つ zip を作る(`ZIP_STORED` と `ZIP_DEFLATED` を混ぜる): `lib/arm64-v8a/libapp.so`・`lib/arm64-v8a/libflutter.so`・`lib/armeabi-v7a/libapp.so`・`lib/x86_64/libflutter.so`・`lib/x86_64/libdatastore_shared_counter.so`・`assets/flutter_assets/AssetManifest.bin`・`classes.dex`・`classes2.dex`・`res/a.xml`・`resources.arsc`・`AndroidManifest.xml`・`META-INF/MANIFEST.MF`(中身は `os.urandom` で数百 KB〜数 MB)
2. `CHECK_ROOT=<tmp>` で、`<tmp>/build/app/outputs/flutter-apk/app-release.apk` に置いて実行し、区分ごとの合計と arm64-v8a 相当が `unzip -v` の値と手計算で一致すること、`exit 0` を確認する
3. `BUDGET_MB` を超える大きさの偽 APK で `exit 1` と stderr のメッセージを確認する(定数を書き換えずに済むよう、arm64 側に十分大きい `ZIP_STORED` エントリを入れる)
4. APK 無し → `exit 2`、`lib/arm64-v8a/` 無し → `exit 2` を確認する
5. `sh -n scripts/report-apk-size.sh`(構文)。`shellcheck` があれば通す(無ければ省略してよい)
6. CI ステップの YAML は `python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/ci.yml"))'` で構文を確認する(PyYAML が無ければ省略してよい)

スクリプトのテストはリポジトリにコミットしない(既存の `scripts/check-*.sh` と同じ扱い)。

## 検収指摘による追加(code-reviewer 1 回目。Should 1〜4 を採用)

1. `scripts/report-apk-size.sh` を git 上でも実行可能にする: `git add --chmod=+x scripts/report-apk-size.sh`(他の `check-*.sh` は 100755)。コミットは司令塔が行うので、index への反映までで止める
2. `unzip -v` の失敗(壊れた APK、警告での終了コード 1 を含む)を `exit 2` に寄せる。`ENTRIES=$(unzip -v "$APK") || { echo "unzip -v に失敗しました: $APK" >&2; exit 2; }`。CI では終了コード 1 が「目安超過」の警告に化けるため
3. `TOTAL=$(wc -c <"$APK" | tr -d ' ')` も同様に失敗時 `exit 2`(`|| { echo "APK のサイズを取得できません: $APK" >&2; exit 2; }`)。awk による集計(`SUMMARY=...` / `OTHER_ABI=...`)も同じ形で失敗時 `exit 2` にする。**`exit 1` を返すのは手順 9 の目安超過だけ**、という不変条件を守る
4. `docs/repository-structure.md` の `report-apk-size.sh` の仕様に「`unzip` が要る。Windows の Git Bash に無い場合は CI のジョブサマリーで見る(ローカルでの実行は任意)」の 1 行を足す

検証: 壊れた APK(`printf 'not a zip' > app-release.apk`)で `exit 2` になること、既存の偽 APK の確認(exit 0 / 1 / 2)が引き続き通ること。
