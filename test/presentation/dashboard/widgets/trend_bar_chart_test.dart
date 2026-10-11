import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/formatters.dart';
import 'package:health_pixcel/presentation/dashboard/widgets/trend_bar_chart.dart';
import 'package:intl/date_symbol_data_local.dart';

List<DateTime> datesOf(int n) => [
  for (var i = 0; i < n; i++) DateTime(2026, 9, 1 + i),
];

Future<void> pumpChart(
  WidgetTester tester, {
  required List<DateTime> dates,
  required List<double?> values,
  String summary = '要約ラベル',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TrendBarChart(
          dates: dates,
          values: values,
          maxY: 10,
          axisLabel: (v) => '${v.round()}件',
          semanticsLabel: summary,
        ),
      ),
    ),
  );
}

List<BarChartGroupData> groupsOf(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

void main() {
  setUpAll(() => initializeDateFormatting('ja'));

  testWidgets('データあり(7 日・全日値あり)', (tester) async {
    await pumpChart(
      tester,
      dates: datesOf(7),
      values: [for (var i = 0; i < 7; i++) i + 1.0],
    );
    final primary = Theme.of(tester.element(find.byType(BarChart)))
        .colorScheme
        .primary;
    final groups = groupsOf(tester);
    expect(groups.length, 7);
    for (final g in groups) {
      final rod = g.barRods.single;
      expect(rod.backDrawRodData.show, isTrue);
      expect(rod.color, primary);
      expect(rod.width, 16);
    }
    expect(find.bySemanticsLabel('要約ラベル'), findsOneWidget);
  });

  testWidgets('一部記録なし', (tester) async {
    final values = <double?>[3, null, 0, 4, null, 5, 6];
    await pumpChart(tester, dates: datesOf(7), values: values);
    final groups = groupsOf(tester);
    for (final i in [1, 4]) {
      final rod = groups[i].barRods.single;
      expect(rod.color, Colors.transparent);
      expect(rod.backDrawRodData.show, isFalse);
    }
    expect(groups[2].barRods.single.backDrawRodData.show, isTrue);
    for (var i = 0; i < values.length; i++) {
      expect(groups[i].barRods.single.toY, values[i] ?? 0);
    }
  });

  testWidgets('縦軸ラベル', (tester) async {
    await pumpChart(
      tester,
      dates: datesOf(7),
      values: [for (var i = 0; i < 7; i++) i + 1.0],
    );
    expect(find.text('5件'), findsAtLeastNWidgets(1));
    expect(find.text('10件'), findsAtLeastNWidgets(1));
    expect(find.text('0件'), findsNothing);
  });

  testWidgets('全日記録なし', (tester) async {
    await pumpChart(
      tester,
      dates: datesOf(7),
      values: List<double?>.filled(7, null),
    );
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('この期間の記録はありません'), findsOneWidget);
    expect(find.bySemanticsLabel('要約ラベル'), findsOneWidget);
  });

  testWidgets('30 日', (tester) async {
    final dates = datesOf(30);
    await pumpChart(
      tester,
      dates: dates,
      values: [for (var i = 0; i < 30; i++) 1.0 + i % 5],
    );
    final groups = groupsOf(tester);
    expect(groups.length, 30);
    expect(groups.first.barRods.single.width, 6);
    expect(find.text(formatShortDate(dates.last)), findsOneWidget);
    expect(find.text(formatShortDate(dates[28])), findsNothing);
  });
}
