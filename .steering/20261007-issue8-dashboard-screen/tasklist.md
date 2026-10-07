# タスクリスト: ダッシュボード画面(#8)

- [x] `lib/presentation/dashboard/widgets/status_message.dart` を書く(design §1)
- [x] `lib/presentation/dashboard/widgets/sleep_section.dart` / `steps_section.dart` を書く(design §2)
- [x] `lib/presentation/dashboard/dashboard_screen.dart` を書く(design §3)
- [x] `lib/app.dart` にテーマと `home: DashboardScreen()` を入れる(design §4)
- [x] `lib/main.dart` に `initializeDateFormatting('ja')` を入れる(design §5)
- [x] `test/presentation/dashboard/dashboard_screen_test.dart` を書く(design §6.1・§6.2。15 ケースすべて)
- [x] `test/app_test.dart` を置き換える(design §6.3)
- [x] 完了条件の 6 コマンドを通す(design §7)

## 検収指摘の対応(design §8)

- [x] 見出しの `Semantics(header: true)` と行の `MergeSemantics`(design §8.1・§8.2)
- [x] ケース 2・10 の強化とケース 16 の追加(design §8.3〜§8.5)
- [x] 完了条件の 6 コマンドを通す(design §7)

## 申し送り

- 実装完了: 2026-10-07。fork 2 往復(初回 + 検収指摘の対応)。検収は code-reviewer 1 巡(critical 0 / major 0 / minor 5)。minor 3 件(ケース 2・10 のアサーション強化、見出しの `Semantics(header: true)` と行の `MergeSemantics`)を採用。test-runner は全パス(最終 111 件)
- 計画との差分: 引っぱって更新のテストは `fling(400)` では縦長ビューポート(2400)の 25% に届かず起動しないため `drag(Offset(0, 1000))` に変更。`SemanticsHandle` は `addTearDown` だと終了時チェックに掛かるためテスト本体の末尾で `dispose()`
- docs 反映: `ui-design-guidelines.md` §7 の ThemeData の置き場所を `lib/app.dart` に修正
- 学んだこと: 画面の参照実装は design.md に文言・ウィジェット種・余白の数値まで書き切ると 1 往復目で設計どおりに上がる。ウィジェットテストの「消えた」「出ない」系アサーションは偽陰性になりやすく、回復後に出るべきものまで確認させる
- **#9 への申し送り**: `DashboardNeedsPermission` の操作に「詳しく見る」(`PermissionRationaleScreen` へ `Navigator.push`)を 3 つ目の `StatusAction` として足す。`HealthPixcelApp` の `home` は現在 `DashboardScreen` 固定。テストのケース 5 は「詳しく見る」が無いことを確認しているので #9 で反転させる
- 見送った指摘: ライト/ダークの描画テスト(色は Theme 由来で破綻リスクが低い。#10 の実機確認で見る)
