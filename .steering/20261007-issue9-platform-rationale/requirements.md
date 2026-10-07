# 要求: プラットフォーム連携と利用目的画面(#9)

## 背景・目的

ヘルスコネクトが要求する「権限の利用目的」の表示先と、権限ダイアログが出なくなったときの逃げ道(ヘルスコネクトの設定画面を開く)を実装する(F1・F4)。

## スコープ

- `MainActivity.kt`: MethodChannel `health_pixcel/health_connect_settings`(`open`)と `health_pixcel/launch`(`getLaunchAction`)
- `lib/data/platform_channels.dart`(`LaunchChannel` / `HealthConnectSettingsChannel`)、`HealthConnectRepository.openPermissionSettings` の実装
- `launchActionProvider`、`HealthPixcelApp` による最初の画面の出し分け
- `PermissionRationaleScreen`(本文と「閉じる」の 2 通りの戻り方)、案内画面(`DashboardNeedsPermission`)の「詳しく見る」からの遷移
- ユニット/ウィジェットテスト

## スコープ外

- `onNewIntent` の対応(MVP ではコールドスタートのみ)
- `AndroidManifest.xml` の変更(#4 で構成済み。本チケットでは触らない)

## 受け入れ条件(Issue #9 より)

- [ ] `resolveActivity` を使わず、`startActivity` の例外で判定している(`MANAGE_HEALTH_PERMISSIONS` → `HEALTH_HOME_SETTINGS` → `false`)
- [ ] 未知の値・例外の起動理由が `LaunchAction.normal` になる
- [ ] `HealthPixcelApp`: `permissionRationale` で `PermissionRationaleScreen`、`normal` で `DashboardScreen` が最初に出る(テスト)
- [ ] `PermissionRationaleScreen`: 本文の箇条書きが表示され、「詳しく見る」から開いた場合は「閉じる」で戻る(テスト)
- [ ] 追加の依存パッケージなし
- [ ] `flutter analyze` / format 検査 / `flutter test` / `scripts/check-*.sh`(layer / privacy)と CI のリリースビルド・権限検査が通る

## 設計書からの変更(司令塔判断)

- 設定画面チャネルの Dart クラス名を `HealthConnectSettingsChannel` とする(docs は「設定画面チャネル」とだけ書いており名前が未定)。docs の変更は不要
