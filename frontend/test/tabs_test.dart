import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/services/api_service.dart';
import 'package:movara_app/screens/home_tab.dart';
import 'package:movara_app/screens/workout_tab.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

/// Guards the Home / Workout split: the overview lives on Home, the log and
/// the "Log a set" action live on Workout.
void main() {
  setUpAll(disableGoogleFontsNetwork);

  final sampleEntries = [
    WorkoutEntry(
      id: 'e1',
      exerciseName: 'Squats',
      sets: 4,
      reps: 12,
      weightKg: 60,
      performedAt: DateTime(2026, 8, 31),
    ),
  ];

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      );

  group('HomeTab', () {
    testWidgets('shows the dashboard, not the log actions', (tester) async {
      await tester.pumpWidget(wrap(HomeTab(
        entriesFuture: Future.value(sampleEntries),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // SectionHeader renders titles uppercased.
      expect(find.text("TODAY'S OVERVIEW"), findsOneWidget);

      // The logging affordances belong to the Workout tab only.
      expect(find.text('Log a set'), findsNothing);
      expect(find.text('WORKOUT LOG'), findsNothing);

      // Further down the (lazy) list -- scroll it into view to confirm.
      await tester.scrollUntilVisible(
        find.text('THIS WEEK'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('THIS WEEK'), findsOneWidget);
    });

    testWidgets('derives the weekly set count from real entries', (tester) async {
      await tester.pumpWidget(wrap(HomeTab(
        entriesFuture: Future.value(sampleEntries),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // 4 sets logged this week.
      expect(find.text('4'), findsWidgets);
    });
  });

  group('WorkoutTab', () {
    testWidgets('shows the log and the Log a set button', (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value(sampleEntries),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Log a set'), findsOneWidget);
      expect(find.text('WORKOUT LOG'), findsOneWidget);
      expect(find.text('Squats'), findsOneWidget);

      // The dashboard sections do not appear here.
      expect(find.text("TODAY'S OVERVIEW"), findsNothing);
    });

    testWidgets('shows an empty state when there are no sets', (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('No sets logged yet'), findsOneWidget);
    });
  });
}
