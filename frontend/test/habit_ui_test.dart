import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/habit.dart';
import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/screens/habits_screen.dart';
import 'package:movara_app/screens/home_shell.dart';
import 'package:movara_app/screens/home_tab.dart';
import 'package:movara_app/services/goal_store.dart';
import 'package:movara_app/services/habit_store.dart';
import 'package:movara_app/services/run_store.dart';
import 'package:movara_app/services/workout_log.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

void main() {
  setUpAll(disableGoogleFontsNetwork);

  late HabitStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = HabitStore();
    await store.load();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget home() => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeTab(
            entriesFuture: Future.value(const <WorkoutEntry>[]),
            runStore: RunStore(),
            goalStore: GoalStore(),
            workoutLog: WorkoutLog(),
            habitStore: store,
            onReload: () async {},
          ),
        ),
      );

  testWidgets('empty Home invites a first habit; a template adds one',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S HABITS"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('habits-start')));
    await tester.pumpAndSettle();

    expect(find.text('Build habits that stick'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('habit-template-Meditate')));
    await tester.pumpAndSettle();
    expect(store.habits.single.name, 'Meditate');
    expect(tester.takeException(), isNull);
  });

  testWidgets('checking a habit on Home celebrates and updates the streak',
      (tester) async {
    phone(tester);
    final h = await store.add(Habit(
      id: '',
      name: 'Read',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      emoji: '📖',
    ));
    // Done the last two days → finishing today makes a 3-day streak.
    for (final ago in [1, 2]) {
      await store.toggleDay(h.id, DateTime.now().subtract(Duration(days: ago)));
    }
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(find.text('🔥 2'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('habit-row-${h.id}')));
    await tester.pump(const Duration(milliseconds: 300));
    // Only habit today → the "all done" celebration.
    expect(find.text('All habits done!'), findsOneWidget);
    await tester.pumpAndSettle(); // confetti finishes and removes itself
    expect(find.text('All habits done!'), findsNothing);

    expect(find.text('🏆 All done today!'), findsOneWidget);
    expect(find.text('🔥 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the editor creates a habit and fits a phone', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: HabitsScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('habit-new')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // editor layout at 375px

    await tester.enterText(find.byKey(const ValueKey('habit-name')), 'Push-ups');
    await tester.tap(find.text('Some days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('habit-save')));
    await tester.pumpAndSettle();

    final saved = store.habits.single;
    expect(saved.name, 'Push-ups');
    expect(saved.frequency, HabitFrequency.specificDays);
    expect(saved.days.contains(6), isFalse); // Saturday toggled off
    expect(find.text('Push-ups'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail shows stats and fixes a forgotten day', (tester) async {
    phone(tester);
    final h = await store.add(Habit(
      id: '',
      name: 'Stretch',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: HabitDetailScreen(store: store, habitId: h.id)));
    await tester.pumpAndSettle();

    expect(find.text('LAST 12 WEEKS'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Directly toggling yesterday (what a heatmap tap does) marks it done.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await store.toggleDay(h.id, yesterday);
    await tester.pumpAndSettle();
    expect(store.byId(h.id)!.doneOn(yesterday), isTrue);
    expect(find.text('🔥 1d'), findsOneWidget);
  });

  testWidgets('all seven bottom tabs fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700); // smallest common phone
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    MovaraTab? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: MovaraTabBar(
          current: MovaraTab.home,
          onChanged: (t) => tapped = t,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final t in MovaraTab.values) {
      expect(find.text(t.label), findsOneWidget, reason: '${t.label} missing');
    }
    expect(tester.takeException(), isNull); // no overflow at 320px

    await tester.tap(find.text('Habits'));
    expect(tapped, MovaraTab.habits);
  });
}
