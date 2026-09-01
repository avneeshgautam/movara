import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movara_app/theme/app_theme.dart';
import 'package:movara_app/widgets/dashboard_widgets.dart';

import 'test_setup.dart';

/// The bars are drawn with [FractionallySizedBox]. If it is ever placed back
/// under a widget that hands it unbounded vertical constraints, the fill
/// silently collapses to zero and every bar renders empty -- which is exactly
/// the bug this guards.
void main() {
  setUpAll(disableGoogleFontsNetwork);

  Future<void> pumpChart(WidgetTester tester, List<double> values) {
    return tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: WeeklyChart(values: values, todayIndex: 0),
          ),
        ),
      ),
    ));
  }

  testWidgets('a full-height bar actually paints at full height', (tester) async {
    await pumpChart(tester, [1.0, 0, 0, 0, 0, 0, 0]);

    final boxes = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(boxes.length, 7);
    expect(boxes.first.heightFactor, 1.0);

    // The rendered fill must have real height, not collapse to zero.
    final fillHeight = tester
        .getSize(find.byType(FractionallySizedBox).first)
        .height;
    expect(fillHeight, greaterThan(0));
  });

  testWidgets('bars scale proportionally to their value', (tester) async {
    await pumpChart(tester, [1.0, 0.5, 0, 0, 0, 0, 0]);

    final full = tester.getSize(find.byType(FractionallySizedBox).at(0)).height;
    final half = tester.getSize(find.byType(FractionallySizedBox).at(1)).height;

    expect(half, greaterThan(0));
    expect(half, lessThan(full));
    // Allow a pixel of rounding slack.
    expect((full / 2 - half).abs(), lessThan(2));
  });

  testWidgets('an empty week renders without overflow', (tester) async {
    await pumpChart(tester, List<double>.filled(7, 0));
    expect(tester.takeException(), isNull);
  });
}
