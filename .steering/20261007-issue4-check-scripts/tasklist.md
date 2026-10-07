# タスクリスト: アプリ検証スクリプト 3 本(#4)

- [x] `scripts/check-layer-imports.sh` を書く(design §1・§2)
- [x] `scripts/check-privacy.sh` を書く(design §1・§3)
- [x] `scripts/check-release-permissions.sh` を書く(design §1・§4)
- [x] フィクスチャで確認する(design §5.2〜§5.4)
- [x] 実プロジェクトで確認する(design §5.1・§6)

## 申し送り

## 検収指摘の対応(design §7)

- [x] `check-release-permissions.sh` の抽出のフェイルクローズ化と SDK 候補のフォールスルー(design §7.1)
- [x] `check-privacy.sh` の debugPrint 系拡張と eval 廃止(design §7.2)
- [x] `check-layer-imports.sh` の L7 / L8 の分割 import 対応(design §7.3)
- [x] 追加確認と既存ケースの再実行(design §7.4)

- 実装は fork 2 往復(初回 + 検収指摘の反映)。検収は code-reviewer 1 巡(must-fix 1 / should-fix 4 / nit 4)、test-runner 全パス
- must-fix は権限検査のフェイルオープン: `aapt2` の出力に解釈できない権限行(二重引用符・未知の形式)が混じると、その行を黙って落として `exit 0` になり得た。権限行はすべて解釈できなければ `exit 2` に変更(design §7.1)
- 採らなかった指摘: `print` のティアオフ検出(誤検知が多い。`avoid_print` とレビューに任せる)/ 層ディレクトリ欠如時の stderr 通知(`lib/domain/` 等が #5 まで無く、毎回ノイズになる)
- 実 APK での権限検査は CI で確認する。`health` プラグインが許可リスト外の権限を足していた場合は PRD に理由を追記してから許可リストを更新する
