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

- [x] PRD「セキュリティ・プライバシー」に `READ_HEART_RATE` の理由を追記してコミットする(528fa0d)

## フェーズ1: 権限宣言

- [ ] `AndroidManifest.xml` に `READ_HEART_RATE` を追加する(design.md §14)
- [ ] `scripts/check-release-permissions.sh` の許可リストに追加する(§15)

## フェーズ2: ドメイン

- [ ] `HealthMetric` / `HealthPermissions` を追加し `PermissionStatus` を削除する。等価性のテストを書く(§1)
- [ ] `HeartRateStats` / `DailyHeartRate` / `summarizeHeartRate` を作り、テストを書く(§2〜4)
- [ ] `formatBpm` / `formatBpmRange` を追加し、テストを書く(§5)

## フェーズ3: データ層・アプリケーション層

- [ ] `HealthRepository` の権限の型を `HealthPermissions` にし、`readHeartRate` を追加する(§6)
- [ ] `HealthConnectRepository` を 3 種の権限と `readHeartRate` に対応させ、テストを追加・更新する(§7)
- [ ] `FakeHealthRepository` を更新する(テスト設計)
- [ ] `WeeklySummaryService.loadHeartRate` を追加し、テストを書く(§8)

## フェーズ4: 状態と画面

- [ ] `DashboardReady.heartRate` と `isAllEmpty` の拡張、テストを追加する(§9)
- [ ] `DashboardController` を 3 種に対応させ、既存テストの置き換えと追加テストを書く(§10)
- [ ] `HeartRateSection` を作る(§11)
- [ ] `DashboardScreen` に心拍セクションを足し、権限なしの文言を変える。画面テストを追加する(§12)
- [ ] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§13)

## フェーズ5: 品質チェック

- [ ] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [ ] `docs/functional-design.md` に心拍と `HealthPermissions` を反映する
- [ ] `docs/architecture.md`(マニフェスト・最小権限・機能拡張性)と、権限を列挙している `docs/development-guidelines.md` / `docs/repository-structure.md` を更新する
- [ ] 振り返りを記入する
