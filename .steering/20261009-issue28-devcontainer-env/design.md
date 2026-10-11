# 設計: devcontainer の環境不備(#28)

<!-- status: ready -->

変更は 3 ファイル(+ 司令塔が書く docs / CLAUDE.md)。アプリのコード(`lib/` / `test/`)には触れない。

## §1 Flutter の PATH(`.devcontainer/devcontainer.json`)

### 決定

- `"remoteUser": "vscode"` をトップレベルに**明示する**(`image` の直後)。ベースイメージの既定と同じ値だが、下の PATH がこのユーザーのホームに依存することを宣言として残す
- `remoteEnv.PATH` を次に変える:

  ```json
  "PATH": "/home/vscode/flutter/bin:${containerEnv:PATH}"
  ```

- JSON 内にコメントは書かない(説明は `post_create.sh` の §2 のコメントに置く)

### 理由(remoteUser 非依存の書き方を採らない理由)

- `${containerEnv:HOME}` は `HOME` がイメージの ENV に無いため空になる(今回の原因)。`${localEnv:HOME}` はホスト(Windows)の値で使えない
- Flutter を `/opt` 等の固定パスに入れる案は `sudo` と既存 `~/flutter` の再取得が要り、変更が大きい
- `~/.local/bin` へのシンボリックリンク案は、VS Code の git 拡張が起動する pre-commit の PATH に `~/.local/bin` が入る保証が無い(シェルの profile 由来のため)

## §2 PATH の食い違い検知(`.devcontainer/post_create.sh` の Flutter ステップ)

`"$FLUTTER_HOME/bin/flutter" --version` の直後(`pub get` の前)に次を足す:

```bash
# devcontainer.json の remoteEnv.PATH は /home/vscode/flutter/bin を直書きしている
# (${containerEnv:HOME} はイメージの ENV に HOME が無く空になるため使えない。#28)。
# remoteUser を変えると PATH と FLUTTER_HOME が食い違うので、ここで気づけるようにする。
if [ "$(command -v flutter || true)" != "$FLUTTER_HOME/bin/flutter" ]; then
  echo "  ⚠️  PATH 上の flutter が $FLUTTER_HOME/bin/flutter ではありません。devcontainer.json の remoteEnv.PATH を確認してください。"
fi
```

## §3 git の作成者(`.devcontainer/post_create.sh` に新ステップ)

### 決定

- GitHub 認証ステップ(現 `[4/5]`)の**直後**に新ステップを入れ、全ステップの番号を `/6` に振り直す(Flutter は `[6/6]`)
- 実効値(`git config user.email`)が空のときだけ、`gh api user` から login と id を取り、**リポジトリローカル**(`git config --local`)に設定する。メールは GitHub の noreply 形式
- gh が未認証・API 失敗時は警告と手動コマンドを出して続行する(`set -e` で止めない)

```bash
# git の作成者(コミットに必要)。VS Code の「ホストの .gitconfig をコピー」はホスト側に
# user.* が無いと何も入らない(#28)。メールアドレスをリポジトリにコミットしないため、
# GitHub アカウントから noreply 形式を組み立てる。--global ではなく --local にするのは、
# VS Code がアタッチ時に ~/.gitconfig を書き込むため順序に依存しないようにするため
# (.git/config はワークスペース側にあり、リビルドしても残る)。
echo "[5/6] Setting up git author..."
if [ -n "$(git config user.email || true)" ]; then
  echo "  Already configured: $(git config user.name) <$(git config user.email)>"
elif GH_USER="$(gh api user --jq '"\(.login) \(.id)"' 2>/dev/null)" && [ -n "$GH_USER" ]; then
  read -r GH_LOGIN GH_ID <<< "$GH_USER"
  git config --local user.name "$GH_LOGIN"
  git config --local user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
  echo "  Configured: ${GH_LOGIN} <${GH_ID}+${GH_LOGIN}@users.noreply.github.com>(.git/config)"
else
  echo "  ⚠️  git の作成者を設定できませんでした(gh 未認証)。手動で設定してください:"
  echo "      git config --local user.name <name> && git config --local user.email <email>"
fi
```

