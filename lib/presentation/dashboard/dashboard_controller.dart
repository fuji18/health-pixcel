import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/domain/models/daily_sleep.dart';
import 'package:health_pixcel/domain/models/daily_steps.dart';
import 'package:health_pixcel/domain/models/date_range.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/metric_result.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_state.dart';
import 'package:health_pixcel/presentation/providers.dart';

/// 画面状態のプロバイダー。
final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// 利用可否が available 以外のときは権限を取得しないため null。
typedef _Snapshot = ({
  HealthAvailability availability,
  ({PermissionStatus steps, PermissionStatus sleep})? permissions,
});

/// ダッシュボードの状態遷移(機能設計書「DashboardController」)。
class DashboardController extends AsyncNotifier<DashboardState> {
  Future<DashboardState>? _inFlight;
  bool _requestingPermission = false;
  _Snapshot? _lastSnapshot;

  @override
  Future<DashboardState> build() => _fetch();

  /// 前回の値を表示したまま読み直す(引っぱって更新・「再読み込み」)。
  Future<void> refresh() async {
    final next = await _fetch();
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  /// 権限をリクエストし、許可後の状態で読み直す。リクエスト中の再呼び出しは無視する。
  Future<void> requestPermissions() async {
    if (_requestingPermission) return;
    final repository = ref.read(healthRepositoryProvider);
    _requestingPermission = true;
    try {
      await repository.requestPermissions();
    } catch (_) {
      // 失敗しても画面はエラーにせず、権限状態を読み直して表示する
    } finally {
      _requestingPermission = false;
    }
    if (!ref.mounted) return;
    state = const AsyncLoading<DashboardState>();
    final next = await _fetch(force: true);
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  /// フォアグラウンド復帰時。利用可否・権限が前回と変わっていれば読み直す。
  Future<void> onResumed() async {
    if (_requestingPermission) return;
    final repository = ref.read(healthRepositoryProvider);
    final _Snapshot current;
    try {
      final availability = await repository.checkAvailability();
      current = (
        availability: availability,
        permissions: availability == HealthAvailability.available
            ? await repository.checkPermissions()
            : null,
      );
    } catch (_) {
      if (!ref.mounted) return;
      await refresh();
      return;
    }
    if (!ref.mounted) return;
    if (current != _lastSnapshot) await refresh();
  }

  /// ヘルスコネクトの権限設定画面を開く。開けなかったら false(画面がスナックバーを出す)。
  Future<bool> openSettings() async {
    try {
      return await ref.read(healthRepositoryProvider).openPermissionSettings();
    } catch (_) {
      return false;
    }
  }

  /// ヘルスコネクトの入手・更新ページを開く。開けなかったら false。
  Future<bool> openStore() async {
    try {
      return await ref.read(healthRepositoryProvider).openHealthConnectStore();
    } catch (_) {
      return false;
    }
  }

  Future<DashboardState> _fetch({bool force = false}) async {
    while (_inFlight != null) {
      final running = _inFlight!;
      if (!force) return running; // 合流する
      final discarded = await running; // 古い結果は捨てる
      if (!ref.mounted) return discarded;
    }
    late final Future<DashboardState> future;
    future = _fetchBody().whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<DashboardState> _fetchBody() async {
    final repository = ref.read(healthRepositoryProvider);
    final service = ref.read(weeklySummaryServiceProvider);
    DateRange? range;
    try {
      // 1. 利用可否
      final availability = await repository.checkAvailability();
      if (availability != HealthAvailability.available) {
        _lastSnapshot = (availability: availability, permissions: null);
        return DashboardUnavailable(availability);
      }
      // 2. 権限
      final permissions = await repository.checkPermissions();
      _lastSnapshot = (
        availability: HealthAvailability.available,
        permissions: permissions,
      );
      final stepsGranted = permissions.steps == PermissionStatus.granted;
      final sleepGranted = permissions.sleep == PermissionStatus.granted;
      // 3. 両方未許可
      if (!stepsGranted && !sleepGranted) {
        return const DashboardNeedsPermission();
      }
      // 4. 許可済みの種別だけ並行に読む
      final r = range = service.currentRange();
      final (
        MetricResult<DailySteps> stepsResult,
        MetricResult<DailySleep> sleepResult,
      ) = await (
        stepsGranted
            ? service.loadSteps(r)
            : Future<MetricResult<DailySteps>>.value(
                const MetricPermissionDenied<DailySteps>(),
              ),
        sleepGranted
            ? service.loadSleep(r)
            : Future<MetricResult<DailySleep>>.value(
                const MetricPermissionDenied<DailySleep>(),
              ),
      ).wait;
      var steps = stepsResult;
      var sleep = sleepResult;
      // 5. 読み込み中の unavailable は利用可否を再確認する
      if (_isUnavailable(steps) || _isUnavailable(sleep)) {
        final again = await repository.checkAvailability();
        if (again != HealthAvailability.available) {
          _lastSnapshot = (availability: again, permissions: null);
          return DashboardUnavailable(again);
        }
        if (_isUnavailable(steps)) {
          steps = const MetricFailed<DailySteps>(HealthErrorKind.readFailed);
        }
        if (_isUnavailable(sleep)) {
          sleep = const MetricFailed<DailySleep>(HealthErrorKind.readFailed);
        }
      }
      // 6.
      return DashboardReady(range: r, steps: steps, sleep: sleep);
    } catch (_) {
      // 7. 想定外の例外。値をログに出さない。次の復帰で必ず読み直すため snapshot を捨てる
      _lastSnapshot = null;
      return DashboardReady(
        range: range ?? service.currentRange(),
        steps: const MetricFailed<DailySteps>(HealthErrorKind.readFailed),
        sleep: const MetricFailed<DailySleep>(HealthErrorKind.readFailed),
      );
    }
  }

  static bool _isUnavailable(MetricResult<Object?> result) =>
      result is MetricFailed<Object?> &&
      result.kind == HealthErrorKind.unavailable;
}
