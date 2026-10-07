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

## 申し送り

- 実装完了: 2026-10-07。fork 2 往復(初回 + 検収指摘の対応)。検収は code-reviewer 1 巡(critical 0 / major 0 / minor 5)。minor 2 件(項目ラベルの `Semantics(header: true)`、戻る矢印テストの偽陰性)を採用。test-runner は全パス(129 件)
- 計画との差分: `platform_channels.dart` の名前付き引数 → private フィールドで `prefer_initializing_formals` が出るため `// ignore:` を 2 箇所。KDoc の `resolveActivity` の語が §9 の grep に掛かるため言い換え。見出しのテストは本文とノードが結合するため `matchesSemantics` ではなく `isSemantics(isHeader: true)`(`containsSemantics` は非推奨)
- Kotlin はローカルでコンパイルできない。CI のリリースビルドが緑になるまで完了扱いにしない(CLAUDE.md)
- 学んだこと: 検査用 grep の語(`resolveActivity`)を設計のコメント例に含めると自分で検査に掛かる。禁止語の検査は設計段階でコメント文と突き合わせる
- **#10 への申し送り**: (1) 起動理由の判定中に出る空 `Scaffold` がスプラッシュとの間でちらつかないか実機で見る (2) ヘルスコネクトの「利用目的」から開く → 「閉じる」でヘルスコネクトに戻る (3) アプリ起動済みの状態で「利用目的」を開くとダッシュボードが出る(`onNewIntent` 非対応。MVP の仕様) (4) 「ヘルスコネクトの設定を開く」でこのアプリの権限画面が直接開く
- 見送った指摘: `onNewIntent`(スコープ外)/ チャネルの全例外捕捉(設計どおり)/ 空 Scaffold のちらつき(#10 の実機で確認)
