# 要求: 技術スタックを Flutter に置き換える(/kickoff フェーズ1)

## 背景

テンプレート既定(Node.js / TypeScript / npm / vitest / eslint / prettier)と、`docs/architecture.md` で確定したスタック(Dart / Flutter、Android)が異なる。放置すると CI が常に赤になり、編集時 hook・lint-staged が無言で空振りする。

## 要求

- 検証コマンドを Flutter 用(`flutter analyze` / `dart format` / `flutter test` / `scripts/check-*.sh`)に置き換える
- Claude Code は devcontainer で動かす(2026-10-06 ユーザー決定)。devcontainer に Flutter SDK を入れ、analyze / format / test をコンテナ内で回せるようにする。実機実行とリリースビルドの実機確認は Windows 側
- ハーネス(husky / secretlint / Claude Code / Codex / Context7)は Node に依存するため、Node と npm は残す
- TS ツールチェーンと `src/` のプレースホルダを撤去する
- CI は `pubspec.yaml` が生成される(最初の実装チケット)までの間も赤くならないこと

## スコープ外

- Flutter プロジェクトの生成(`flutter create`)— 最初の実装チケットで行う
- `scripts/check-*.sh` の実装 — 実装チケットで行う(CI は存在するときだけ実行する)
- Dependabot の monthly 化 — `/kickoff` フェーズ4
