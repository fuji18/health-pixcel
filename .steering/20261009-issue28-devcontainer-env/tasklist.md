# タスクリスト: devcontainer の環境不備(#28)

## 計画(司令塔)

- [x] `docs/architecture.md` を更新する(design §5)

## 実装(implement-ticket)

- [x] `.devcontainer/devcontainer.json` に `remoteUser` を明示し `remoteEnv.PATH` を直す(design §1)
- [x] `.devcontainer/post_create.sh` に git 作成者ステップと PATH 食い違い検知を足し、ステップ番号を `/6` に振り直す(design §2・§3)
- [x] `.claude/hooks/session-start.sh` の `lib-*.sh` ディスク検査を `core.fileMode=false` で飛ばす(design §4)
- [x] `CLAUDE.md` の `session-start.sh` 項に差分を足す(design §5)
- [x] 完了条件の 1〜4 を通す(design「完了条件」)

## 申し送り

- 実装完了: 2026-10-11。fork 1 往復で設計どおり完了。検収は code-reviewer 1 巡(critical 0 / major 1 / minor 4)。major 1 件と minor 1 件を司令塔が直接反映(design §9)。test-runner はアプリ無変更かつ fork がフルスイート(148 件)を通したため省略
- 未確認: devcontainer 再ビルド後の `which dart` / `export` なしの `git commit` / post_create の git 作成者ステップ(コンテナの外からしかできない。PR 本文の手順でユーザーが確認する)
- 学んだこと: devcontainer の `${containerEnv:VAR}` はイメージの ENV にある変数しか展開できない(`HOME` は ENV に無い)。drvfs マウントではディスクの実行ビットが git の事実を表さないため、権限検査は index を正にする
- テンプレート還元候補: `session-start.sh` の `core.fileMode=false` 分岐(このプロジェクトには docs/template-dev/CHANGELOG.md が無いため no-changelog で出す)
