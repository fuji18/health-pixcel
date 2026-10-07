# 要求: データ層 HealthConnectRepository(#6)

## 背景・目的

ヘルスコネクトへのアクセスをデータ層に閉じ込め、上位層にプラグインの型・例外を漏らさない(PRD「移植性・保守性」)。あわせて、設計時点で資料ベースだった `health` 13 の挙動を確かめる。

## スコープ

- `HealthRepository`(抽象)・`HealthReadException`(`lib/data/health_repository.dart`)
- `HealthConnectRepository`(`lib/data/health_connect_repository.dart`)。`configure()` は `late final` で 1 回だけ
- 例外を `HealthErrorKind` に変換する(元の例外やデータ点をログに出さない)
- フェイクの `Health` を注入した変換規則のユニットテスト(`test/data/health_connect_repository_test.dart`)
- 「最初の実装チケットで確認する事項」のうち `health` 13 の項目の確認(ソースで実施済み。結果は `docs/architecture.md` に記録済み)

## スコープ外

- `openPermissionSettings` の MethodChannel 実装(#9。ここでは `false` を返すだけ)
- `lib/data/platform_channels.dart`(#9)
- 状態管理・画面・providers(#7 以降)
- 実機での確認(#10)

## 受け入れ条件(Issue #6 より。1 点は司令塔判断で変更)

- [ ] `package:health/` が `lib/data/` 以外に出現しない(`check-layer-imports.sh`)
- [ ] ~~`getTotalStepsInInterval` の `null` / `0` が `null`(記録なし)になる~~ → **`0` が `null`(記録なし)、`null` が `HealthReadException(readFailed)` になる**(理由: `health` 13.3.2 はネイティブ側の例外を握りつぶして `null` を返し、記録なしでは `0` を返す。ユーザー承認済み 2026-10-07)
- [ ] `dateTo <= dateFrom` のセッションが破棄される
- [ ] `UnsupportedError` → `unavailable`、その他の例外 → `readFailed` に変換される
- [ ] 確認事項の結果を PR 本文に記録し、設計と違った点は docs に反映済み
- [ ] `flutter analyze` / format 検査 / `flutter test` / `scripts/check-*.sh`(layer / privacy)が通る

## 根拠

- `docs/functional-design.md`「HealthRepository(データ層・抽象)」「HealthConnectRepository(データ層・Android 実装)」「アルゴリズム設計」A2「テスト戦略」
- `docs/architecture.md`「最初の実装チケットで確認する事項」「テスト戦略」
- `docs/repository-structure.md`「lib/data/(データ層)」「test/(テスト)」
