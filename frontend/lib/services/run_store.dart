import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_record.dart';

/// Saved runs, kept on the device and mirrored to the backend.
///
/// Local storage is the source of truth for the UI; each run is also uploaded
/// (best-effort, idempotent) via [uploader] so it can score on the
/// leaderboard. Uploads that fail are retried on the next load.
class RunStore extends ChangeNotifier {
  RunStore({Future<void> Function(RunRecord)? uploader}) : _uploader = uploader;

  static const _key = 'saved_runs';

  final Future<void> Function(RunRecord)? _uploader;

  List<RunRecord> _runs = [];
  bool _loaded = false;

  /// Newest first.
  List<RunRecord> get runs => List.unmodifiable(_runs);
  bool get isLoaded => _loaded;
  bool get isEmpty => _runs.isEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _runs = RunRecord.decodeList(raw)
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      } catch (_) {
        // Corrupt or older-format data: start clean rather than crash.
        _runs = [];
      }
    }
    _loaded = true;
    notifyListeners();

    // Backfill anything recorded before the backend had run sync, and retry
    // uploads that failed earlier. Cheap: the server upserts by id.
    _syncAll();
  }

  Future<void> add(RunRecord run) async {
    _runs = [run, ..._runs];
    await _persist();
    notifyListeners();
    await _uploader?.call(run);
  }

  void _syncAll() {
    final upload = _uploader;
    if (upload == null) return;
    for (final run in _runs) {
      upload(run);
    }
  }

  Future<void> remove(String id) async {
    _runs = _runs.where((r) => r.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, RunRecord.encodeList(_runs));
  }

  // ── Derived figures, all from real recorded runs ──────────────────

  /// Distance per weekday for the current week, Monday first.
  List<double> kmByWeekday({DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final totals = List<double>.filled(7, 0);

    for (final run in _runs) {
      final day = _startOfDay(run.startedAt);
      final offset = day.difference(monday).inDays;
      if (offset >= 0 && offset < 7) totals[offset] += run.distanceKm;
    }
    return totals;
  }

  double totalKmThisWeek({DateTime? now}) =>
      kmByWeekday(now: now).fold(0, (a, b) => a + b);

  Iterable<RunRecord> _thisWeek({DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return _runs.where((r) {
      final offset = _startOfDay(r.startedAt).difference(monday).inDays;
      return offset >= 0 && offset < 7;
    });
  }

  int runsThisWeek({DateTime? now}) => _thisWeek(now: now).length;

  /// Minutes spent running so far this week.
  int activeMinutesThisWeek({DateTime? now}) => _thisWeek(now: now)
      .fold<int>(0, (a, r) => a + r.elapsedSeconds) ~/
      60;

  /// Furthest single run.
  RunRecord? get longestRun {
    if (_runs.isEmpty) return null;
    return _runs.reduce((a, b) => b.distanceMeters > a.distanceMeters ? b : a);
  }

  /// Best (lowest) pace, ignoring very short runs where GPS noise dominates.
  RunRecord? get fastestPace {
    final eligible =
        _runs.where((r) => r.distanceKm >= 0.5 && r.paceSecondsPerKm > 0);
    if (eligible.isEmpty) return null;
    return eligible
        .reduce((a, b) => b.paceSecondsPerKm < a.paceSecondsPerKm ? b : a);
  }

  /// Longest time spent running in one go.
  RunRecord? get longestDuration {
    if (_runs.isEmpty) return null;
    return _runs.reduce((a, b) => b.elapsedSeconds > a.elapsedSeconds ? b : a);
  }

  double get totalKmAllTime =>
      _runs.fold<double>(0, (sum, r) => sum + r.distanceKm);

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
