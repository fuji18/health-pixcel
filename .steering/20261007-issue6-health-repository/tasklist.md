# タスクリスト: データ層 HealthConnectRepository(#6)

- [x] `health` 13.3.2 の確認事項をソースで確認し、docs に反映する(司令塔。`docs/architecture.md`「確認結果(#6)」ほか)
- [x] `lib/data/health_repository.dart` を書く(design §1)
- [x] `lib/data/health_connect_repository.dart` を書く(design §2)
- [x] `test/data/health_connect_repository_test.dart` を書く(design §3)
- [x] 完了条件の 5 コマンドを通す(design §4)

## 検収指摘の対応(design §5)

- [x] テストを追加し、完了条件の 5 コマンドを通す(design §5・§4)

## 申し送り

- 実装は fork 2 往復(初回 + 検収指摘のテスト追加)。検収は code-reviewer 1 巡(must-fix 0 / should-fix 3 / nit 4)。should-fix 2 件と nit 2 件を採用。TZ 依存の指摘 1 件は誤検知として見送った(入力が `DateTime.utc` なので TZ によらず検出できる)。test-runner は全パス
- 設計からの変更: 歩数の `null` は `readFailed` にする(health 13.3.2 はネイティブ例外を `null` で返すため。ユーザー承認済み)。`test/data/` を新設した(フェイクの `Health` で変換規則を検証)
- **#7 への申し送り**: `readTotalSteps` は利用不可でも `UnsupportedError` を出さず `readFailed` になる(health 13.3.2 の `getTotalStepsInInterval` は利用可否を検査しない)。読み込み後の利用可否の再確認は `_fetch()` の設計どおり行うこと
- **#9 への申し送り**: `openPermissionSettings` は暫定で `false` を返す。MethodChannel 実装に置き換えること
- **#10 への申し送り**: health 13.3.2 の Kotlin 側が `Log.i("FLUTTER_HEALTH::SUCCESS", "returning $stepsInInterval steps")` で**歩数の値を logcat に出す**。受け入れ条件「logcat に値が出ない」に抵触する見込みが高い。リリースビルドでの出力有無を確認し、出るなら対策(R8 で `android.util.Log` を除去する等)を別チケットで検討する。実機で未確認の確認事項(ACTIVITY_RECOGNITION なしの歩数 / MANAGE_HEALTH_PERMISSIONS / 睡眠セッションの区間)も #10 で行う
