import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/app.dart';
import 'package:health_pixcel/domain/models/health_status.dart';
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
          launchActionProvider.overrideWith((ref) async => LaunchAction.normal),
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

  testWidgets('起動理由が permissionRationale なら利用目的画面が最初に出る', (tester) async {
    final fake = FakeHealthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 10, 30)),
          launchActionProvider.overrideWith(
            (ref) async => LaunchAction.permissionRationale,
          ),
        ],
        child: const HealthPixcelApp(),
      ),
    );
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
  });

  testWidgets('起動理由の判定中は空の画面を出す', (tester) async {
    final completer = Completer<LaunchAction>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(FakeHealthRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 10, 30)),
          launchActionProvider.overrideWith((ref) => completer.future),
        ],
        child: const HealthPixcelApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.byType(PermissionRationaleScreen), findsNothing);

    completer.complete(LaunchAction.normal);
    await tester.pumpAndSettle();
  });
}
