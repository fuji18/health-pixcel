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

## フェーズ0: PRD(司令塔が実施済み)

- [x] PRD「セキュリティ・プライバシー」に `READ_EXERCISE` / `READ_DISTANCE` / `READ_TOTAL_CALORIES_BURNED` の理由を追記してコミットする(e9d0fc8)

## フェーズ1: 権限宣言

- [ ] `AndroidManifest.xml` に 3 つの権限を追加する(design.md §13)
- [ ] `scripts/check-release-permissions.sh` の許可リストに追加する(§14)

## フェーズ2: ドメイン

- [ ] `HealthMetric.exercise` を追加する(§1)
- [ ] `ExerciseSession` / `DailyExercise` を作り、テストを書く(§2〜3)
- [ ] `assignExerciseToDays` を作り、テストを書く(§4。日をまたぐ記録のケースを必ず含める)

## フェーズ3: データ層・アプリケーション層

- [ ] `HealthRepository.readExerciseSessions` を追加する(§5)
- [ ] `HealthConnectRepository` の型対応を 1 種別 = 複数型にし、`readExerciseSessions` を足し、テストを追加・更新する(§6)
- [ ] `FakeHealthRepository` を更新する(テスト設計)
- [ ] `WeeklySummaryService.loadExercise` を追加し、テストを書く(§7)

## フェーズ4: 状態と画面

- [ ] `DashboardReady.exercise` と `isAllEmpty` の拡張、テストを追加する(§8)
- [ ] `DashboardController` を 5 種に対応させ、テストを追加する(§9)
- [ ] `ExerciseSection` を作る(§10)
- [ ] `DashboardScreen` に運動セクションを足し、権限なしの文言を変える。画面テストを追加する(§11)
- [ ] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§12)

## フェーズ5: 品質チェック

- [ ] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [ ] `docs/functional-design.md` に運動記録を反映する(A6 として帰属日判定を追加、権限・型の対応、表示)
- [ ] 権限・データ種別を列挙している他の `docs/`(architecture / glossary / repository-structure / development-guidelines)を更新する
- [ ] 振り返りを記入する

## 申し送り
