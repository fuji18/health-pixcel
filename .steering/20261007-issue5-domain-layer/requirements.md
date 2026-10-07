# 要求: ドメイン層(日付範囲・睡眠の帰属・表示フォーマット)(#5)

## 背景・目的

「直近 7 日」「睡眠の帰属日」「表示フォーマット」をプラットフォーム非依存の純粋なロジックとして実装する。F2 / F3 の正しさの中核。

## スコープ

- `lib/domain/` のエンティティ・enum・`MetricResult`(`sealed`)
- `buildDateRange` / `nextDay`(A1)/ `assignSleepToDays`(A3)/ 表示フォーマット関数(A4)
- 上記のユニットテスト

## スコープ外

- `DashboardState` と `isAllEmpty`(#7)
- リポジトリ・`health` パッケージの利用(#6)
- `main()` での `initializeDateFormatting('ja')` 呼び出し(フォーマット関数を画面で使い始める #8 で入れる)

## 受け入れ条件(Issue #5 より)

- [ ] `lib/domain/` が `flutter` / `flutter_riverpod` / `health` を import しない
- [ ] ドメインモデルが `toString()` を実装しない
- [ ] `buildDateRange`: 通常日・月またぎ・年またぎ・23:59 のテストが通り、7 日が 00:00 に揃い `now` が保持される
- [ ] `assignSleepToDays`: 日付をまたぐ睡眠が起床日に入る / 最古日より前に起床したセッションの除外 / 同日 2 件の昇順 / 重複の 1 件化 / 空の日が空リスト、のテストが通る
- [ ] フォーマット: `7時間12分` / `45分` / `8,432 歩` / `今日 10/6(火)`(2026-10-06 基準)のテストが通る
- [ ] `flutter analyze` / format 検査 / `flutter test` / `check-layer-imports.sh` / `check-privacy.sh` が通る

## 根拠

- `docs/functional-design.md`「データモデル定義」「アルゴリズム設計」A1・A3・A4「テスト戦略 > ユニットテスト」
- `docs/repository-structure.md`「lib/domain/(ドメイン層)」
- `docs/development-guidelines.md`「型とモデル」「時刻への依存」「テストの書き方」
