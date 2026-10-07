import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/application/weekly_summary_service.dart';
import 'package:health_pixcel/data/health_connect_repository.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

/// 現在時刻。テストで固定値に差し替える。
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// ヘルスデータへのアクセス。テストでフェイクに差し替える。
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthConnectRepository(),
);

/// 直近 7 日の組み立て。
final weeklySummaryServiceProvider = Provider<WeeklySummaryService>(
  (ref) => WeeklySummaryService(
    ref.watch(healthRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

/// 利用目的画面の起動ルート(MainActivity.getInitialRoute と同じ値)。
const permissionRationaleRoute = '/permission-rationale';

/// 起動理由。起動時のルート名(Android の初期ルート)から同期的に決まる。
final launchActionProvider = Provider<LaunchAction>(
  (ref) =>
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
          permissionRationaleRoute
      ? LaunchAction.permissionRationale
      : LaunchAction.normal,
);
