# 要求: ダッシュボード画面(F1〜F4)(#8)

## 背景・目的

直近 7 日の睡眠・歩数を一覧で表示し、権限未許可・データなし・利用不可・エラーの各状態で「何が起きているか」と「次の行動」を示す(F1〜F4 のユーザー価値の本体)。

## スコープ

- `DashboardScreen` / `SleepSection`(上)/ `StepsSection`(下)/ `StatusMessage`
- 状態別の文言と操作ボタン(「権限を許可する」「ヘルスコネクトの設定を開く」「再読み込み」「Play ストアを開く」「ヘルスコネクトを更新する」)
- 引っぱって更新(`RefreshIndicator` + `AlwaysScrollableScrollPhysics`)、`AppLifecycleListener` による `onResumed`
- `app.dart` の `ThemeData`(`ColorScheme.fromSeed`、ライト/ダーク)と、最初の画面を `DashboardScreen` にすること
- `main.dart` の `initializeDateFormatting('ja')`(機能設計書 A4。画面で日付を整形するのは本チケットが初)
- ウィジェットテスト

## スコープ外

- 「詳しく見る」ボタンと遷移先 `PermissionRationaleScreen`、起動理由による出し分け(#9)。**#8 では「詳しく見る」ボタン自体を出さない**(遷移先の無いボタンを置かないため。#9 で足す)
- 設定画面を開く MethodChannel(#9。ここでは `openSettings()` を呼ぶところまで)

## 受け入れ条件(Issue #8 より)

- [ ] 各 `DashboardState` で「状態別の表示」の文言と操作ボタンが出る(ウィジェットテスト)
- [ ] `Ready` で 7 行ずつ表示され、記録なしの日も行が省略されない
- [ ] 睡眠が上・歩数が下、新しい日が上
- [ ] 色・文字サイズの直書きがなく、`Theme.of(context)` 経由になっている
- [ ] `docs/ui-design-guidelines.md` §6 のチェックリストを `code-reviewer` で当てている
- [ ] `flutter analyze` / format 検査 / `flutter test` / `scripts/check-*.sh`(layer / privacy)が通る

## 設計書からの変更(司令塔判断。docs に反映する)

- `docs/ui-design-guidelines.md` §7 の `ThemeData` の置き場所 `lib/presentation/app.dart` は実在しない。実体は `lib/app.dart`(`docs/repository-structure.md` と一致)。§7 を直す
- 「詳しく見る」は #9 で足す(上記)
