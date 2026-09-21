import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished gym workout: the day it happened and how long it lasted.
///
/// Recorded when the user taps "Finish Workout". Distinct from a logged set
/// (that tracks lifts) and from a run (that tracks distance) — this simply
/// answers "did I train today, and for how long".
@immutable
class WorkoutSessionRecord {
  const WorkoutSessionRecord({
    required this.id,
    required this.startedAt,
    required this.seconds,
  });

  final String id;
  final DateTime startedAt;
  final int seconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'seconds': seconds,
      };

  static WorkoutSessionRecord fromJson(Map<String, dynamic> j) =>
      WorkoutSessionRecord(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        seconds: (j['seconds'] as num).toInt(),
      );
}

/// Finished workouts, kept on the device. Powers the daily workout count, the
/// "longest workout" record, and the workout-day streak used for badges.
class WorkoutLog extends ChangeNotifier {
  static const _key = 'workout_sessions';

  List<WorkoutSessionRecord> _sessions = [];
  bool _loaded = false;

  /// Newest first.
  List<WorkoutSessionRecord> get sessions => List.unmodifiable(_sessions);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => WorkoutSessionRecord.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        _sessions = list;
      } catch (_) {
        _sessions = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Records a finished workout. Very short taps (< 20s) are ignored so an
  /// accidental start/finish doesn't inflate the count.
  Future<void> add({required Duration duration, DateTime? startedAt}) async {
    if (duration.inSeconds < 20) return;
    final record = WorkoutSessionRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: startedAt ?? DateTime.now(),
      seconds: duration.inSeconds,
    );
    _sessions = [record, ..._sessions];
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _sessions = _sessions.where((s) => s.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  // ── Derived figures ───────────────────────────────────────────────

  int get totalCount => _sessions.length;

  /// Workouts finished today.
  int countToday({DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    return _sessions.where((s) => _startOfDay(s.startedAt) == today).length;
  }

  int countThisWeek({DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return _sessions.where((s) {
      final offset = _startOfDay(s.startedAt).difference(monday).inDays;
      return offset >= 0 && offset < 7;
    }).length;
  }

  /// The longest single workout, in seconds (0 if none).
  int get longestSeconds =>
      _sessions.fold<int>(0, (m, s) => s.seconds > m ? s.seconds : m);

  /// Total time trained today.
  Duration timeToday({DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final total = _sessions
        .where((s) => _startOfDay(s.startedAt) == today)
        .fold<int>(0, (a, s) => a + s.seconds);
    return Duration(seconds: total);
  }

  /// Distinct days with at least one finished workout, counting back from
  /// today (or yesterday, so a rest morning doesn't break it immediately).
  int get streakDays {
    if (_sessions.isEmpty) return 0;
    final days = _sessions.map((s) => _startOfDay(s.startedAt)).toSet();
    final today = _startOfDay(DateTime.now());
    var cursor = today;
    if (!days.contains(cursor)) {
      cursor = today.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// "1h 05m" / "42m" / "18s" — compact workout duration for chips and badges.
String formatWorkoutDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}
