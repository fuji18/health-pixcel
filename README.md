# health-pixcel

端末内だけで完結する個人用ヘルスデータ解析アプリ(Flutter / Android)。

スマートウォッチの健康データを、ヘルスコネクト経由で自分のスマートフォンの中だけで読み取り、直近 7 日の睡眠と歩数をすぐ確認できるようにする。

- **端末内で完結**: リリースビルドに `INTERNET` 権限を持たせず、健康データを外部に一切送信しない
- **ヘルスコネクトだけを見る**: データの書き込み元(HUAWEI / Fitbit など)に依存しない
- **読み取りのみ**: 宣言するヘルスコネクト権限は `READ_STEPS` と `READ_SLEEP` だけ

```
HUAWEI Band 9 → HUAWEIヘルスケア → Health Sync → ヘルスコネクト → health-pixcel(読み取りのみ)
```

## ドキュメント

| ドキュメント                                                       | 内容                                                     |
| ------------------------------------------------------------------ | -------------------------------------------------------- |
| [`docs/product-requirements.md`](docs/product-requirements.md)     | PRD(機能要件・KPI・非機能要件)                           |
| [`docs/functional-design.md`](docs/functional-design.md)           | 機能設計(データモデル・コンポーネント・アルゴリズム・UI) |
| [`docs/architecture.md`](docs/architecture.md)                     | 技術仕様(スタック・Android 統合・セキュリティ)           |
| [`docs/repository-structure.md`](docs/repository-structure.md)     | リポジトリ構造・検証スクリプトの仕様                     |
| [`docs/development-guidelines.md`](docs/development-guidelines.md) | 開発ガイドライン(規約・テスト・Git 運用)                 |
| [`docs/glossary.md`](docs/glossary.md)                             | 用語集                                                   |
| [`docs/ui-design-guidelines.md`](docs/ui-design-guidelines.md)     | UI 品質基準(§7: Flutter / Material 3)                    |

実装チケットは [GitHub Issues](https://github.com/fuji18/health-pixcel/issues?q=label%3Aticket)(`ticket` ラベル)で管理する。

## 開発環境

| 用途                          | 環境                                                                     |
| ----------------------------- | ------------------------------------------------------------------------ |
| Claude Code・静的解析・テスト | devcontainer(Flutter SDK は `post_create.sh` が導入。Android SDK は無い) |
| 実機実行・リリースビルド      | Windows + Flutter SDK + Android Studio + Pixel 10(USB デバッグ)          |
| 最終ゲート                    | GitHub Actions(リリースビルドと APK の権限検査を含む)                    |

セットアップと実機確認の手順は [`docs/development-guidelines.md`](docs/development-guidelines.md)「開発環境セットアップ」を参照。

### 検証コマンド

```bash
npm run lint           # flutter analyze + レイヤー検査 + プライバシー検査
npm run format:check   # dart format --output=none --set-exit-if-changed .
npm test               # flutter test

# Windows / CI のみ(Android SDK が必要)
flutter build apk --release
bash scripts/check-release-permissions.sh   # INTERNET なし・許可リスト外の権限なし
```

Node.js / npm はハーネス(husky・lint-staged・secretlint・prettier、Claude Code)専用で、アプリ本体は Node に依存しない。

## Claude Code での開発

スペック駆動開発のテンプレート [`claude-code-template`](https://github.com/fuji18/claude-template) をもとにしている。ルールは `CLAUDE.md` と `.claude/rules/` を参照。

### コマンド早見表

| コマンド              | タイミング               | 内容                             |
| --------------------- | ------------------------ | -------------------------------- |
| `/next-ticket`        | 日常                     | 次のチケットに着手               |
| `/add-feature [機能]` | 日常                     | 機能追加の全自動フロー           |
| `/fix-issue [番号]`   | 日常                     | Issue 修正と PR 作成             |
| `/check`              | 日常                     | 品質チェック一括実行 & 自動修正  |
| `/commit`             | 日常                     | 適切な粒度でのコミット           |
| `/resume-work`        | 日常                     | 中断作業の再開                   |
| `/status`             | 随時                     | 現在地と次の一手                 |
| `/sync-docs`          | 定期                     | 実装とドキュメントの同期         |
| `/review-docs [パス]` | 随時                     | ドキュメントの詳細レビュー       |
| `/setup-tickets`      | 随時                     | P1 / P2 着手時のチケット発行     |
| `/sync-template`      | 随時(テンプレート更新時) | テンプレートの更新差分を取り込む |

## ライセンス

[MIT](LICENSE)
