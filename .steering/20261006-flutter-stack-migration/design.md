# 設計: Flutter スタックへの置換

<!-- status: ready -->

## 方針

- **npm の入口は残し、中身を Flutter に向ける。** テンプレート所有の `implementer` エージェントは `package.json` の scripts(`npm run lint` / `npm test` 等)を読んで品質チェックを回す。所有ファイルを書き換えずに済むよう、scripts を Flutter のラッパーにする
- **`pubspec.yaml` が無い間は Flutter の検査をスキップする**(CI・hook とも)。最初の実装チケットで生成されるまで、全 PR が赤になるのを避ける
- **`scripts/check-*.sh` は存在するときだけ実行する**(実装チケットで追加される)

## 変更内容

| ファイル | 変更 |
|---|---|
| `.devcontainer/devcontainer.json` | `name` → `health-pixcel`。`containerEnv` に `PATH` へ `$HOME/flutter/bin` を追加 |
| `.devcontainer/post_create.sh` | Flutter SDK(タグ `3.47.6`)を `$HOME/flutter` に shallow clone し、`flutter precache --no-android --no-ios --no-web ...` 相当の最小構成で初期化。Android SDK は入れない(ビルド・実機は Windows 側) |
| `tsconfig.json` / `vitest.config.ts` / `eslint.config.js` / `src/` | 削除 |
| `package.json` | name・description・keywords をプロダクト用に。scripts を Flutter ラッパーに。devDependencies は husky / lint-staged / secretlint(+preset)/ prettier のみ |
| `package.json` の lint-staged | `*.dart` → `dart format`、`*.{json,md,yml,yaml}` → prettier、`*` → secretlint |
| `.gitignore` | Flutter / Android の除外を追加(`repository-structure.md`「除外設定」)。`*.tsbuildinfo` / `dist/` を削除 |
| `.prettierignore` | `lib/` `test/` `android/` `build/` `.dart_tool/` `pubspec.lock` を追加 |
| `.github/workflows/ci.yml` | `quality` を Flutter 化(`subosito/flutter-action`)。`pubspec.yaml` 不在時はスキップ。secretlint は Node で継続 |
| `.github/dependabot.yml` | `pub` エコシステムを追加。TS の ignore を削除 |
| `.claude/scripts/lint-on-edit.sh` | `*.dart` を対象に `dart analyze <file>` |
| `.claude/settings.json` | PostToolUse を `*.dart` → `dart format`、他 → prettier に。permissions を Flutter 用に |
| `.claude/hooks/session-start.sh` | リモート時に `flutter pub get`(`pubspec.yaml` があり `flutter` があるとき)。serena 規模検知を `*.dart` に |
| `CLAUDE.md` | 技術スタック節を更新。owned ファイルへの Flutter 差分を「プロジェクト固有ルール」に記録 |
| `docs/architecture.md` / `docs/development-guidelines.md` | 「コマンドの実行環境」を devcontainer 実態に更新 |

## package.json scripts

```json
"prepare": "husky",
"lint": "flutter analyze && bash scripts/check-layer-imports.sh && bash scripts/check-privacy.sh",
"format": "dart format .",
"format:check": "dart format --output=none --set-exit-if-changed .",
"test": "flutter test"
```

`scripts/check-*.sh` が未作成の間は `lint` が失敗するため、`[ ! -f ] ||` で存在時のみ実行する形にする。
