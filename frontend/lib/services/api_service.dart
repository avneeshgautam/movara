import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/exercise.dart';
import '../models/leaderboard_entry.dart';
import '../models/run_record.dart';
import '../models/workout_entry.dart';
import 'api_config.dart';

/// Thin wrapper around the Movara backend REST API.
///
/// Every request carries the signed-in user's Firebase ID token; the backend
/// scopes all workout data to that user and rejects anonymous calls.
class ApiService {
  ApiService({http.Client? client, Future<String?> Function()? tokenProvider})
      : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final Future<String?> Function()? _tokenProvider;

  Future<Map<String, String>> _headers({bool json = false}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';

    final token = await _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  /// Sends the conversation to the assistant and returns its reply.
  ///
  /// Throws [ChatUnavailable] when the server has no model configured (503),
  /// so the UI can explain that rather than showing a generic error.
  Future<String> sendChat(List<ChatMessage> messages) async {
    final response = await _client.post(
      _uri('/chat'),
      headers: await _headers(json: true),
      body: jsonEncode({'messages': messages.map((m) => m.toJson()).toList()}),
    );
    if (response.statusCode == 503) {
      throw const ChatUnavailable();
    }
    _checkOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['reply'] as String?)?.trim() ?? '';
  }

  /// Streams the assistant's reply as text chunks, so the UI can show it as
  /// it's written. Throws [ChatUnavailable] on 503.
  Stream<String> sendChatStream(List<ChatMessage> messages) async* {
    final request = http.Request('POST', _uri('/chat/stream'));
    request.headers.addAll(await _headers(json: true));
    request.body =
        jsonEncode({'messages': messages.map((m) => m.toJson()).toList()});

    final response = await _client.send(request);
    if (response.statusCode == 503) {
      throw const ChatUnavailable();
    }
    if (response.statusCode != 200) {
      throw Exception('chat failed: ${response.statusCode}');
    }
    yield* response.stream.transform(utf8.decoder);
  }

  /// Registers (or updates) the signed-in user's name and photo so they can
  /// appear on the leaderboard. Best-effort: failures are swallowed.
  Future<void> upsertProfile(String displayName, {String? photoUrl}) async {
    try {
      await _client.put(
        _uri('/profile'),
        headers: await _headers(json: true),
        body: jsonEncode({'displayName': displayName, 'photoUrl': photoUrl}),
      );
    } catch (_) {
      // Not fatal -- the board just won't show this user until it succeeds.
    }
  }

  /// Syncs one recorded run to the backend so it scores on the leaderboard.
  /// Best-effort and idempotent (the server upserts by id).
  Future<void> uploadRun(RunRecord run) async {
    try {
      await _client.post(
        _uri('/runs'),
        headers: await _headers(json: true),
        body: jsonEncode({
          'id': run.id,
          'startedAt': run.startedAt.toUtc().toIso8601String(),
          'elapsedSeconds': run.elapsedSeconds,
          'distanceMeters': run.distanceMeters,
        }),
      );
    } catch (_) {
      // Not fatal -- the run stays local and syncs on a later attempt.
    }
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final response =
        await _client.get(_uri('/leaderboard'), headers: await _headers());
    _checkOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Exercise>> fetchExercises() async {
    final response = await _client.get(_uri('/exercises'), headers: await _headers());
    _checkOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WorkoutEntry>> fetchWorkoutEntries() async {
    final response =
        await _client.get(_uri('/workout-entries'), headers: await _headers());
    _checkOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => WorkoutEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkoutEntry> addWorkoutEntry(WorkoutEntry entry) async {
    final response = await _client.post(
      _uri('/workout-entries'),
      headers: await _headers(json: true),
      body: jsonEncode(entry.toJson()),
    );
    _checkOk(response, expected: 201);
    return WorkoutEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteWorkoutEntry(String id) async {
    final response = await _client.delete(
      _uri('/workout-entries/$id'),
      headers: await _headers(),
    );
    _checkOk(response, expected: 204);
  }

  void _checkOk(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Thrown when the assistant backend has no API key configured.
class ChatUnavailable implements Exception {
  const ChatUnavailable();
}
