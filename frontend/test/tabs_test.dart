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
    testWidgets('shows the category session, not the dashboard', (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // Session header + category tabs + first exercise.
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Demo'), findsWidgets);

      // The dashboard sections belong to the Home tab only.
      expect(find.text("TODAY'S OVERVIEW"), findsNothing);
    });

    testWidgets('switching category swaps the exercise list', (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);

      await tester.tap(find.text('Legs'));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Squat'), findsOneWidget);
      expect(find.text('Bench Press'), findsNothing);
    });
  });

  group('completed sets persist for the day', () {
    WorkoutEntry loggedBenchPress(DateTime when) => WorkoutEntry(
          id: 'logged-1',
          exerciseName: 'Bench Press',
          sets: 1,
          reps: 8,
          weightKg: 40,
          performedAt: when,
        );

    testWidgets("today's logged set shows as ticked on a fresh mount",
        (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value([loggedBenchPress(DateTime.now())]),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // Bench Press ships with 3 default sets; one is logged today.
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets("yesterday's set does not carry over", (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value([loggedBenchPress(yesterday)]),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // Several exercises all read "0 / 3"; what matters is that nothing is
      // ticked and Bench Press did not keep yesterday's progress.
      expect(find.text('1 / 3'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
