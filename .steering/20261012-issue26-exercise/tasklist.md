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

- [x] `AndroidManifest.xml` に 3 つの権限を追加する(design.md §13)
- [x] `scripts/check-release-permissions.sh` の許可リストに追加する(§14)

## フェーズ2: ドメイン

- [x] `HealthMetric.exercise` を追加する(§1)
- [x] `ExerciseSession` / `DailyExercise` を作り、テストを書く(§2〜3)
- [x] `assignExerciseToDays` を作り、テストを書く(§4。日をまたぐ記録のケースを必ず含める)

## フェーズ3: データ層・アプリケーション層

- [x] `HealthRepository.readExerciseSessions` を追加する(§5)
- [x] `HealthConnectRepository` の型対応を 1 種別 = 複数型にし、`readExerciseSessions` を足し、テストを追加・更新する(§6)
- [x] `FakeHealthRepository` を更新する(テスト設計)
- [x] `WeeklySummaryService.loadExercise` を追加し、テストを書く(§7)

## フェーズ4: 状態と画面

- [x] `DashboardReady.exercise` と `isAllEmpty` の拡張、テストを追加する(§8)
- [x] `DashboardController` を 5 種に対応させ、テストを追加する(§9)
- [x] `ExerciseSection` を作る(§10)
- [x] `DashboardScreen` に運動セクションを足し、権限なしの文言を変える。画面テストを追加する(§11)
- [x] `PermissionRationaleScreen` の文言を変え、テストを追従させる(§12)

## フェーズ5: 品質チェック

- [x] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ6: ドキュメント(司令塔が行う。実装者は触らない)

- [x] `docs/functional-design.md` に運動記録を反映する(A6 として帰属日判定を追加、権限・型の対応、表示)
- [x] 権限・データ種別を列挙している他の `docs/`(architecture / glossary / repository-structure / development-guidelines)を更新する
- [x] 振り返りを記入する

## 申し送り

### 実装の結果

- 計画中に `health` 13.3.2 の制約を発見した。WORKOUT を読むと、記録ごとに距離・消費カロリー・歩数を権限確認なしで読み、どれかが未許可だと例外を握りつぶして空を返す。ユーザーの判断で、自前の Kotlin 実装ではなく `READ_DISTANCE` / `READ_TOTAL_CALORIES_BURNED` を追加宣言する案を採った。運動の許可は 4 型すべての許可を条件にした
- 実装は `implement-ticket`(Sonnet fork)で 1 往復。全フェーズを完了し 301 件通過。design.md との差異なし
- 検収(code-reviewer)は Must 0 / Should 3 / Nit 3。2.0 倍の overflow テスト(画面テスト 42)があることを確認した。コードの変更が要る指摘はなかった

### 申し送り(実機確認 #10 などで判断する)

- **実機で運動記録が表示されることの確認は未実施**(受け入れ条件。Windows 側で行う)。権限画面に 7 型が並ぶこと、距離・消費カロリーを外すと運動だけが未許可の案内になることもあわせて見る
- 書き込み元が異なる重なった運動記録(例: HUAWEI と Pixel Watch の両方)は二重に数える(同一の開始・終了だけまとめる。睡眠と同じ)
- `checkPermissions` の問い合わせが 4 回から 7 回に増えた(復帰のたびに走る)。体感で遅ければ計測する
- `health` が WORKOUT の付帯読み取りを権限確認つきに改めたら、`READ_DISTANCE` / `READ_TOTAL_CALORIES_BURNED` を外す(PRD に明記済み)

### 次回への改善提案

- 新しいデータ型の計画時は、`health` の Kotlin 側(`HealthDataReader.kt`)でその型の読み取りが他の型を巻き込まないかを先に確認する。今回は計画中に気づけたが、design.md 作成後だと往復になっていた
