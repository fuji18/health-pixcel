# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
以下の技術的理由に該当する場合のみスキップ可能:
- 実装方針の変更により、機能自体が不要になった
- アーキテクチャ変更により、別の実装方法に置き換わった
- 依存関係の変更により、タスクが実行不可能になった

スキップ時は必ず理由を明記:
```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## フェーズ1: 依存の追加

- [x] 追加前の Android プラグイン一覧を控える(`jq -r '.plugins.android[].name' .flutter-plugins-dependencies | sort`)
- [x] `flutter pub add shared_preferences:^2.5.6` と `flutter pub add dev:shared_preferences_platform_interface:^2.4.2` を実行する
- [x] Android プラグインで増えたのが `shared_preferences_android` だけであることを確認する(他が増えていたら停止して報告)。`pubspec.lock` で増えたパッケージ名を控える
  - 結果: Android プラグインは device_info_plus / health / shared_preferences_android(増えたのは shared_preferences_android のみ)。pubspec.lock で増えたのは path_provider_linux / path_provider_platform_interface / path_provider_windows / platform / shared_preferences* / xdg_directories

## フェーズ2: ドメイン

- [x] `lib/domain/models/goals.dart` を新規作成する
- [x] `lib/domain/goal_input.dart` を新規作成する(定数・`parseStepsGoal`・`parseSleepGoal`)
- [x] `test/domain/goal_input_test.dart` を新規作成する(design.md「ユニットテスト」の全ケース)

## フェーズ3: データ層

- [x] `lib/data/goal_repository.dart`(`GoalRepository` / `GoalStorageException`)を新規作成する
- [x] `lib/data/shared_preferences_goal_repository.dart` を新規作成する(import 行の allow コメントを含む)
- [x] `test/fakes/fake_goal_repository.dart` を新規作成する
- [x] `test/data/shared_preferences_goal_repository_test.dart` を新規作成する

## フェーズ4: プロバイダーとコントローラー

- [x] `lib/presentation/providers.dart` に `goalRepositoryProvider` を追加する
- [x] `lib/presentation/goals/goals_controller.dart` を新規作成する
- [x] `test/presentation/goals/goals_controller_test.dart` を新規作成する

## フェーズ5: 画面と導線

- [x] `lib/presentation/goals/goal_settings_screen.dart` を新規作成する
- [x] `lib/presentation/dashboard/dashboard_screen.dart` の AppBar に旗アイコンと遷移を追加する
- [x] `test/presentation/goals/goal_settings_screen_test.dart` を新規作成する
- [x] `test/presentation/dashboard/dashboard_screen_test.dart` に遷移のテストを追記する

## フェーズ6: 検査スクリプト

- [x] `scripts/check-layer-imports.sh` の実装ファイル規則に `shared_preferences_goal_repository` を加える
- [x] `bash scripts/check-privacy.sh` が通り、「privacy-check: allow で除外: 1 件」と出ることを確認する
- [x] `bash scripts/check-layer-imports.sh` が通ることを確認する

## フェーズ7: 品質チェック

- [x] 変更ファイルの `flutter analyze` / `dart format --output=none --set-exit-if-changed .` / `flutter test` が通る

## フェーズ8: ドキュメント更新

- [x] `docs/functional-design.md` を更新する(design.md「ドキュメント更新」の 5 項目)
- [x] `docs/architecture.md` を更新する(2 項目)
- [x] `docs/repository-structure.md` を更新する(4 項目)
- [x] 実装後の振り返り(このファイルの下部に記録。司令塔が担当)

---

## 実装後の振り返り

### 実装完了日
2026-10-11

### 計画と実績の差分

**計画と異なった点**:
- 設計からの差分はなし。fork は 1 回目の実行がユーザー操作で中断され、成果物は残ったが tasklist が未更新のままだった。2 回目は「既存ファイルを design.md と照合してから [x] にする」と指示して再開し、補ったのはテスト 1 件(エラー文言の消去がアニメーション途中だったため `pumpAndSettle()` に変更)とドキュメント更新
- Android プラグインの確認(フェーズ1)は、中断で fork の記録が無かったため司令塔が `.flutter-plugins-dependencies` で実施した

**新たに必要になったタスク**:
- なし

### 学んだこと

- `shared_preferences` は Linux / Windows 実装経由で `path_provider_*` / `xdg_directories` / `platform` を `pubspec.lock` に引き込む。APK に入るかの判定は lock の差分ではなく `.flutter-plugins-dependencies` の `plugins.android` で見るほうが正確
- `SharedPreferencesAsync` はコンストラクタで platform の有無を検査して `StateError` を投げるため、遅延生成にしておくと、目標値を読まないダッシュボード側の既存テストに影響しない
- 依存の審査で pub cache を読むたびに作業ディレクトリ外の読み取り確認が出ていた。`.claude/settings.local.json` の `additionalDirectories` に `~/.pub-cache` と `~/flutter` を足して解消した(ユーザー承認済み)

### 申し送り(検収の Minor 指摘。#23 以降で判断する)

- 睡眠の「時間」「分」欄は `labelText` と `suffixText` が同じ語で、スクリーンリーダーが「時間 時間」と読む可能性がある。実機の TalkBack で確認し、必要ならラベルを「睡眠時間(時間)」などにする(design.md の指定どおりの実装)
- 読み込みに失敗すると目標なしとして画面が開き、その状態で保存すると既存の値を上書きする。読み込み失敗の案内を出すかは、#23 でダッシュボードから読むときに合わせて判断する
- `parseSleepGoal` で分の桁数が極端に多い場合(`tryParse` が null)の文言はテストで固定されていない
- 依存の審査結果と `privacy-check: allow` の理由は PR 本文に記載。CI のリリースビルドと権限検査が緑になるまで完了扱いにしない

### 次回への改善提案

- fork が中断された場合は tasklist と作業ツリーがずれる。再開時は「既存の成果を照合してから [x]」と明示する今回の指示文が有効だった
- #23 は `goalsControllerProvider` をダッシュボードから watch すれば目標値が得られる(本チケットで準備済み)
