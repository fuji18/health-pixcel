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

- [x] PRD「セキュリティ・プライバシー」に `READ_WEIGHT` の理由を追記してコミットする(ef29f48)

## フェーズ1: 権限宣言

- [ ] `AndroidManifest.xml` に `READ_WEIGHT` を追加する(design.md §13)
- [ ] `scripts/check-release-permissions.sh` の許可リストに追加する(§14)

## フェーズ2: ドメイン

- [ ] `HealthMetric.weight` を追加する(§1)
- [ ] `DailyWeight` / `pickLatestWeight` を作り、テストを書く(§2〜3)
- [ ] `formatKg` を追加し、テストを書く(§4)

## フェーズ3: データ層・アプリケーション層

- [ ] `HealthRepository.readLatestWeight` を追加する(§5)
- [ ] `HealthConnectRepository` に体重の型と `readLatestWeight` を足し、テストを追加・更新する(§6)
- [ ] `FakeHealthRepository` を更新する(テスト設計)
- [ ] `WeeklySummaryService.loadWeight` を追加し、テストを書く(§7)

## フェーズ4: 状態と画面

- [ ] `DashboardReady.weight` と `isAllEmpty` の拡張、テストを追加する(§8)
- [ ] `DashboardController` を 4 種に対応させ、テストを追加する(§9)
- [ ] `WeightSection` を作る(§10)
- [ ] `DashboardScreen` に体重セクションを足し、権限なしの文言を変える。画面テストを追加する(§11)
- [ ] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§12)

## フェーズ5: 品質チェック

- [ ] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [ ] `docs/functional-design.md` に体重を反映する
- [ ] 権限・データ種別を列挙している他の `docs/`(architecture / glossary / repository-structure / development-guidelines)を更新する
- [ ] 振り返りを記入する

## 申し送り

(振り返り時に記入)
