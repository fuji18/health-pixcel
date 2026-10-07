import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/application/weekly_summary_service.dart';
import 'package:health_pixcel/data/health_connect_repository.dart';
import 'package:health_pixcel/data/health_repository.dart';
import 'package:health_pixcel/data/platform_channels.dart';
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

/// 起動理由。HealthPixcelApp が最初の画面を決めるために使う。テストで差し替える。
final launchActionProvider = FutureProvider<LaunchAction>(
  (ref) => const LaunchChannel().getLaunchAction(),
);
