import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exercise.dart';
import '../models/workout_entry.dart';
import 'api_config.dart';

/// Thin wrapper around the Movara backend REST API.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  Future<List<Exercise>> fetchExercises() async {
    final response = await _client.get(_uri('/exercises'));
    _checkOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WorkoutEntry>> fetchWorkoutEntries() async {
    final response = await _client.get(_uri('/workout-entries'));
    _checkOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => WorkoutEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkoutEntry> addWorkoutEntry(WorkoutEntry entry) async {
    final response = await _client.post(
      _uri('/workout-entries'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(entry.toJson()),
    );
    _checkOk(response, expected: 201);
    return WorkoutEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteWorkoutEntry(String id) async {
    final response = await _client.delete(_uri('/workout-entries/$id'));
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
