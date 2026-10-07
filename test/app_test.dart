import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/app.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_screen.dart';
import 'package:health_pixcel/presentation/providers.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fakes/fake_health_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja'));

  testWidgets('HealthPixcelApp がダッシュボードとテーマを表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(FakeHealthRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 10, 30)),
        ],
        child: const HealthPixcelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.theme!.colorScheme.brightness, Brightness.light);
    expect(app.darkTheme!.colorScheme.brightness, Brightness.dark);
  });
}
