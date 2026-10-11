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

## フェーズ1: ドメイン

- [ ] `lib/domain/goal_progress.dart` を作る(design.md §1)
- [ ] `test/domain/goal_progress_test.dart` を作る(境界値を含む。design.md「テスト設計」)
- [ ] `lib/domain/trend_summary.dart` の要約 2 関数に目標の任意引数を足し、`test/domain/trend_summary_test.dart` にテストを追加する(§2-1)

## フェーズ2: ウィジェット

- [ ] `TrendBarChart` に `goalY` を足し、目標ラインを描く。`trend_bar_chart_test.dart` にテストを追加する(§3)
- [ ] `GoalMark` を作る(§4)
- [ ] `StepsSection` に目標の表示・ライン・マークを足す(§5)
- [ ] `SleepSection` に目標の表示・ライン・マークを足す(§6)

## フェーズ3: 画面の配線

- [ ] `DashboardScreen` で `goalsControllerProvider` を watch して各セクションへ渡す(§7)
- [ ] `test/app_test.dart` と `dashboard_screen_test.dart` の overrides に `FakeGoalRepository` を足す
- [ ] `dashboard_screen_test.dart` に目標表示・即時反映のテストを追加する(テスト設計 1〜5 と読み上げ)

## フェーズ4: 品質チェック

- [ ] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ5: ドキュメント(司令塔が行う。実装者は触らない)

- [ ] `docs/functional-design.md` に達成状況の表示を反映する
- [ ] 振り返りを記入する

## 申し送り

(振り返り時に記入)
