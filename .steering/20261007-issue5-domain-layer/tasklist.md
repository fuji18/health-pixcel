# タスクリスト: ドメイン層(#5)

- [x] モデル 6 ファイルを書く(design §1・§2)
- [x] `buildDateRange` / `nextDay` と `assignSleepToDays` を書く(design §3・§4)
- [x] フォーマット関数を書く(design §5)
- [x] ユニットテスト 4 ファイルを書く(design §6)
- [x] 完了条件の 5 コマンドを通す(design §7)

## 検収指摘の対応(design §8)

- [x] 不変性・未来日除外のテストを追加し、完了条件の 5 コマンドを通す(design §8・§7)

## 申し送り

- 実装は fork 2 往復(初回 + 検収指摘の反映)。検収は code-reviewer 1 巡(must-fix 0 / should-fix 1(2 点)/ nit 3)、test-runner 全パス
- design との差異は 1 点: `assignSleepToDays` の `[...?byDay[d]]` が型推論できず `avoid_dynamic_calls` に当たったため `<SleepSession>[...]` と型引数を明示(挙動同じ)
- **#6 への申し送り**: `assignSleepToDays` の重複キー `(start, end)` は `isUtc` が違うと同一瞬間でも別扱いになる。`HealthConnectRepository` は `SleepSession` の `start` / `end` を必ず `toLocal()` してから返すこと
- **#8 への申し送り**: `main()` で `runApp` の前に `await initializeDateFormatting('ja')` を呼ぶ(`formatDate` / `formatDayLabel` / `formatTime` の前提。本チケットでは未実施)
