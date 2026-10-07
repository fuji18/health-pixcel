import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/app.dart';
import 'package:health_pixcel/presentation/dashboard/dashboard_screen.dart';
import 'package:health_pixcel/presentation/providers.dart';
import 'package:health_pixcel/presentation/rationale/permission_rationale_screen.dart';
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
    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.theme!.colorScheme.brightness, Brightness.light);
    expect(app.darkTheme!.colorScheme.brightness, Brightness.dark);
  });

  testWidgets('起動ルートが /permission-rationale なら利用目的画面が最初に出る', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/permission-rationale';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final fake = FakeHealthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 10, 30)),
        ],
        child: const HealthPixcelApp(),
      ),
    );
    expect(find.byType(PermissionRationaleScreen), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(PermissionRationaleScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(
      tester
          .widget<PermissionRationaleScreen>(
            find.byType(PermissionRationaleScreen),
          )
          .closesApp,
      isTrue,
    );
    expect(fake.checkAvailabilityCalls, 0);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未知の起動ルートならダッシュボードが出る', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/unknown';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
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
    expect(find.byType(PermissionRationaleScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
