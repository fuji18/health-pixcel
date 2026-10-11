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

- [x] `lib/domain/goal_progress.dart` を作る(design.md §1)
- [x] `test/domain/goal_progress_test.dart` を作る(境界値を含む。design.md「テスト設計」)
- [x] `lib/domain/trend_summary.dart` の要約 2 関数に目標の任意引数を足し、`test/domain/trend_summary_test.dart` にテストを追加する(§2-1)

## フェーズ2: ウィジェット

- [x] `TrendBarChart` に `goalY` を足し、目標ラインを描く。`trend_bar_chart_test.dart` にテストを追加する(§3)
- [x] `GoalMark` を作る(§4)
- [x] `StepsSection` に目標の表示・ライン・マークを足す(§5)
- [x] `SleepSection` に目標の表示・ライン・マークを足す(§6)

## フェーズ3: 画面の配線

- [x] `DashboardScreen` で `goalsControllerProvider` を watch して各セクションへ渡す(§7)
- [x] `test/app_test.dart` と `dashboard_screen_test.dart` の overrides に `FakeGoalRepository` を足す
- [x] `dashboard_screen_test.dart` に目標表示・即時反映のテストを追加する(テスト設計 1〜5 と読み上げ)

## フェーズ4: 品質チェック

- [x] `dart format .` / `flutter analyze` / `flutter test` / `bash scripts/check-layer-imports.sh` / `bash scripts/check-privacy.sh` がすべて通る

## フェーズ4.5: 検収指摘の反映(design.md「検収指摘の反映」)

- [x] R1: `GoalMark` を最小幅にし、文字サイズ 2.0 倍のテストを追加する
- [x] R2: 縦軸上限の計算に目標 +1 を渡し、`maxY` のテストを追加する
- [x] R3: 読み上げテストを行単位に締める
- [x] 品質チェック(フェーズ4 と同じコマンド)がすべて通る

## フェーズ5: ドキュメント(司令塔が行う。実装者は触らない)

- [x] `docs/functional-design.md` に達成状況の表示を反映する
- [x] 振り返りを記入する

## 申し送り

### 実装の結果

- 実装は `implement-ticket`(Sonnet fork)で 2 往復した。1 往復目で全フェーズ(215 件通過)、2 往復目で検収指摘 R1〜R3 を反映した(216 件通過)
- 検収(code-reviewer)の指摘は Must 0 / Should 4 / Nit 3。Should 3 件(R1 GoalMark の文字拡大時のはみ出し、R2 目標が軸上限と同値のときのラベル欠け、R3 読み上げテストの行単位化)は反映した

### 申し送り(未対応の指摘。実機確認 #10 などで判断する)

- 目標ライン(`onSurface` の 1.5px 破線)と棒(`primary`)の見分けやすさを、実機のライト / ダーク両方で目視確認する
- 複数セッションの日に、達成マークが 1 行目に揃う描画のテストはない(`crossAxisAlignment.start` のため設計どおり)
- 全日記録なしでも、目標があれば「目標 N 歩」の見出しは出る(仕様どおり)
- #22 の申し送り「目標の読み込み失敗時に目標なしとして開く」は、ダッシュボードでも同じく目標なしとして描画する(案内は出さない)とした。設定画面で上書きされうる点は未対応のまま

### 次回への改善提案

- UI の固定幅・グラフのラベル位置のように「文字拡大」「境界値で枠の端に乗る」で崩れる箇所は、design.md の段階で書いておくと検収の往復が減る
