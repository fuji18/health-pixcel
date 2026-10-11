# 要求: devcontainer の環境不備(#28)

## 背景

#20(PR #27)の作業中に、devcontainer の環境が原因の失敗・警告が 3 件出た。毎回手作業で回避しているため、環境側で直す。

## 要求

1. **git の作成者**: コンテナ内で `git commit` が `Author identity unknown` で失敗しない。メールアドレスをリポジトリにコミットしない
2. **Flutter の PATH**: `export` なしで `dart` / `flutter` が PATH にあり、pre-commit(lint-staged の `dart format`)が通る
3. **誤警告**: SessionStart hook が `lib-*.sh` の実行権限警告を出さない(index 上は正しく `100644`。Windows ドライブの 9p/drvfs マウントでディスク上だけ `rwxrwxrwx` になる)

## 受け入れ条件(Issue #28)

- devcontainer 再ビルド後、`export` なしで `git commit` が pre-commit を通って成功する
- SessionStart hook で `lib-*.sh` の実行権限警告が出ない
- CI(harness-integrity を含む)が緑

## スコープ外

- アプリのコード変更
- テンプレートリポジトリへの還元そのもの(PR 本文で還元候補として挙げるだけ)

## 調査で確定した事実

- `remoteEnv.PATH` の `${containerEnv:HOME}` は、`HOME` がコンテナの環境変数(イメージの ENV)に無いため空に展開され、`/flutter/bin` が入っている
- `git config --get-regexp 'user\.'` は空。VS Code の「ホストの .gitconfig をコピー」では作成者が入っていない
- 既存コミットの作成者は `fuji18 <109528067+fuji18@users.noreply.github.com>` = GitHub の noreply 形式(`<id>+<login>@users.noreply.github.com`)
- `core.fileMode=false`。`lib-*.sh` は root 所有で、コンテナのユーザー(vscode)からは `chmod` で外せない前提で扱う
