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

## フェーズ1: 依存の追加

- [x] `flutter pub add fl_chart:^1.2.0` で `pubspec.yaml` / `pubspec.lock` を更新する
- [x] `pubspec.lock` の新規パッケージが `fl_chart` / `equatable` / `vector_math` 以外に増えていないことを確認する(増えていたら停止して報告)

## フェーズ2: ドメインの純粋関数

- [x] `lib/domain/formatters.dart` に `formatShortDate` / `formatNumber` を追加し、`test/domain/formatters_test.dart` に追記する
- [x] `lib/domain/trend_summary.dart` を新規作成する(`stepsTrendSummary` / `sleepTrendSummary` / `stepsAxisMax` / `sleepAxisMaxHours`)
- [x] `test/domain/trend_summary_test.dart` を新規作成する(design.md「ユニットテスト」の全ケース)

## フェーズ3: グラフウィジェット

- [x] `lib/presentation/dashboard/widgets/trend_bar_chart.dart` を新規作成する
- [x] `test/presentation/dashboard/widgets/trend_bar_chart_test.dart` を新規作成する(データあり / 一部記録なし / 全日記録なし / 30 日)

## フェーズ4: 画面への組み込み

- [x] `steps_section.dart` の `MetricLoaded` 分岐にグラフを組み込み、doc コメントを直す
- [x] `sleep_section.dart` の `MetricLoaded` 分岐にグラフを組み込み、doc コメントを直す
- [x] `dashboard_screen_test.dart` にテスト 23・24 を追記する(既存テストの扱いは design.md「既存テストの扱い」に従う)

## フェーズ5: ドキュメント更新

- [x] `docs/functional-design.md` を design.md「ドキュメント更新の内容」どおりに更新する
- [x] `docs/architecture.md` の fl_chart 行を更新する
- [x] `docs/repository-structure.md` のツリーに新規ファイルを追加する

## フェーズ5b: 検収指摘の反映

- [x] design.md「検収指摘によるテスト追加」の 3 項目をテストに追加し、変更ファイルの analyze / format / test を通す

## フェーズ6: 品質チェックと修正

- [x] `/check`(test-runner に委譲)の全チェックがパスすることを確認
  - 検証コマンドは `docs/development-guidelines.md` の定義が正(test-runner が自動検出する)
- [ ] PR 作成後、CI のリリースビルドと権限検査(`INTERNET` の不在)が緑であることを確認する(司令塔)
- [ ] CI のリリースビルドで APK サイズが 30MB を大きく超えていないことを確認する(司令塔)
- [ ] 実装後の振り返り（このファイルの下部に記録）

---

## 実装後の振り返り

### 実装完了日
{YYYY-MM-DD}

### 計画と実績の差分

**計画と異なった点**:
-

**新たに必要になったタスク**:
-

### 学んだこと

-

### 次回への改善提案

-
