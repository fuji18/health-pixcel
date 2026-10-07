# 要求: Flutter プロジェクト生成と Android 構成(#3)

## 目的

アプリ本体の土台を作る。以降のチケットはすべてこの Flutter プロジェクトの上に積む。PRD F1(読み取り権限は `READ_STEPS` / `READ_SLEEP` のみ)と「セキュリティ・プライバシー(最重要)」の INTERNET 権限除去を、マニフェストの段階で満たす。

## スコープ

- `flutter create`(Android のみ)で生成し、Android パッケージを `io.github.fuji18.healthpixcel` に揃える
- 上書きされた `README.md` / `.gitignore` を戻し、`analysis_options.yaml` を規約どおりに書き直す
- `minSdk 34`
- main / release の `AndroidManifest.xml` を設計どおりに書く
- `MainActivity` を `FlutterFragmentActivity` 継承にする(MethodChannel は #9)
- `pubspec.yaml` に `health` / `flutter_riverpod` / `intl` を追加し、`pubspec.lock` をコミットする
- 生成サンプルを、空の `MaterialApp` を出す最小構成とその起動テストに置き換える

## スコープ外

- `scripts/check-*.sh`(#4)/ ドメイン・データ層・画面(#5 以降)/ MethodChannel(#9)
- `initializeDateFormatting`・`launchActionProvider` による画面選択(画面を作るチケットで足す)

## 受け入れ条件

- [ ] `flutter analyze` / `dart format --output=none --set-exit-if-changed .` / `flutter test` が devcontainer で通る
- [ ] CI の `quality` ジョブ(format / analyze / test / リリースビルド)が通る
- [ ] main のマニフェストのヘルスコネクト権限が `READ_STEPS` / `READ_SLEEP` の 2 つだけ
- [ ] release のマニフェストに `INTERNET` の `tools:node="remove"` がある
- [ ] パッケージ名が `io.github.fuji18.healthpixcel` に揃っている(Gradle と Kotlin)
- [ ] `README.md` が `flutter create` 前の内容のまま
- [ ] `pubspec.lock` がコミットされている

## 根拠

- `docs/repository-structure.md`「Flutter プロジェクトの生成手順」「android/」「除外設定」
- `docs/architecture.md`「テクノロジースタック」「MainActivity」「AndroidManifest の構成」
- `docs/development-guidelines.md`「analysis_options.yaml」
