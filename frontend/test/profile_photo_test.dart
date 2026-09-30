import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/screens/account_tab.dart';
import 'package:movara_app/services/api_service.dart';
import 'package:movara_app/services/run_store.dart';
import 'package:movara_app/services/workout_log.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

void main() {
  setUpAll(disableGoogleFontsNetwork);

  group('profile photo API', () {
    test('upload PUTs the raw bytes with auth and returns the new URL',
        () async {
      late http.Request sent;
      final api = ApiService(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
              jsonEncode({'photoUrl': 'https://api/x/photo/u1?v=2'}), 200);
        }),
        tokenProvider: () async => 'tok',
      );

      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
      final url = await api.uploadProfilePhoto(bytes);

      expect(url, 'https://api/x/photo/u1?v=2');
      expect(sent.method, 'PUT');
      expect(sent.url.path, endsWith('/profile/photo'));
      expect(sent.headers['Authorization'], 'Bearer tok');
      expect(sent.bodyBytes, bytes);
    });

    test('remove treats 204 No Content as success', () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          return http.Response('', 204);
        }),
      );
      await expectLater(api.removeProfilePhoto(), completes);
    });

    test('my profile includes the photo and whether it was uploaded',
        () async {
      final api = ApiService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'displayName': 'Avi',
              'username': 'devil',
              'photoUrl': 'https://api/x/photo/u1?v=2',
              'photoCustom': true,
            }),
            200)),
      );
      final me = await api.fetchMyProfile();
      expect(me.photoUrl, 'https://api/x/photo/u1?v=2');
      expect(me.photoCustom, isTrue);
    });
  });

  testWidgets('tapping the avatar offers choose / take, not remove',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: AccountTab(
          api: ApiService(),
          entriesFuture: Future.value(const <WorkoutEntry>[]),
          runStore: RunStore(),
          workoutLog: WorkoutLog(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Choose from photos'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    // Nothing uploaded yet, so nothing to remove.
    expect(find.text('Remove photo'), findsNothing);
  });
}
