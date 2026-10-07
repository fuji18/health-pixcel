# .harness/

ハーネスの状態置き場(`/harness-setup` が生成)。

| ファイル | 内容 |
|---|---|
| `decisions.jsonl` | 横断的な技術判断とチケット完了時の実測記録。1 行 1 JSON、**追記のみ・削除禁止** |
| `state.json` | ハーネスの構成(モデル・Agent Teams の有無) |
| `mode` | ハーネスモード(git 追跡外。人間が切り替える) |
| `codex-runs/` | Codex 委託の実行記録(git 追跡外) |

自作しないもの: 進捗(`.steering/*/tasklist.md`)、スナップショット(組み込みの `/rewind`)、セッション横断の学び(auto-memory)。
