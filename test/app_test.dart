import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/app.dart';

void main() {
  testWidgets('HealthPixcelApp が MaterialApp を表示する', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthPixcelApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