- 冒頭の `echo` は他ステップと同じ書式。他ステップの `[n/5]` は `[1/6]`〜`[4/6]`・`[6/6]` に直す

## §4 誤警告(`.claude/hooks/session-start.sh` の実行権限検査)

### 決定

ディスクを見るループの `lib-*.sh` 分岐だけ、`core.fileMode=false` のときは判定しない。非 lib の `! -x` 検査(hook が実際に起動できるか)はディスクが正なので**変えない**。index を見る後段の検査も変えない。

ループの直前に:

```bash
# core.fileMode=false(WSL / Windows マウント経由の devcontainer 等)では、ディスクの
# 実行ビットは git に入らず、マウント次第では外せもしない(drvfs で root 所有・777。#28)。
# lib-*.sh の「付いていてはいけない」はその環境では意味を持たないので、下の index 検査だけを正とする。
# 非 lib の「付いていなければならない」はディスクが正(hook が実際に起動できるか)なので常に見る。
FILEMODE="$(git config --get core.fileMode 2>/dev/null || echo true)"
```

`lib-*.sh)` 分岐の条件を `if [ "$FILEMODE" != "false" ] && [ -x "$s" ]; then` に変える。

- `git` が無い環境では `|| echo true` で従来どおりディスクを見る

## §5 docs / CLAUDE.md

- `docs/architecture.md` 開発環境の箇条に、PATH と git 作成者の扱いを 1 行足す(**司令塔が計画時に更新済み**)
- `CLAUDE.md`「テンプレート所有ファイルへの Flutter 差分」の `session-start.sh` 項の行末(`*.dart`)の直後に、次をそのまま足す(**fork が書く**):

  ```
  、`lib-*.sh` のディスク実行ビット検査を `core.fileMode=false` で飛ばす分岐(Windows マウントでの誤警告対策。#28)
  ```

## 完了条件

1. `bash -n .devcontainer/post_create.sh` / `bash -n .claude/hooks/session-start.sh` が通る
2. `jq . .devcontainer/devcontainer.json` が通る(JSON として正しい)
3. `bash .claude/hooks/session-start.sh < /dev/null 2>/dev/null | grep 'source 専用ライブラリ'` が**何も出さない**(この環境は `core.fileMode=false`)
4. `npm run lint` / `npm run format:check` / `npm test` が通る(アプリは変えていないので回帰確認)
5. §3 のブロックだけを一時スクリプトに切り出して実行はしない(`.git/config` を書き換えるため)。ロジックは目視で確認する

devcontainer の再ビルド後の確認(`which dart` / `git commit`)は devcontainer の外からしかできないため、ユーザーに依頼する(PR 本文に手順を書く)。

## 決定事項(判断の記録)

- テンプレート還元: `session-start.sh` の §4 はテンプレートにも有効(Windows マウントは一般的)。このプロジェクトには `docs/template-dev/CHANGELOG.md` が無いため、PR には `no-changelog` ラベルを付け、PR 本文に還元候補として書く

## §9 検収指摘の対応(code-reviewer 1 巡: critical 0 / major 1 / minor 4)

- 採用(major): `core.fileMode` が `False` / `no` / `0` 等のとき誤警告が復活する → `git config --type=bool --get` で正規化する
- 採用(minor): `user.email` だけ空で `user.name` が設定済みのとき、name を gh の login で上書きしていた → name は空のときだけ設定する
- 見送り: git リポジトリ外での `git config --local` 失敗(postCreateCommand はワークスペース直下で走る)/ Codespaces の 403(警告分岐に落ちて止まらない)/ `remoteEnv` が VS Code 経由のプロセスにしか効かない点(設計どおり。CLAUDE.md の前提も VS Code 経由)
- 再ビルド後の確認項目に「post_create のログに PATH 食い違いの警告が出ないこと」を加える(lifecycle コマンドに remoteEnv が効いている確認を兼ねる)
