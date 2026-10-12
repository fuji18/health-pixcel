# 要求内容

Issue: #25 [チケット] 体重の読み取りと表示(P1 / フェーズ 4 / depends: #24)

## 背景・目的

PRD P1「心拍・体重・運動記録の読み取りと表示」のうち体重。#24 で作った基盤(`HealthMetric` / `HealthPermissions`、心拍の読み取りとセクション)の横展開。

## スコープ(やること)

- **先に** PRD「セキュリティ・プライバシー」に `READ_WEIGHT` を追加する理由を追記する(司令塔が実施済み: コミット ef29f48)
- `AndroidManifest.xml` に `android.permission.health.READ_WEIGHT` を追加し、`scripts/check-release-permissions.sh` の許可リストを更新する
- 体重を日別に表示する(その日の最新値。#24 と同じ未許可・記録なしの扱い)

## スコープ外(やらないこと)

- 体重のグラフ・目標
- BMI・体脂肪率・身長(権限を宣言しない)
- 記録のない日に前日以前の値を引き継ぐ表示

## 受け入れ条件

- [ ] PRD の理由追記が、マニフェスト・許可リストの変更より前のコミットにある
- [ ] 体重だけ未許可でも他のセクションの表示は保たれる
- [ ] 体重の値をログに出さない(`check-privacy.sh` が通る)
- [ ] CI のリリースビルドと権限検査が緑
- [ ] 実機で体重が表示されることを確認する(ユーザーが Windows 側で実施)
- [ ] `docs/functional-design.md` を更新する

## 根拠

- `docs/product-requirements.md`「セキュリティ・プライバシー(最重要)」
- `docs/functional-design.md`(#24 で更新した HealthRepository / HealthConnectRepository / 取得結果と権限状態 / DashboardController / 状態別の表示)
- `.steering/20261011-issue24-heart-rate/design.md`(参照実装)
