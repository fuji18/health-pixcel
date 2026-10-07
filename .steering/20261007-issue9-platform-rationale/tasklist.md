# タスクリスト: プラットフォーム連携と利用目的画面(#9)

- [x] `MainActivity.kt` に MethodChannel 2 本を書く(design §1)
- [x] `lib/data/platform_channels.dart` を書き、`HealthConnectRepository.openPermissionSettings` をつなぐ(design §2・§3)
- [x] `launchActionProvider` を足す(design §4)
- [x] `PermissionRationaleScreen` を書く(design §5)
- [x] `DashboardScreen` に「詳しく見る」を足す(design §6)
- [x] `HealthPixcelApp` で最初の画面を出し分ける(design §7)
- [x] テストを書く・直す(design §8.1〜§8.5)
- [x] 完了条件の 6 コマンドを通す(design §9)

## 検収指摘の対応(design §10)

- [x] 項目ラベルを見出しにする(design §10.1)
- [x] 戻る矢印・見出しのテストを直す(design §10.2)
- [x] 完了条件の 6 コマンドを通す(design §9)

## CI 失敗の対応(design §11)

- [x] `ACTION_HEALTH_HOME_SETTINGS` を文字列定数にする(design §11)
- [x] 完了条件の 6 コマンドを通す(design §9)

## /code-review 指摘の対応(design §12)

- [x] `MainActivity.kt` を初期ルート方式にする(design §12.2)
- [x] `LaunchChannel` を削除し、`launchActionProvider` と `HealthPixcelApp` を初期ルート方式にする(design §12.3〜§12.5)
- [x] 利用目的画面の戻る矢印を出す(design §12.6)
- [x] テストを直す(design §12.7)
- [x] 完了条件を通す(design §9・§12.8)

## 申し送り

- 実装完了: 2026-10-07。fork 3 往復(初回 + 検収指摘の対応 + CI のリリースビルド失敗の修正)。検収は code-reviewer 1 巡(critical 0 / major 0 / minor 5)。minor 2 件(項目ラベルの `Semantics(header: true)`、戻る矢印テストの偽陰性)を採用。test-runner は全パス(129 件)
- 計画との差分: `platform_channels.dart` の名前付き引数 → private フィールドで `prefer_initializing_formals` が出るため `// ignore:` を 2 箇所。KDoc の `resolveActivity` の語が §9 の grep に掛かるため言い換え。見出しのテストは本文とノードが結合するため `matchesSemantics` ではなく `isSemantics(isHeader: true)`(`containsSemantics` は非推奨)
- Kotlin はローカルでコンパイルできない。CI のリリースビルドが緑になるまで完了扱いにしない(CLAUDE.md)
- CI 失敗: `HealthConnectManager.ACTION_HEALTH_HOME_SETTINGS` は SDK 上で非公開でコンパイル不可(docs/architecture.md の「直接参照してよい」が誤り。docs を修正し文字列定数で持つ形にした)。code-reviewer も公開定数と判断しており、ローカルでコンパイルできない Kotlin の API 可否はレビューでは担保できない
- 学んだこと: 検査用 grep の語(`resolveActivity`)を設計のコメント例に含めると自分で検査に掛かる。禁止語の検査は設計段階でコメント文と突き合わせる
- **#10 への申し送り**: (1) 通常起動でスプラッシュの直後にダッシュボードが出る(空画面を挟まない。design §12) (2) ヘルスコネクトの「利用目的」から開く → 「閉じる」でヘルスコネクトに戻る (3) ダッシュボード →「ヘルスコネクトの設定を開く」→ ヘルスコネクト上で「利用目的」を開くと、新しいインスタンスで利用目的画面が出て、「閉じる」でヘルスコネクトの画面に戻る(下のダッシュボードは残る) (4) 「ヘルスコネクトの設定を開く」でこのアプリの権限画面が直接開く
- 見送った指摘: `onNewIntent`(スコープ外)/ チャネルの全例外捕捉(設計どおり)/ 空 Scaffold のちらつき(#10 の実機で確認 → `/code-review` を受けて design §12 で解消)
- `/code-review` 指摘 6 件の対応(design §12): Codex 委託は機密候補ファイル(`.claude/settings.local.json`。中身は MCP の有効化設定のみ)の検出で止まり、承認付きの再実行が権限で拒否されたため `implement-ticket` の fork で実装。fork 1 往復。起動理由を MethodChannel から初期ルートに替え、空画面・チャネル重複・provider の差し替え不能をまとめて解消。docs 5 ファイルを司令塔が訂正
