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

- [ ] 追加前の Android プラグイン一覧を控える(`jq -r '.plugins.android[].name' .flutter-plugins-dependencies | sort`)
- [ ] `flutter pub add shared_preferences:^2.5.6` と `flutter pub add dev:shared_preferences_platform_interface:^2.4.2` を実行する
- [ ] Android プラグインで増えたのが `shared_preferences_android` だけであることを確認する(他が増えていたら停止して報告)。`pubspec.lock` で増えたパッケージ名を控える

## フェーズ2: ドメイン

- [ ] `lib/domain/models/goals.dart` を新規作成する
- [ ] `lib/domain/goal_input.dart` を新規作成する(定数・`parseStepsGoal`・`parseSleepGoal`)
- [ ] `test/domain/goal_input_test.dart` を新規作成する(design.md「ユニットテスト」の全ケース)

## フェーズ3: データ層

- [ ] `lib/data/goal_repository.dart`(`GoalRepository` / `GoalStorageException`)を新規作成する
- [ ] `lib/data/shared_preferences_goal_repository.dart` を新規作成する(import 行の allow コメントを含む)
- [ ] `test/fakes/fake_goal_repository.dart` を新規作成する
- [ ] `test/data/shared_preferences_goal_repository_test.dart` を新規作成する

## フェーズ4: プロバイダーとコントローラー

- [ ] `lib/presentation/providers.dart` に `goalRepositoryProvider` を追加する
- [ ] `lib/presentation/goals/goals_controller.dart` を新規作成する
- [ ] `test/presentation/goals/goals_controller_test.dart` を新規作成する

## フェーズ5: 画面と導線

- [ ] `lib/presentation/goals/goal_settings_screen.dart` を新規作成する
- [ ] `lib/presentation/dashboard/dashboard_screen.dart` の AppBar に旗アイコンと遷移を追加する
- [ ] `test/presentation/goals/goal_settings_screen_test.dart` を新規作成する
- [ ] `test/presentation/dashboard/dashboard_screen_test.dart` に遷移のテストを追記する

## フェーズ6: 検査スクリプト

- [ ] `scripts/check-layer-imports.sh` の実装ファイル規則に `shared_preferences_goal_repository` を加える
- [ ] `bash scripts/check-privacy.sh` が通り、「privacy-check: allow で除外: 1 件」と出ることを確認する
- [ ] `bash scripts/check-layer-imports.sh` が通ることを確認する

## フェーズ7: 品質チェック

- [ ] 変更ファイルの `flutter analyze` / `dart format --output=none --set-exit-if-changed .` / `flutter test` が通る

## フェーズ8: ドキュメント更新

- [ ] `docs/functional-design.md` を更新する(design.md「ドキュメント更新」の 5 項目)
- [ ] `docs/architecture.md` を更新する(2 項目)
- [ ] `docs/repository-structure.md` を更新する(4 項目)
- [ ] 実装後の振り返り(このファイルの下部に記録。司令塔が担当)

---

## 実装後の振り返り

### 実装完了日
{YYYY-MM-DD}

### 計画と実績の差分

**計画と異なった点**:
-

**新たに必要になったタスク**:
-

### 学んだこと

-

### 次回への改善提案

-
