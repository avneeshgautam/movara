import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/widgets/workout_entry_card.dart';

import 'test_setup.dart';

void main() {
  setUpAll(disableGoogleFontsNetwork);

  group('WorkoutEntry', () {
    test('serializes performedAt as a plain ISO date', () {
      final entry = WorkoutEntry(
        exerciseName: 'Squats',
        sets: 3,
        reps: 10,
        performedAt: DateTime(2026, 8, 31, 14, 30),
      );

      // The backend maps this onto a LocalDate, so it must not carry a time part.
      expect(entry.toJson()['performedAt'], '2026-08-31');
    });

    test('round-trips through JSON', () {
      final json = {
        'id': 'abc123',
        'exerciseName': 'Bench Press',
        'sets': 4,
        'reps': 8,
        'weightKg': 60.5,
        'performedAt': '2026-08-30',
        'notes': 'felt strong',
      };

      final entry = WorkoutEntry.fromJson(json);

      expect(entry.id, 'abc123');
      expect(entry.exerciseName, 'Bench Press');
      expect(entry.sets, 4);
      expect(entry.reps, 8);
      expect(entry.weightKg, 60.5);
      expect(entry.performedAt, DateTime(2026, 8, 30));
      expect(entry.notes, 'felt strong');
    });

    test('tolerates a missing weight', () {
      final entry = WorkoutEntry.fromJson({
        'id': 'xyz789',
        'exerciseName': 'Push-ups',
        'sets': 3,
        'reps': 20,
        'weightKg': null,
        'performedAt': '2026-08-30',
        'notes': null,
      });

      expect(entry.weightKg, isNull);
      expect(entry.notes, isNull);
    });
  });

  group('WorkoutEntryCard', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows sets, reps and weight', (tester) async {
      await tester.pumpWidget(wrap(WorkoutEntryCard(
        entry: WorkoutEntry(
          exerciseName: 'Deadlift',
          sets: 5,
          reps: 5,
          weightKg: 100,
          performedAt: DateTime(2026, 8, 30),
        ),
        onDelete: () {},
      )));

      expect(find.text('Deadlift'), findsOneWidget);
      // Whole numbers render without a trailing ".0".
      expect(find.text('5 sets × 5 reps @ 100 kg'), findsOneWidget);
    });

    testWidgets('omits the weight when there is none', (tester) async {
      await tester.pumpWidget(wrap(WorkoutEntryCard(
        entry: WorkoutEntry(
          exerciseName: 'Plank',
          sets: 3,
          reps: 30,
          performedAt: DateTime(2026, 8, 30),
        ),
        onDelete: () {},
      )));

      expect(find.text('3 sets × 30 reps'), findsOneWidget);
    });

    testWidgets('fires onDelete when the delete button is tapped', (tester) async {
      var deleted = false;

      await tester.pumpWidget(wrap(WorkoutEntryCard(
        entry: WorkoutEntry(
          exerciseName: 'Pull-ups',
          sets: 3,
          reps: 8,
          performedAt: DateTime(2026, 8, 30),
        ),
        onDelete: () => deleted = true,
      )));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(deleted, isTrue);
    });
  });
}
