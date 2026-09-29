import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/services/run_store.dart';
import 'package:movara_app/services/goal_store.dart';
import 'package:movara_app/services/workout_timer.dart';
import 'package:movara_app/services/workout_log.dart';
import 'package:movara_app/services/api_service.dart';
import 'package:movara_app/screens/account_tab.dart';
import 'package:movara_app/screens/home_tab.dart';
import 'package:movara_app/screens/workout_tab.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

/// Guards the Home / Workout split: the overview lives on Home, the log and
/// the "Log a set" action live on Workout.
void main() {
  setUpAll(disableGoogleFontsNetwork);

  // Dated to earlier today so "this week" holds whenever the suite runs. A
  // fixed calendar date silently falls out of the current week once the week
  // rolls over, which used to break the weekly-count test every Monday.
  final today = DateTime.now();
  final sampleEntries = [
    WorkoutEntry(
      id: 'e1',
      exerciseName: 'Squats',
      sets: 4,
      reps: 12,
      weightKg: 60,
      performedAt: DateTime(today.year, today.month, today.day),
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
        runStore: RunStore(),
        goalStore: GoalStore(),
        workoutLog: WorkoutLog(),
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
        runStore: RunStore(),
        goalStore: GoalStore(),
        workoutLog: WorkoutLog(),
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
        workoutTimer: WorkoutTimer(),
        workoutLog: WorkoutLog(),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // Session header + category tabs + first exercise (collapsed).
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);

      // Cards start collapsed; Demo appears once expanded.
      expect(find.text('Demo'), findsNothing);
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(find.text('Demo'), findsWidgets);

      // The dashboard sections belong to the Home tab only.
      expect(find.text("TODAY'S OVERVIEW"), findsNothing);
    });

    testWidgets('switching category swaps the exercise list', (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        workoutTimer: WorkoutTimer(),
        workoutLog: WorkoutLog(),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);

      // Bicep is near the start of the (now scrollable) category bar.
      await tester.tap(find.text('Bicep'));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Curl'), findsOneWidget);
      expect(find.text('Bench Press'), findsNothing);
    });
  });

  group('AccountTab', () {
    testWidgets('renders the profile sections', (tester) async {
      await tester.pumpWidget(wrap(AccountTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        runStore: RunStore(),
        workoutLog: WorkoutLog(),
      )));
      await tester.pumpAndSettle();

      expect(find.text('BODY STATS'), findsOneWidget);
      expect(find.text('DAILY GOALS'), findsOneWidget);
      expect(find.text('BADGES'), findsOneWidget);
      // Username editing now lives in the hero, not a separate section.
      expect(find.text('Set a username'), findsOneWidget);
      // The full settings menu is present, including working actions.
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Water Reminders'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      // BMI computed from the default weight/height is Normal.
      expect(find.text('Normal'), findsOneWidget);
    });

    testWidgets('derives workout count and personal records from entries',
        (tester) async {
      final today = DateTime.now();
      await tester.pumpWidget(wrap(AccountTab(
        api: ApiService(),
        entriesFuture: Future.value([
          WorkoutEntry(
            id: 'a',
            exerciseName: 'Bench Press',
            sets: 1,
            reps: 5,
            weightKg: 80,
            performedAt: today,
          ),
          WorkoutEntry(
            id: 'b',
            exerciseName: 'Bench Press',
            sets: 1,
            reps: 3,
            weightKg: 100, // heavier -> this is the PR
            performedAt: today,
          ),
        ]),
        runStore: RunStore(),
        workoutLog: WorkoutLog(),
      )));
      await tester.pumpAndSettle();

      // Both entries are the same day => one workout day.
      expect(find.text('1'), findsWidgets);
      // Best Bench Press lift only, not the lighter one.
      expect(find.text('100 kg'), findsOneWidget);
      expect(find.text('80 kg'), findsNothing);
    });

    testWidgets('shows an empty state when there are no records',
        (tester) async {
      await tester.pumpWidget(wrap(AccountTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        runStore: RunStore(),
        workoutLog: WorkoutLog(),
      )));
      await tester.pumpAndSettle();

      expect(find.text('No records yet'), findsOneWidget);
    });
  });

  group('Gym Motivation times', () {
    testWidgets('row shows saved times; tapping it opens the time picker',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'gym_motivation_morning_min': 7 * 60 + 30,
        'gym_motivation_evening_min': 18 * 60 + 30,
      });
      await tester.pumpWidget(wrap(AccountTab(
        api: ApiService(),
        entriesFuture: Future.value(const <WorkoutEntry>[]),
        runStore: RunStore(),
        workoutLog: WorkoutLog(),
      )));
      await tester.pumpAndSettle();

      final row = find.text('7:30 AM & 6:30 PM · tap to change');
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Morning wake-up'), findsOneWidget);
      expect(find.text('Evening gym'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tapping the row edits times; it must not flip the switch on.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('toggle_Gym Motivation'), isNot(true));
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
        workoutTimer: WorkoutTimer(),
        workoutLog: WorkoutLog(),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // The collapsed card's badge reflects today's logged set.
      expect(find.text('1/3'), findsOneWidget);
      // Expanding shows the ticked set.
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets("today's logged exercise lights up its category pill",
        (tester) async {
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        // Bench Press belongs to the Chest category.
        entriesFuture: Future.value([loggedBenchPress(DateTime.now())]),
        workoutTimer: WorkoutTimer(),
        workoutLog: WorkoutLog(),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // A trained category shows a check on its pill; none logged => none.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets("yesterday's set does not carry over", (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(wrap(WorkoutTab(
        api: ApiService(),
        entriesFuture: Future.value([loggedBenchPress(yesterday)]),
        workoutTimer: WorkoutTimer(),
        workoutLog: WorkoutLog(),
        onReload: () async {},
      )));
      await tester.pumpAndSettle();

      // Nothing carried over: Bench Press badge is not 1/3, and once expanded
      // there is no ticked set.
      expect(find.text('1/3'), findsNothing);
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
  group('WorkoutSessionCard', () {
    testWidgets('idle and running states fit one row on a narrow phone',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final timer = WorkoutTimer();
      final log = WorkoutLog();
      await tester.pumpWidget(wrap(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.topCenter,
          child: WorkoutSessionCard(timer: timer, log: log),
        ),
      )));
      await tester.pump();

      expect(find.text('0 workouts today'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      // The longest-workout record moved to Home.
      expect(find.text('Longest Workout'), findsNothing);

      await tester.tap(find.text('Start'));
      // start() persists before notifying; let that future complete.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Finish'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(tester.takeException(), isNull); // no RenderFlex overflow

      await tester.runAsync(timer.reset);
      timer.dispose();
    });
  });
}
