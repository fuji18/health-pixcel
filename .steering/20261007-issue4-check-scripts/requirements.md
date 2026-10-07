# 要求: アプリ検証スクリプト 3 本(#4)

## 目的

プライバシー要件(INTERNET 権限なし・ログ出力なし・保存/共有なし)とレイヤー規則を機械的に検査する。PRD セカンダリーKPI「外部送信ゼロ」の測定手段でもある。

## スコープ

- `scripts/check-release-permissions.sh`(最終 APK を `aapt2 dump permissions` で許可リストと照合。`exit 0/1/2`)
- `scripts/check-layer-imports.sh`(外部パッケージ・アプリ内レイヤー・相対 import の検査)
- `scripts/check-privacy.sh`(ログ・入出力・共有・通信・保存・ロガー・`toString()` の検出。`// privacy-check: allow(<理由>)` の除外)
- いずれも POSIX シェル(Git Bash と ubuntu の両方で動く)

## スコープ外

- CI への組み込み(`ci.yml` はファイルの有無で自動実行する。変更しない)
- `package.json` の変更(`npm run lint` は既に 2 本をファイルの有無で呼ぶ)
- 自動テスト(スクリプトの自己テスト)のコミット。確認は使い捨てのフィクスチャで行い、手順を PR 本文に書く

## 受け入れ条件

- [ ] 3 本とも、違反を含むサンプル入力で `exit 1` と該当行・権限名を出し、違反なしで `exit 0` を返す(確認手順を PR 本文に書く)
- [ ] `check-release-permissions.sh` が APK なし・APK が古いとき・SDK や `aapt2` が見つからないときに `exit 2` と理由を出す
- [ ] 現在の `lib/` に対して `check-layer-imports.sh` と `check-privacy.sh` が `exit 0`
- [ ] CI のリリースビルド後の権限検査が通る(`INTERNET` なし・許可リスト外の権限なし)。許可リスト外の権限が出た場合は PRD に理由を追記してから許可リストを更新する
- [ ] `npm run lint` から 2 本(layer / privacy)が実行される

## 根拠

- `docs/repository-structure.md`「scripts/(アプリの検証スクリプト)」「依存関係のルール」
- `docs/architecture.md`「検証コマンド」「コマンドの実行環境」「セキュリティアーキテクチャ」
