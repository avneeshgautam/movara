import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/screens/workout_session.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

/// A slow server whose writes only land when the test says so, so the races
/// behind "tapped two sets quickly and one got skipped" are reproducible.
class _SlowServer {
  final entries = <WorkoutEntry>[];
  final _gates = <Completer<void>>[];
  var logs = 0;
  var unlogs = 0;
  var _next = 0;

  Future<String?> log(String name, int reps, double weight) async {
    logs++;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    final id = 'id${(_next++).toString().padLeft(3, '0')}';
    entries.add(WorkoutEntry(
      id: id,
      exerciseName: name,
      sets: 1,
      reps: reps,
      weightKg: weight,
      performedAt: DateTime.now(),
    ));
    return id;
  }

  Future<void> unlog(String id) async {
    unlogs++;
    entries.removeWhere((e) => e.id == id);
  }

  /// Let the oldest in-flight write land.
  void landNext() => _gates.removeAt(0).complete();
}

void main() {
  setUpAll(disableGoogleFontsNetwork);

  late _SlowServer server;
  late StateSetter refresh; // stands in for the shell re-fetching entries

  Future<void> pumpSession(WidgetTester tester) async {
    server = _SlowServer();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          refresh = setState;
          return WorkoutSession(
            entries: List.of(server.entries),
            onLogSet: server.log,
            onUnlogSet: server.unlog,
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press')); // expand the first card
    await tester.pumpAndSettle();
  }

  Finder tick(int i) => find.byKey(ValueKey('set-tick-$i'));
  bool ticked(int i) => find
      .descendant(of: tick(i), matching: find.byIcon(Icons.check))
      .evaluate()
      .isNotEmpty;

  Future<void> reload(WidgetTester tester) async {
    refresh(() {});
    await tester.pump();
  }

  testWidgets('two quick taps both stick while the first save lands',
      (tester) async {
    await pumpSession(tester);

    await tester.tap(tick(0));
    await tester.pump();
    await tester.tap(tick(1));
    await tester.pump();
    expect(ticked(0) && ticked(1), isTrue, reason: 'both tick instantly');

    // First save lands and the list is re-fetched while set 2 is still saving:
    // this used to un-tick set 2.
    server.landNext();
    await tester.pump();
    await reload(tester);
    expect(ticked(0) && ticked(1), isTrue);

    server.landNext();
    await tester.pump();
    await reload(tester);
    expect(ticked(0) && ticked(1), isTrue);
    expect(server.logs, 2);
    expect(server.entries, hasLength(2));
  });

  testWidgets('the row you tap is the row that stays ticked', (tester) async {
    await pumpSession(tester);

    await tester.tap(tick(1)); // set 2 first, not set 1
    await tester.pump();
    server.landNext();
    await tester.pump();
    await reload(tester);

    expect(ticked(1), isTrue);
    expect(ticked(0), isFalse, reason: 'used to jump to the first row');
  });

  testWidgets('a fast double tap ends unticked with nothing left saved',
      (tester) async {
    await pumpSession(tester);

    await tester.tap(tick(0));
    await tester.pump();
    await tester.tap(tick(0));
    await tester.pump();
    expect(ticked(0), isFalse);

    // The first tap's save lands after the un-tick; the queued follow-up must
    // remove it rather than leave an orphan logged set.
    server.landNext();
    await tester.pump();
    await tester.pump();
    await reload(tester);

    expect(ticked(0), isFalse);
    expect(server.logs, 1);
    expect(server.unlogs, 1);
    expect(server.entries, isEmpty);
  });
}
