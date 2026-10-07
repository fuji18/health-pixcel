# タスクリスト: MVP の実機検証とリリース確認(#10)

担当: 【人】= Windows 側で人間が実施 / 【C】= 司令塔(Claude)

## フェーズ1: 準備

- [x] 【C】steering(requirements / design / tasklist / results テンプレート)の作成
- [ ] 【人】Health Sync の同期確認、リリース APK のビルドとインストール(design.md §0)

## フェーズ2: 実機確認(結果は results.md へ)

- [ ] 【人】C1 初回起動 → 権限許可 → 表示
- [ ] 【人】C2 HUAWEIヘルスケアとの 7 日分の突き合わせ(§2)
- [ ] 【人】C3 片方の権限を外したときの表示
- [ ] 【人】C4 機内モード・Health Sync 停止中
- [ ] 【人】C5 `check-release-permissions.sh` と APK Analyzer(§4)
- [ ] 【人】C6 利用目的画面((a) 終了状態から (b) バックグラウンドから)
- [ ] 【人】C7 logcat の確認(§5)
- [ ] 【人】C8 / C9 起動時間・再読み込み時間の計測(§3)

## フェーズ3: 判定と反映

- [ ] 【C】results.md の判定(合否・不具合の振り分け。design.md §7)
- [ ] 【C】睡眠時間の定義の結論を docs に反映(design.md §6)
- [ ] 【C】不具合修正(あれば。小さいものは `implement-ticket`、大きいものは別 Issue)

## フェーズ4: 完了

- [ ] 【C】振り返り(本ファイル末尾の申し送り)
- [ ] 【C】`.harness/decisions.jsonl` への記録・コミット・PR(`Closes #10`)
