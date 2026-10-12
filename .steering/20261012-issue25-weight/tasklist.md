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

- [x] `AndroidManifest.xml` に `READ_WEIGHT` を追加する(design.md §13)
- [x] `scripts/check-release-permissions.sh` の許可リストに追加する(§14)

## フェーズ2: ドメイン

- [x] `HealthMetric.weight` を追加する(§1)
- [x] `DailyWeight` / `pickLatestWeight` を作り、テストを書く(§2〜3)
- [x] `formatKg` を追加し、テストを書く(§4)

## フェーズ3: データ層・アプリケーション層

- [x] `HealthRepository.readLatestWeight` を追加する(§5)
- [x] `HealthConnectRepository` に体重の型と `readLatestWeight` を足し、テストを追加・更新する(§6)
- [x] `FakeHealthRepository` を更新する(テスト設計)
- [x] `WeeklySummaryService.loadWeight` を追加し、テストを書く(§7)

## フェーズ4: 状態と画面

- [x] `DashboardReady.weight` と `isAllEmpty` の拡張、テストを追加する(§8)
- [x] `DashboardController` を 4 種に対応させ、テストを追加する(§9)
- [x] `WeightSection` を作る(§10)
- [x] `DashboardScreen` に体重セクションを足し、権限なしの文言を変える。画面テストを追加する(§11)
- [x] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§12)

## フェーズ5: 品質チェック

- [x] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [x] `docs/functional-design.md` に体重を反映する
- [x] 権限・データ種別を列挙している他の `docs/`(architecture / glossary / repository-structure / development-guidelines)を更新する
- [x] 振り返りを記入する

## 申し送り

### 実装の結果

- 実装は `implement-ticket`(Sonnet fork)で 1 往復。全フェーズを完了し 270 件通過。design.md との差異なし
- 検収(code-reviewer)は Must 0 / Should 0 / Nit 3。コードの変更が要る指摘はなかった
- 既存の画面テストは、体重セクションの追加で日付ラベル・「記録なし」の件数が増えたため期待件数だけを増やした。「歩数だけ未許可」「心拍だけ未許可」のテストは許可セットに `weight` を足した(足さないと「権限を許可する」が 2 つ出るため)

### 申し送り(実機確認 #10 などで判断する)

- **実機で体重が表示されることの確認は未実施**(受け入れ条件。Windows 側で行う)
- 同時刻の体重記録が複数あると、列挙順で後のものを採る。`health` が返す順序は保証されないため、どちらが選ばれるかは決まらない(実害は小さい。Nit)
- 30 日表示では心拍・体重とも 1 日 1 回の読み取りを並行に発行する(#24 の申し送りと同じ。重ければ区間をまとめて読む方式を検討)

### 次回への改善提案

- #26(運動記録)も同じ横展開になる。ただし運動記録は区間を持つセッション(`ExerciseSessionRecord`)で、睡眠に近い日への割り当てが要るため、心拍・体重より design.md の判断が増える
