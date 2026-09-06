import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/run_record.dart';
import 'package:movara_app/services/run_store.dart';
import 'package:movara_app/services/run_tracker.dart';
import 'package:movara_app/screens/running_tab.dart';
import 'package:movara_app/theme/app_theme.dart';
import 'package:movara_app/widgets/route_map.dart';
import 'package:movara_app/widgets/share_card.dart';

import 'test_setup.dart';

Position _at(double lat, double lng, {double accuracy = 5}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

RunRecord _run({
  String id = 'r',
  DateTime? at,
  int seconds = 600,
  double metres = 2000,
}) =>
    RunRecord(
      id: id,
      startedAt: at ?? DateTime.now(),
      elapsedSeconds: seconds,
      distanceMeters: metres,
      route: const [RunPoint(28.61, 77.20), RunPoint(28.62, 77.21)],
    );


/// A blank tile, so map widgets can be tested without a network.
class _OfflineTiles extends TileProvider {
  static final _pixel = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

void main() {
  group('RunRecord', () {
    test('derives distance and pace from what was recorded', () {
      final run = _run(seconds: 1800, metres: 5000);

      expect(run.distanceKm, closeTo(5, 0.001));
      // 30 min over 5 km = 6:00 per km.
      expect(run.paceSecondsPerKm, closeTo(360, 0.1));
      expect(formatPace(run.paceSecondsPerKm), '6:00');
      expect(formatDuration(run.elapsed), '30:00');
    });

    test('reports no pace until the distance is meaningful', () {
      // A few metres of GPS drift must not read as a 90 s/km world record.
      expect(_run(seconds: 60, metres: 10).paceSecondsPerKm, 0);
      expect(formatPace(0), '--:--');
    });

    test('survives a JSON round trip', () {
      final run = _run(id: 'abc', seconds: 900, metres: 3210);
      final back = RunRecord.fromJson(run.toJson());

      expect(back.id, 'abc');
      expect(back.elapsedSeconds, 900);
      expect(back.distanceMeters, 3210);
      expect(back.route.length, run.route.length);
      expect(back.route.first.lat, closeTo(28.61, 0.0001));
    });

    test('formats an hour-long run with hours', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1:05:03');
    });
  });

  group('RunStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts empty, with no bests to show', () async {
      final store = RunStore();
      await store.load();

      expect(store.runs, isEmpty);
      expect(store.longestRun, isNull);
      expect(store.fastestPace, isNull);
      expect(store.totalKmThisWeek(), 0);
      expect(store.kmByWeekday(), List.filled(7, 0.0));
    });

    test('keeps runs across a reload', () async {
      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'one'));

      final reopened = RunStore();
      await reopened.load();

      expect(reopened.runs.single.id, 'one');
    });

    test('newest run comes first', () async {
      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'old', at: DateTime(2026, 1, 1)));
      await store.add(_run(id: 'new', at: DateTime(2026, 6, 1)));

      expect(store.runs.map((r) => r.id), ['new', 'old']);
    });

    test('removes by id', () async {
      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'a'));
      await store.add(_run(id: 'b'));
      await store.remove('a');

      expect(store.runs.map((r) => r.id), ['b']);
    });

    test('buckets this week by weekday and ignores older runs', () async {
      final monday = DateTime(2026, 8, 31, 7); // a Monday
      final wednesday = DateTime(2026, 9, 2, 7);
      final lastWeek = DateTime(2026, 8, 25, 7);
      final now = DateTime(2026, 9, 5, 12); // that Saturday

      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'm', at: monday, metres: 3000));
      await store.add(_run(id: 'w', at: wednesday, metres: 5000));
      await store.add(_run(id: 'old', at: lastWeek, metres: 9000));

      final week = store.kmByWeekday(now: now);
      expect(week[0], closeTo(3, 0.001)); // Monday
      expect(week[2], closeTo(5, 0.001)); // Wednesday
      expect(week[4], 0); // Friday, nothing logged
      expect(store.totalKmThisWeek(now: now), closeTo(8, 0.001));
      expect(store.runsThisWeek(now: now), 2);
    });

    test('picks the real bests', () async {
      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'short', seconds: 300, metres: 1000)); // 5:00/km
      await store.add(_run(id: 'long', seconds: 3000, metres: 10000)); // 5:00/km
      await store.add(_run(id: 'fast', seconds: 600, metres: 3000)); // 3:20/km

      expect(store.longestRun?.id, 'long');
      expect(store.longestDuration?.id, 'long');
      expect(store.fastestPace?.id, 'fast');
      expect(store.totalKmAllTime, closeTo(14, 0.001));
    });

    test('a jog-on-the-spot does not win the pace record', () async {
      final store = RunStore();
      await store.load();
      await store.add(_run(id: 'real', seconds: 1800, metres: 5000));
      // 200 m of drift in 10 s would compute an absurd pace.
      await store.add(_run(id: 'drift', seconds: 10, metres: 200));

      expect(store.fastestPace?.id, 'real');
    });
  });

  group('RunTracker', () {
    test('refuses to record without location permission', () async {
      final tracker = RunTracker(
        positionStream: () => const Stream<Position>.empty(),
        ensurePermission: () async => false,
      );
      await tracker.start();

      expect(tracker.state, TrackerState.denied);
      expect(tracker.error, isNotNull);
      expect(tracker.route, isEmpty);
      tracker.dispose();
    });

    test('builds the route and distance from GPS fixes', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      positions.add(_at(28.6229, 77.2090)); // ~1 km north
      await Future<void>.delayed(Duration.zero);

      expect(tracker.route.length, 2);
      expect(tracker.distanceKm, closeTo(1.0, 0.05));

      await positions.close();
      tracker.dispose();
    });

    test('a phone sitting still does not accumulate distance', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      // GPS noise at rest wobbles around a fixed point rather than walking
      // off in one direction; each wobble here is well under a metre.
      for (var i = 0; i < 40; i++) {
        final wobble = (i.isEven ? 1 : -1) * 0.00001; // ~1 m either side
        positions.add(_at(28.6139 + wobble, 77.2090 + wobble));
      }
      await Future<void>.delayed(Duration.zero);

      expect(tracker.distanceMeters, 0,
          reason: 'a phone on a table must not log any distance');

      await positions.close();
      tracker.dispose();
    });

    test('ignores fixes the device reports as unreliable', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      // A 500 m-accurate fix would otherwise draw a wild spike in the route.
      positions.add(_at(28.7000, 77.3000, accuracy: 500));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.route.length, 1);
      expect(tracker.distanceMeters, 0);

      await positions.close();
      tracker.dispose();
    });

    test('real movement past the jitter threshold is counted', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      // ~6 m north: real movement, well past the jitter gate.
      positions.add(_at(28.613954, 77.2090));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.distanceMeters, greaterThan(3.0));

      await positions.close();
      tracker.dispose();
    });


    test('reports a weak signal instead of discarding fixes in silence',
        () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      // Wi-Fi positioning on a laptop indoors: a fix arrives, but it is far
      // too vague to plot.
      positions.add(_at(28.6139, 77.2090, accuracy: 400));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.route, isEmpty);
      expect(tracker.hasWeakSignal, isTrue,
          reason: 'the user must be told why nothing is being drawn');
      expect(tracker.accuracyMetres, 400);

      await positions.close();
      tracker.dispose();
    });

    test('accepts the everyday accuracy a phone browser reports', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      // 40 m is ordinary for a browser outdoors; the first gate rejected it.
      positions.add(_at(28.6139, 77.2090, accuracy: 40));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.route.length, 1);
      expect(tracker.hasWeakSignal, isFalse);

      await positions.close();
      tracker.dispose();
    });

    test('a vague fix cannot invent distance', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      // Two fixes 20 m apart, each only accurate to 90 m: that difference is
      // the estimate drifting, not the runner moving.
      positions.add(_at(28.6139, 77.2090, accuracy: 90));
      positions.add(_at(28.61408, 77.2090, accuracy: 90));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.distanceMeters, 0);
      expect(tracker.route.length, 1);

      await positions.close();
      tracker.dispose();
    });

    test('standing still still yields a run, with the one position held',
        () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      await Future<void>.delayed(Duration.zero);

      final run = tracker.finish();
      // Regression: this case used to be reported as "GPS did not report a
      // position", which was untrue and unfixable-looking.
      expect(run, isNotNull);
      expect(run!.route.length, 1);
      expect(run.distanceMeters, 0);

      await positions.close();
      tracker.dispose();
    });

    test('pausing stops the route growing, resuming continues it', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      await Future<void>.delayed(Duration.zero);
      tracker.pause();

      positions.add(_at(28.6229, 77.2090));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.route.length, 1, reason: 'paused fixes are not recorded');
      expect(tracker.distanceMeters, 0);

      tracker.resume();
      positions.add(_at(28.6319, 77.2090));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.route.length, 2);

      await positions.close();
      tracker.dispose();
    });

    test('finish hands back a record carrying the route', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();

      positions.add(_at(28.6139, 77.2090));
      positions.add(_at(28.6229, 77.2090));
      await Future<void>.delayed(Duration.zero);

      final run = tracker.finish();
      expect(run, isNotNull);
      expect(run!.route.length, 2);
      expect(run.distanceKm, closeTo(1.0, 0.05));
      expect(tracker.state, TrackerState.idle);

      await positions.close();
      tracker.dispose();
    });

    test('discarding a run keeps nothing', () async {
      final positions = StreamController<Position>.broadcast();
      final tracker = RunTracker(
        positionStream: () => positions.stream,
        ensurePermission: () async => true,
      );
      await tracker.start();
      positions.add(_at(28.6139, 77.2090));
      await Future<void>.delayed(Duration.zero);

      tracker.discard();
      expect(tracker.route, isEmpty);
      expect(tracker.distanceMeters, 0);
      expect(tracker.state, TrackerState.idle);

      await positions.close();
      tracker.dispose();
    });
  });

  group('RunningTab', () {
    setUp(() {
      disableGoogleFontsNetwork();
      SharedPreferences.setMockInitialValues({});
    });

    Future<RunStore> pump(WidgetTester tester, List<RunRecord> runs) async {
      final store = RunStore();
      await store.load();
      for (final run in runs) {
        await store.add(run);
      }
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: RunningTab(store: store)),
      ));
      await tester.pump();
      return store;
    }

    testWidgets('invites a first run instead of showing sample data',
        (tester) async {
      await pump(tester, []);

      expect(find.text('No runs yet'), findsOneWidget);
      expect(find.text('Record Activity'), findsOneWidget);
      // Nothing may be presented as a personal best before anything is run.
      expect(find.text('YOUR BESTS'), findsNothing);
    });

    testWidgets('shows the figures from a recorded run', (tester) async {
      await pump(tester, [
        _run(id: 'a', at: DateTime(2026, 9, 5, 7), seconds: 1800, metres: 5000),
      ]);

      // Once on the run card and once as the personal best, since it is the
      // only run recorded.
      expect(find.text('5.00 km'), findsNWidgets(2)); // distance
      expect(find.text('30:00'), findsNWidgets(2)); // time
      expect(find.text('6:00/km'), findsOneWidget); // pace, on the card
      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('YOUR BESTS'), findsOneWidget);
    });

    testWidgets('deleting a run clears it from the feed', (tester) async {
      await pump(tester, [_run(id: 'a')]);
      expect(find.text('No runs yet'), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('No runs yet'), findsOneWidget);
    });
  });

  group('ShareCard', () {
    setUp(() => RouteMap.debugTileProvider = _OfflineTiles());
    tearDown(() => RouteMap.debugTileProvider = null);
    setUpAll(disableGoogleFontsNetwork);

    testWidgets('renders the run and rasterises to a PNG', (tester) async {
      final key = GlobalKey();
      final run = _run(
          id: 'a', at: DateTime(2026, 9, 5, 7), seconds: 1830, metres: 5120);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Center(child: ShareCard(run: run, boundaryKey: key)),
      ));
      await tester.pump();

      // The three figures the user asked to see on the shared image.
      // The figures sit in RichText so the unit can be styled separately.
      expect(find.text('5.12 km', findRichText: true), findsOneWidget);
      expect(find.text('30:30', findRichText: true), findsOneWidget);
      expect(find.text('5:57 /km', findRichText: true), findsOneWidget);

      Uint8List? bytes;
      await tester.runAsync(() async {
        bytes = await captureShareCard(key, pixelRatio: 2);
      });

      expect(bytes, isNotNull);
      // PNG magic number: the capture really produced an image file.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(bytes!.length, greaterThan(1000));

      final dump = Platform.environment['MOVARA_SHARE_PNG'];
      if (dump != null) File(dump).writeAsBytesSync(bytes!);
    });
  });
}
