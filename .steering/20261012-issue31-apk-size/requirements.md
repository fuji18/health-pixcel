# 要求内容

Issue: #31 [チケット] リリース APK サイズの目安(30MB)と測り方の見直し(P2 / フェーズ 4 / depends: なし)

## 背景・目的

`docs/architecture.md`「パフォーマンス要件」はリリース APK サイズの目安を 30MB 以下としているが、CI のリリースビルド(3 ABI 同梱の fat APK)は 48〜49MB あり、常に超過している。目安の本来の目的は「依存追加時に急増していないかの検知」なので、現状のビルドで意味のある数値・測り方に改める。

## スコープ(やること)

- リリース APK の内訳(ABI ごとのネイティブライブラリ・Dart AOT・アセット・DEX・リソース)を出すスクリプト `scripts/report-apk-size.sh` を作る
- CI のリリースビルド後にそのスクリプトを走らせ、内訳をジョブサマリーに出す(目安超過は警告のみで、CI は落とさない)
- CI の実測値をもとに目安(数値・測り方)を決め、`docs/architecture.md` を更新する
- 依存を追加した PR でサイズ増加を確認する手順を `docs/development-guidelines.md` に書く

## スコープ外(やらないこと)

- サイズ削減のための依存の入れ替え・機能削除
- Play ストア配布用の AAB 化
- `--split-per-abi` ビルドへの切り替え(配布物は従来どおり fat APK)
- main との差分を CI が自動計算すること(main を別途ビルドする費用に見合わない。比較は手順で行う)

## 受け入れ条件

- [ ] APK サイズの内訳(ABI・Dart AOT・アセット)が PR 本文か `.steering/` に記録されている
- [ ] `docs/architecture.md` の目安が、現状のビルドで意味のある数値・測り方に更新されている
- [ ] 依存を追加した PR で、サイズの増加を確認する手順が明確になっている(CI のジョブサマリー + 手順)
- [ ] CI のリリースビルドと権限検査が緑

## 根拠

- `docs/architecture.md`「パフォーマンス要件 > リソース使用量」
- `docs/repository-structure.md`「scripts/(アプリの検証スクリプト)」
- `docs/development-guidelines.md`「プルリクエストプロセス」「品質の自動化」
- `.steering/20261011-issue21-trend-chart/tasklist.md`「次回への改善提案」
