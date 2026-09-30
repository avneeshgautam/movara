import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/screens/account_tab.dart';
import 'package:movara_app/screens/upgrade_screen.dart';
import 'package:movara_app/services/api_service.dart';
import 'package:movara_app/services/daily_pitch.dart';
import 'package:movara_app/services/run_store.dart';
import 'package:movara_app/services/workout_log.dart';
import 'package:movara_app/theme/app_theme.dart';
import 'package:movara_app/widgets/movara_header.dart';

import 'test_setup.dart';

/// A fake backend for the profile endpoints, recording profile writes.
class _FakeProfileServer {
  _FakeProfileServer({this.taken = const {}});

  final Set<String> taken;
  String? username = 'ironheart';
  String? status;
  final writes = <Map<String, dynamic>>[];

  http.Client get client => MockClient((r) async {
        if (r.url.path.endsWith('/profile/me')) {
          return http.Response(
              jsonEncode({
                'displayName': 'Avi',
                'username': username,
                'status': status,
                'photoUrl': null,
                'photoCustom': false,
              }),
              200);
        }
        if (r.url.path.endsWith('/profile/username-available')) {
          final u = r.url.queryParameters['u']!.toLowerCase();
          return http.Response(jsonEncode({'available': !taken.contains(u)}), 200);
        }
        if (r.url.path.endsWith('/profile') && r.method == 'PUT') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          writes.add(body);
          if (body['username'] != null) username = body['username'] as String;
          if (body['status'] != null) status = body['status'] as String;
          return http.Response('', 204);
        }
        return http.Response('[]', 200);
      });
}

void main() {
  setUpAll(disableGoogleFontsNetwork);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget account(ApiService api, {ValueChanged<String>? onNameChanged}) =>
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AccountTab(
            api: api,
            displayName: 'Avi Google',
            entriesFuture: Future.value(const <WorkoutEntry>[]),
            runStore: RunStore(),
            workoutLog: WorkoutLog(),
            onNameChanged: onNameChanged,
          ),
        ),
      );

  group('Edit profile', () {
    testWidgets('shows one name, saves name + status, updates the hero',
        (tester) async {
      final server = _FakeProfileServer();
      String? renamed;
      await tester.pumpWidget(account(ApiService(client: server.client),
          onNameChanged: (n) => renamed = n));
      await tester.pumpAndSettle();

      // One name: the public name, no "@" handle line.
      expect(find.text('ironheart'), findsOneWidget);
      expect(find.text('@ironheart'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('edit-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('profile-name')), 'devil');
      await tester.enterText(
          find.byKey(const ValueKey('profile-status')), 'Training for a 10K');
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pumpAndSettle();

      final write = server.writes.last;
      expect(write['username'], 'devil');
      expect(write['status'], 'Training for a 10K');
      // The server's display name stays the sign-in name.
      expect(write['displayName'], 'Avi Google');

      expect(find.text('devil'), findsOneWidget);
      expect(find.text('Training for a 10K'), findsOneWidget);
      expect(renamed, 'devil');
    });

    testWidgets('a taken name is rejected before saving', (tester) async {
      final server = _FakeProfileServer(taken: {'devil'});
      await tester.pumpWidget(account(ApiService(client: server.client)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('profile-name')), 'devil');
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pumpAndSettle();

      expect(find.textContaining('taken'), findsOneWidget);
      expect(server.writes, isEmpty);
    });
  });

  group('Daily Pro message', () {
    ApiService chatApi(List<int> calls, {bool fail = false}) =>
        ApiService(client: MockClient((r) async {
          calls.add(1);
          if (fail) return http.Response('down', 503);
          // UTF-8 like the real server; the default charset can't hold ⚡.
          return http.Response(
              jsonEncode({'reply': '"Go Pro, go further ⚡"'}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));

    test('fetches once per day, then serves the cached line', () async {
      final calls = <int>[];
      var now = DateTime(2026, 9, 30, 9);
      final pitch = DailyPitch(chatApi(calls), clock: () => now);

      expect(await pitch.today(), 'Go Pro, go further ⚡');
      expect(await pitch.today(), 'Go Pro, go further ⚡');
      expect(calls, hasLength(1));

      now = DateTime(2026, 10, 1, 9); // next day → a fresh line
      await pitch.today();
      expect(calls, hasLength(2));
    });

    test('falls back to a curated line that changes by day, uncached',
        () async {
      final calls = <int>[];
      var now = DateTime(2026, 9, 30);
      final pitch = DailyPitch(chatApi(calls, fail: true), clock: () => now);

      final a = await pitch.today();
      expect(DailyPitch.fallbacks, contains(a));
      now = DateTime(2026, 10, 1);
      final b = await pitch.today();
      expect(b, isNot(a));
      // Not cached on failure, so the next open retries the AI.
      await pitch.today();
      expect(calls.length, 3);
    });
  });

  testWidgets('upgrade screen shows the pitch and joins the waitlist',
      (tester) async {
    final api = ApiService(
        client: MockClient((_) async =>
            http.Response(jsonEncode({'reply': 'Unlock your best year.'}), 200)));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: UpgradeScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Unlock your best year.'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pro-notify')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('pro-notify')));
    await tester.pumpAndSettle();
    expect(find.text("You're on the list ✓"), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pro_waitlist'), isTrue);
  });

  testWidgets('PRO pill fits the header on a phone and opens upgrade',
      (tester) async {
    tester.view.physicalSize = const Size(375, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MovaraHeader(
          username: 'devil',
          isDark: false,
          onToggleTheme: () {},
          action: const SizedBox(width: 40, height: 36),
          onUpgrade: () => opened = true,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('pro-pill')));
    expect(opened, isTrue);
  });
}
