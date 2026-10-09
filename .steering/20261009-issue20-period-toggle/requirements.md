# 要求内容

## 概要

ダッシュボードの表示期間を 7 日固定から「7 日 / 30 日」の切り替え式にする(Issue #20。PRD P1「週・月単位の期間切り替え」)。

## 背景

MVP は直近 7 日だけを表示している。1 か月単位の傾向を見るため、30 日分の日別リストに切り替えられるようにする。P1 のグラフ(#21)・目標(#22 / #23)はこの期間を前提に積み上がる。

## 実装対象の機能

### 1. 日付範囲の一般化
- `buildDateRange` を日数を引数に取る形にする(既定は 7 日。既存の挙動とテストを保つ)

### 2. 表示期間の状態と切り替え UI
- 表示期間(7 日 / 30 日)を `DashboardController` が持ち、`DashboardReady` に載せる
- `DashboardReady` の画面上部に切り替え UI(`SegmentedButton`)を置く
- 起動時は常に 7 日(選んだ期間は保存しない)

### 3. 30 日分の読み取り
- 歩数は日ごとの区間集計 API(`getTotalStepsInInterval` = ヘルスコネクトの aggregate)で 30 回取得する。生データの全件取得はしない
- 睡眠は既存どおり 1 回のクエリで期間全体を取り、端末内で振り分ける

## 受け入れ条件

- [ ] 7 日 / 30 日を切り替えると、日別リストがその期間の日数分だけ表示される
- [ ] `buildDateRange` のテストに 30 日のケース(月またぎ・年またぎ)が追加され、既存の 7 日のテストも通る
- [ ] 切り替え中・再読み込み中も、既存の状態別表示(権限未許可・データなし・エラー)が崩れない
- [ ] 30 日表示で、起動から表示まで 3 秒以内(実機。#10 の実機確認で見る)
- [ ] `docs/functional-design.md` の該当節(A1 / DashboardController / 画面レイアウト)を更新する

## 成功指標

- 30 日表示の初回読み込みが 3 秒以内(PRD 非機能要件)

## スコープ外

- グラフ(#21)、目標(#22 / #23)
- 選んだ期間の保存(起動時は常に 7 日)
- 暦の月(当月 1 日〜)での表示
- `WeeklySummaryService` のリネーム

## 参照ドキュメント

- `docs/product-requirements.md`「将来的な機能(Post-MVP) > P1」
- `docs/functional-design.md`「DateRange」「DashboardState」「WeeklySummaryService」「DashboardController」「A1」「A2」「画面レイアウト(DashboardReady)」「状態別の表示」
- `docs/architecture.md`「スケーラビリティ設計 > データ増加への対応」「機能拡張性」
