import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_screen.dart';
import 'package:health_pixcel/presentation/providers.dart';
import 'package:health_pixcel/presentation/rationale/permission_rationale_screen.dart';

/// 落ち着いた青緑(ui-design-guidelines.md §7)。アプリで唯一の色の直書き。
const _seedColor = Color(0xFF2E7D80);

ThemeData _buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  ),
);

/// アプリのルート。起動理由(launchActionProvider)で最初の画面を決める。
class HealthPixcelApp extends ConsumerWidget {
  const HealthPixcelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget home = switch (ref.watch(launchActionProvider)) {
      LaunchAction.permissionRationale => const PermissionRationaleScreen(
        closesApp: true,
      ),
      LaunchAction.normal => const DashboardScreen(),
    };
    return MaterialApp(
      title: 'health-pixcel',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      // 起動時のルート名は launchActionProvider で解釈済み。ここでは最初の 1 枚だけを積む。
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => home),
      ],
      // 名前付きルートは使わない(MaterialApp の assert を満たすためだけに渡す)。
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
    );
  }
}
