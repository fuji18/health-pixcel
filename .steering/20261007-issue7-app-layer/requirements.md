# 要求: アプリ層・状態管理(WeeklySummaryService / DashboardController)(#7)

## 背景・目的

起動・再読み込み・権限リクエスト・フォアグラウンド復帰の状態遷移を、画面から独立してテスト可能な形で実装する(F1 の「再起動不要」と F4 の各状態の土台)。

## スコープ

- `WeeklySummaryService`(`lib/application/weekly_summary_service.dart`)。時計の注入、歩数・睡眠の独立取得、`Future.wait`
- `DashboardState` と `isAllEmpty`(`lib/presentation/dashboard/dashboard_state.dart`)
- `DashboardController` と `dashboardControllerProvider`(`lib/presentation/dashboard/dashboard_controller.dart`)。`_fetch` の多重実行の扱い、`_Snapshot`、`onResumed`、`requestPermissions` の `try/finally`
- `lib/presentation/providers.dart`(`clockProvider` / `healthRepositoryProvider` / `weeklySummaryServiceProvider`)
- フェイクのリポジトリ(`test/fakes/fake_health_repository.dart`)と固定時計によるユニットテスト

## スコープ外

- 画面・ウィジェット(#8)。スナックバーの表示も #8(下記の設計変更を参照)
- MethodChannel・`launchActionProvider`(#9)

## 受け入れ条件(Issue #7 より)

- [ ] 機能設計書「テスト戦略」に列挙された `WeeklySummaryService` / `DashboardController`(追加ケース含む)/ `isAllEmpty` のテストがすべてある
- [ ] `lib/application/` が `flutter` / `flutter_riverpod` を import しない
- [ ] `_fetch()` が例外を外に出さない
- [ ] `flutter analyze` / format 検査 / `flutter test` / `scripts/check-*.sh`(layer / privacy)が通る

## 設計書からの変更(司令塔判断。docs に反映する)

- `openSettings()` / `openStore()` は `Future<bool>` を返し、スナックバーは画面(#8)が出す(コントローラーは `BuildContext` を持たないため)
- `requestPermissions()` の `AsyncLoading` は Riverpod 3 の仕様上、前回の値を引き継ぐ(`state = AsyncLoading()` は自動で `copyWithPrevious` される)。`isLoading == true` になり、`when()` の既定(`skipLoadingOnReload: false`)ではローディング表示になる
