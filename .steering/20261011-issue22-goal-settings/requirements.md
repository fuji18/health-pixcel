# 要求内容

## 概要

歩数・睡眠時間の目標値を入力する設定画面を作り、アプリ専用領域(`shared_preferences`)に保存する(Issue #22。PRD P1「目標設定と達成状況の表示」の前半)。

## 背景

PRD P1 で目標の達成状況を表示する(#23)。その前提として、目標値を入力・保存できる必要がある。保存するのはユーザーが入力した目標値 2 つだけで、健康データは保存しない(PRD「セキュリティ・プライバシー」)。

## 実装対象の機能

### 1. 目標値の保存(GoalRepository)
- 抽象 `GoalRepository` と、`shared_preferences` による実装 `SharedPreferencesGoalRepository`(`lib/data/`)
- テスト用のフェイク `FakeGoalRepository`
- 未設定(目標なし)を扱える

### 2. 目標の設定画面(GoalSettingsScreen)
- 歩数(整数)と睡眠時間(時間・分)を入力する
- 入力検証: 非数値・範囲外は保存せず、理由を入力欄の下に表示する
- 空欄で保存すると目標なし(削除)になる
- ダッシュボードの AppBar から遷移できる

## 受け入れ条件

### 目標値の保存
- [ ] 目標を保存してアプリを再起動しても値が残る(テスト: 別インスタンスのリポジトリから読み直して同じ値)
- [ ] `package:shared_preferences/` の import は `lib/data/shared_preferences_goal_repository.dart` の 1 行だけで、その行にだけ `// privacy-check: allow(目標値の保存。健康データは保存しない)` が付いている

### 設定画面
- [ ] 範囲外・非数値の入力は保存できず、理由が表示される
- [ ] ダッシュボードの AppBar のアイコンから設定画面に遷移できる

### 共通
- [ ] `flutter analyze` / `dart format` / `flutter test` / `bash scripts/check-*.sh`(リリース権限検査を除く)が通る
- [ ] `docs/functional-design.md` に GoalRepository と設定画面を追記する
- [ ] PR 本文に `shared_preferences`(Android 実装を含む)に通信・解析 SDK が無いことの確認結果を書く(司令塔が担当)
- [ ] CI のリリースビルドと権限検査(INTERNET の不在)が緑(司令塔が PR 後に確認)

## 成功指標

- 目標値の保存が `lib/data/` の 1 ファイルに閉じ、プライバシー検査の例外が 1 行だけ

## スコープ外

以下はこのチケットでは実装しません:

- 達成状況の表示(#23。ダッシュボードで目標値を読むのも #23)
- 健康データの保存(PRD により禁止)

## 参照ドキュメント

- `docs/product-requirements.md`「セキュリティ・プライバシー(最重要)」
- `docs/architecture.md`「データ永続化戦略」「レイヤードアーキテクチャ」「フレームワーク・ライブラリ」
- `docs/functional-design.md`「コンポーネント設計」「画面遷移図」「UI設計」
