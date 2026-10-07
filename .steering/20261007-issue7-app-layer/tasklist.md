# タスクリスト: アプリ層・状態管理(#7)

- [x] `lib/application/weekly_summary_service.dart` を書く(design §1)
- [x] `lib/presentation/providers.dart` を書く(design §2)
- [x] `lib/presentation/dashboard/dashboard_state.dart` を書く(design §3)
- [x] `lib/presentation/dashboard/dashboard_controller.dart` を書く(design §4)
- [x] `test/fakes/fake_health_repository.dart` を書く(design §5)
- [x] `test/application/weekly_summary_service_test.dart` を書く(design §6)
- [x] `test/presentation/dashboard/dashboard_controller_test.dart` を書く(design §7。22 ケースすべて)
- [x] `test/presentation/dashboard/dashboard_state_test.dart` を書く(design §8)
- [x] 完了条件の 5 コマンドを通す(design §9)

## 検収指摘の対応(design §10)

- [x] `_fetch()` をループで直列化し、破棄ガードを足す(design §10.1)
- [x] `requestPermissions()` の二重呼び出しを無視する(design §10.2)
- [x] テスト #14・#16 を強化し、#23・#24 を追加する(design §10.3)
- [x] 完了条件の 5 コマンドを通す(design §9)

## 申し送り

- 実装完了: 2026-10-07。fork 2 往復(初回 + 検収指摘の対応)。検収は code-reviewer 1 巡(critical 0 / major 2 / minor 8)。major 2 件と minor 3 件(破棄ガード・二重リクエスト・テストの明確化)を採用。test-runner は全パス(最終 95 件)
- 計画との差分: `_fetch()` の force 経路を「1 回待つ」から「`_inFlight` が空くまでループで待つ」に変更(`await` の隙に別の `_fetch()` が入ると本体が並走し `_lastSnapshot` の不変条件が崩れるため)。`requestPermissions()` はリクエスト中の再呼び出しを無視する
- docs 反映: `openSettings()` / `openStore()` は `Future<bool>` を返し、スナックバーは画面が出す。`requestPermissions()` 中の `AsyncLoading` は Riverpod 3 の仕様で前回値を伴う(画面は `isLoading` で判定)。Riverpod 3 の自動リトライは走らないことを確認(`architecture.md`)
- 学んだこと: 並行性の擬似コードは「待った後に状態を確認し直すか」まで書き切る。競合テストは最終状態だけでなく「途中で何回呼ばれたか」を見ないと、直列化が外れても通ってしまう
- **#8 への申し送り**: スナックバー(「ヘルスコネクトを開けませんでした」/「Play ストアを開けませんでした」)は `openSettings()` / `openStore()` の戻り値 `false` を見て画面で出す。ローディングは `when()` の既定(`skipLoadingOnReload: false`)で表示する(権限リクエスト後は前回値を伴う `AsyncLoading`)。フェイクは `test/fakes/fake_health_repository.dart` を使う
- 見送った指摘(仕様の検討事項):
  - `refresh()` と `requestPermissions()` が重なると、古い結果(NeedsPermission)が一瞬表示される。最終状態は正しい
  - 設定画面から戻ったときの `refresh()` は、権限変更前に始まった読み込みに合流しうる(設計書どおり。次の復帰で回復)
  - 日付をまたいで復帰しても、権限が同じなら再読み込みしない。読み取り失敗も復帰では再試行しない(機能設計書どおり。#10 の実機確認で問題になれば `onResumed()` に日付の比較を足す)
