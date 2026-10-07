import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_controller.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_state.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/sleep_section.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/status_message.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/steps_section.dart';

/// 唯一の画面。DashboardState に応じて表示を出し分ける。
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final AppLifecycleListener _lifecycle;

  DashboardController get _controller =>
      ref.read(dashboardControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _controller.onResumed());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('health-pixcel')),
      body: _buildBody(async),
    );
  }

  Widget _buildBody(AsyncValue<DashboardState> async) {
    if (async.isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
      );
    }
    final List<Widget> children;
    if (async.hasError) {
      children = [
        StatusMessage(
          title: 'データを読み込めませんでした',
          actions: [StatusAction('再読み込み', _retry)],
        ),
      ];
    } else {
      children = _buildChildren(async.requireValue);
    }
    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  List<Widget> _buildChildren(DashboardState state) {
    return switch (state) {
      DashboardUnavailable(:final availability) => [
        switch (availability) {
          HealthAvailability.updateRequired => StatusMessage(
            title: 'ヘルスコネクトの更新が必要です',
            actions: [StatusAction('ヘルスコネクトを更新する', _openStore)],
          ),
          HealthAvailability.notInstalled ||
          HealthAvailability.available => StatusMessage(
            title: 'ヘルスコネクトを利用できません',
            body: 'Play ストアでヘルスコネクトの状態を確認してください',
            actions: [StatusAction('Play ストアを開く', _openStore)],
          ),
        },
      ],
      DashboardNeedsPermission() => [
        StatusMessage(
          title: '歩数と睡眠を表示するには、ヘルスコネクトの読み取り権限が必要です',
          body: 'データの読み取りのみ行い、端末の外には送信しません',
          actions: [
            StatusAction('権限を許可する', _requestPermissions),
            StatusAction('ヘルスコネクトの設定を開く', _openSettings),
          ],
        ),
      ],
      DashboardReady() => _buildReady(state),
    };
  }

  List<Widget> _buildReady(DashboardReady state) {
    final today = state.range.today;
    return [
      if (state.isAllEmpty) ...[
        StatusMessage(
          title: 'ヘルスコネクトにデータがありません',
          body: 'Health Sync の同期設定を確認してください',
          actions: [StatusAction('再読み込み', _retry)],
        ),
        const SizedBox(height: 24),
      ],
      SleepSection(
        result: state.sleep,
        today: today,
        onRequestPermission: _requestPermissions,
        onOpenSettings: _openSettings,
        onRetry: _retry,
      ),
      const Divider(height: 32),
      StepsSection(
        result: state.steps,
        today: today,
        onRequestPermission: _requestPermissions,
        onOpenSettings: _openSettings,
        onRetry: _retry,
      ),
    ];
  }

  void _retry() => _controller.refresh();

  void _requestPermissions() => _controller.requestPermissions();

  Future<void> _openSettings() async {
    final opened = await _controller.openSettings();
    if (!opened && mounted) _showSnackBar('ヘルスコネクトを開けませんでした');
  }

  Future<void> _openStore() async {
    final opened = await _controller.openStore();
    if (!opened && mounted) _showSnackBar('Play ストアを開けませんでした');
  }

  void _showSnackBar(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
