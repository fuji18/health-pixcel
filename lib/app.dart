import 'package:flutter/material.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_screen.dart';

/// 落ち着いた青緑(ui-design-guidelines.md §7)。アプリで唯一の色の直書き。
const _seedColor = Color(0xFF2E7D80);

ThemeData _buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  ),
);

/// アプリのルート。起動理由による最初の画面の出し分けは #9 で足す。
class HealthPixcelApp extends StatelessWidget {
  const HealthPixcelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'health-pixcel',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const DashboardScreen(),
    );
  }
}
