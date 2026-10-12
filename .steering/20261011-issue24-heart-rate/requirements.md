# 要求内容

Issue: #24 [チケット] 新しいデータ型の読み取り基盤 + 心拍(P1 / フェーズ 3 / depends: なし)

## 背景・目的

PRD P1「心拍・体重・運動記録の読み取りと表示」の 1 例目。新しいデータ型を読む基盤(データ型ごとの権限状態)を整え、心拍を日別に表示する。体重(#25)・運動記録(#26)はこのチケットの横展開になる。

## スコープ(やること)

- **先に** PRD「セキュリティ・プライバシー」に `READ_HEART_RATE` を追加する理由を追記する(司令塔が実施済み: コミット 528fa0d)
- `AndroidManifest.xml` に `android.permission.health.READ_HEART_RATE` を追加し、`scripts/check-release-permissions.sh` の許可リストを更新する
- `HealthRepository` に心拍の読み取りを追加し、権限状態をデータ型ごとに扱えるようにする(片方だけ許可の F4 と同じ考え方を 3 種以上に広げる)
- 日別の心拍を画面に表示する(未許可・記録なしの案内を含む)

## スコープ外(やらないこと)

- 体重(#25)・運動記録(#26)
- 心拍のグラフ
- 安静時心拍(`READ_RESTING_HEART_RATE` は宣言しない)

## 受け入れ条件

- [ ] PRD の理由追記が、マニフェスト・許可リストの変更より前のコミットにある
- [ ] 心拍だけ未許可の状態で、心拍セクションに許可の案内が出て、歩数・睡眠の表示は保たれる
- [ ] 心拍の値をログに出さない(`check-privacy.sh` が通る)
- [ ] CI のリリースビルドと権限検査が緑
- [ ] 実機(Pixel 10)で心拍が表示されることを確認する(ユーザーが Windows 側で実施)
- [ ] `docs/functional-design.md` と `docs/architecture.md`(最小権限の記述)を更新する

## 根拠

- `docs/product-requirements.md`「セキュリティ・プライバシー(最重要)」
- `docs/functional-design.md`「HealthRepository」「HealthConnectRepository」「取得結果と権限状態」「DashboardController」「状態別の表示」
- `docs/architecture.md`「AndroidManifest の構成」「機能拡張性」
