# タスクリスト: 表示期間の切り替え(#20)

## 計画(司令塔)

- [x] `docs/functional-design.md` / `docs/architecture.md` の該当節を更新する(DisplayPeriod / DateRange / DashboardState / WeeklySummaryService / DashboardController / A1 / A2 / 画面レイアウト / 状態別の表示 / パフォーマンス / データ増加への対応)

## 実装(implement-ticket)

- [x] `lib/domain/models/display_period.dart` を作り、`buildDateRange` に `dayCount` を足し、`DateRange` のコメントを直す(design §1〜§3)
- [x] `test/domain/date_range_builder_test.dart` に 30 日のケースを足す(design「テスト戦略」)
- [x] `WeeklySummaryService.currentRange({dayCount})` とコメント(design §4)+ テスト追加
- [x] `DashboardReady.period` と `DashboardController.selectPeriod` / `_isCurrent` / `_fetchBody` の変更(design §5・§6)+ 既存テストの `period:` 追加 + 「表示期間」グループのテスト
- [x] `DashboardScreen` に `SegmentedButton` を置き、`PermissionRationaleScreen` の文言を直す(design §7・§8)+ ウィジェットテスト 18〜22 と利用目的画面のテスト文言
- [x] 完了条件の 5 コマンドを通す(design「完了条件」)

## 検収指摘の対応(design §9)

- [x] `requestPermissions()` 中の切り替えテストを足す(design §9.1)
- [x] 競合テストのゲート到達確認と mutation 確認(design §9.2)
- [x] `SegmentedButton` に `Semantics(label: '表示期間')`(design §9.3)
- [x] 完了条件の 5 コマンドを通す(design「完了条件」)

## 申し送り

mutation 確認: _isCurrent を true に固定すると「実行中の refresh」「連続切り替え」「権限リクエスト後の読み込み中の切り替え」の 3 ケースが落ちることを確認済み(元に戻した)。

- 実装完了: 2026-10-09。fork 2 往復(初回 + 検収指摘の対応)。検収は code-reviewer 1 巡(critical 0 / major 2 / minor 4)。major 2 件(`requestPermissions()` との競合テスト、競合テストのゲート到達確認と mutation 確認)と minor 1 件(切り替えボタンの `Semantics(label: '表示期間')`)を採用。test-runner は全パス(最終 148 件)
- 計画との差分: design §9.1 の手順は `selectPeriod` が先に月の読み込みを始めるため競合を作れず、mutation 確認で落ちなかった。fork が「権限リクエスト後の読み込み中の切り替え」に手順を直した。§9.2 の `isNotEmpty` は初期表示で常に真になるため、切り替え前の件数との比較に変えた
- 見送った指摘: 切り替え中も `SegmentedButton` を残す案(design「決定事項」の理由)。docs の状態表の「前回の値を伴う」は Riverpod 3 の仕様の記述で矛盾ではない
- 学んだこと: 競合テストは設計段階で「どちらの Future が先にゲートに着くか」まで書かないと、競合を作らないまま緑になる。design に mutation 確認を入れると偽陰性を機械的に潰せる
- **#21 への申し送り**: グラフは `DashboardReady.period` / `range.days` をそのまま横軸に使える。30 日表示ではリストが長くなるため、グラフとリストの配置(リストを折りたたむ等)は #21 の design で決める
- 未確認: 30 日表示で起動から表示まで 3 秒以内(実機。#10 で確認)
