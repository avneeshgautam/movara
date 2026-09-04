import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:movara_app/models/workout_entry.dart';
import 'package:movara_app/services/api_service.dart';

/// The backend rejects anonymous calls, so every request must carry the
/// Firebase ID token. These pin that down at the HTTP layer.
void main() {
  late List<http.BaseRequest> sent;

  http.Client recordingClient(String body, int status) {
    return MockClient((request) async {
      sent.add(request);
      return http.Response(body, status);
    });
  }

  setUp(() => sent = []);

  ApiService serviceWith(http.Client client, {String? token}) => ApiService(
        client: client,
        tokenProvider: token == null ? null : () async => token,
      );

  test('GET sends the bearer token', () async {
    final api = serviceWith(recordingClient('[]', 200), token: 'tok-123');
    await api.fetchWorkoutEntries();

    expect(sent.single.headers['Authorization'], 'Bearer tok-123');
  });

  test('POST sends the bearer token and JSON content type', () async {
    final body = jsonEncode({
      'id': 'e1',
      'exerciseName': 'Squats',
      'sets': 1,
      'reps': 5,
      'weightKg': 60.0,
      'performedAt': '2026-09-04',
      'notes': null,
    });
    final api = serviceWith(recordingClient(body, 201), token: 'tok-abc');

    await api.addWorkoutEntry(WorkoutEntry(
      exerciseName: 'Squats',
      sets: 1,
      reps: 5,
      performedAt: DateTime(2026, 9, 4),
    ));

    expect(sent.single.headers['Authorization'], 'Bearer tok-abc');
    expect(sent.single.headers['Content-Type'], contains('application/json'));
  });

  test('DELETE sends the bearer token', () async {
    final api = serviceWith(recordingClient('', 204), token: 'tok-del');
    await api.deleteWorkoutEntry('abc123');

    expect(sent.single.headers['Authorization'], 'Bearer tok-del');
  });

  test('exercises request sends the bearer token', () async {
    final api = serviceWith(recordingClient('[]', 200), token: 'tok-ex');
    await api.fetchExercises();

    expect(sent.single.headers['Authorization'], 'Bearer tok-ex');
  });

  test('omits the header when there is no signed-in user', () async {
    final api = serviceWith(recordingClient('[]', 200));
    await api.fetchWorkoutEntries();

    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test('surfaces a 401 as an ApiException so the UI can react', () async {
    final api = serviceWith(recordingClient('Unauthorized', 401), token: 'stale');

    expect(
      () => api.fetchWorkoutEntries(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
