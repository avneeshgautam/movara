import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/api_service.dart';
import 'package:movara_app/services/inbox.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns new messages once, then asks only for newer ones', () async {
    final sinceParams = <String?>[];
    var serverMessages = [
      {'id': 'a', 'title': 'Welcome', 'body': 'Hi', 'createdAt': '2026-09-30T10:00:00'},
      {'id': 'b', 'title': 'Streak!', 'body': 'Nice', 'createdAt': '2026-09-30T11:00:00'},
    ];
    final api = ApiService(client: MockClient((r) async {
      sinceParams.add(r.url.queryParameters['since']);
      final since = r.url.queryParameters['since'];
      final fresh = since == null
          ? serverMessages
          : serverMessages
              .where((m) => DateTime.parse('${m['createdAt']}Z')
                  .isAfter(DateTime.parse(since)))
              .toList();
      return http.Response(jsonEncode(fresh), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final inbox = Inbox(api);

    final first = await inbox.fetchNew();
    expect(first.map((m) => m.title), ['Welcome', 'Streak!']);
    expect(sinceParams.first, isNull);

    // Nothing new: the second check passes the newest seen time and gets [].
    expect(await inbox.fetchNew(), isEmpty);
    expect(sinceParams.last, '2026-09-30T11:00:00.000Z');

    serverMessages = [
      ...serverMessages,
      {'id': 'c', 'title': 'New feature', 'body': '✨', 'createdAt': '2026-09-30T12:00:00'},
    ];
    final third = await inbox.fetchNew();
    expect(third.map((m) => m.title), ['New feature']);
  });

  test('server timestamps without a zone are read as UTC', () async {
    final api = ApiService(
      client: MockClient((_) async => http.Response(
          jsonEncode([
            {'id': 'a', 'title': 't', 'body': 'b', 'createdAt': '2026-09-30T10:00:00'}
          ]),
          200)),
    );
    final m = (await api.fetchNotifications()).single;
    expect(m.sentAt.isUtc, isTrue);
    expect(m.sentAt, DateTime.utc(2026, 9, 30, 10));
  });
}
