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

- [x] `AndroidManifest.xml` に `READ_HEART_RATE` を追加する(design.md §14)
- [x] `scripts/check-release-permissions.sh` の許可リストに追加する(§15)

## フェーズ2: ドメイン

- [x] `HealthMetric` / `HealthPermissions` を追加し `PermissionStatus` を削除する。等価性のテストを書く(§1)
- [x] `HeartRateStats` / `DailyHeartRate` / `summarizeHeartRate` を作り、テストを書く(§2〜4)
- [x] `formatBpm` / `formatBpmRange` を追加し、テストを書く(§5)

## フェーズ3: データ層・アプリケーション層

- [x] `HealthRepository` の権限の型を `HealthPermissions` にし、`readHeartRate` を追加する(§6)
- [x] `HealthConnectRepository` を 3 種の権限と `readHeartRate` に対応させ、テストを追加・更新する(§7)
- [x] `FakeHealthRepository` を更新する(テスト設計)
- [x] `WeeklySummaryService.loadHeartRate` を追加し、テストを書く(§8)

## フェーズ4: 状態と画面

- [x] `DashboardReady.heartRate` と `isAllEmpty` の拡張、テストを追加する(§9)
- [x] `DashboardController` を 3 種に対応させ、既存テストの置き換えと追加テストを書く(§10)
- [x] `HeartRateSection` を作る(§11)
- [x] `DashboardScreen` に心拍セクションを足し、権限なしの文言を変える。画面テストを追加する(§12)
- [x] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§13)

## フェーズ5: 品質チェック

- [x] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [x] `docs/functional-design.md` に心拍と `HealthPermissions` を反映する
- [x] `docs/architecture.md`(マニフェスト・最小権限・機能拡張性)と、権限を列挙している `docs/development-guidelines.md` / `docs/repository-structure.md` を更新する
- [x] 振り返りを記入する(`docs/glossary.md` の権限状態も更新した)

## 申し送り

### 実装の結果

- 実装は `implement-ticket`(Sonnet fork)で 1 往復。全フェーズを完了し 243 件通過。design.md との差異なし
- 検収(code-reviewer)は Must 0 / Should 3 / Nit 3。コード変更が要る指摘はなかった
- 既存の画面テスト 5 件は、心拍セクションの追加で日付ラベル・「記録なし」の件数が増えたため期待値だけを増やした

### 申し送り(実機確認 #10 などで判断する)

- **実機(Pixel 10)で心拍が表示されることの確認は未実施**(受け入れ条件。Windows 側で行う)
- 30 日表示では 1 日 1 回 × 30 回の `getHealthDataFromTypes` を並行に発行する。ウォッチ連携で標本が多い端末で重ければ、並行数を絞るか区間をまとめて読む方式を検討する(PRD の 3 秒 / 2 秒の目安)
- 標本の区間判定は `dateFrom` のみ。`health` 13.3.2 の HEART_RATE は標本ごとに `dateFrom == dateTo` のため問題ないはずだが、実機で日またぎの値がずれていないか見る
- 心拍セクションの「記録なし」は `Flexible` で包んでいない(日付ラベルが `Expanded` で縮むため通常は問題なし)
- `dashboard_screen.dart` の import 順(`heart_rate_section.dart` が末尾寄り)。lint は通る

### 次回への改善提案

- #25(体重)・#26(運動記録)は `HealthMetric` に列挙値を足し、`HealthConnectRepository._types`・`load*`・`DashboardReady`・セクションを横展開する。参照実装が揃ったので Codex 委託の候補になる(ただしマニフェスト・`scripts/` は委託禁止領域のため、その 2 行は司令塔か fork が書く)
