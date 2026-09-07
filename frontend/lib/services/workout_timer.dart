import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stopwatch for the whole workout session, shown above the exercises.
///
/// Elapsed time is derived from the wall clock (not a counted ticker), so it
/// stays accurate even if the app is backgrounded or the screen locks. It is
/// persisted and scoped to the day: reopening the app continues the same
/// session's time, and it resets on a new day.
class WorkoutTimer extends ChangeNotifier {
  static const _kDay = 'workout_timer_day';
  static const _kBankedMs = 'workout_timer_banked_ms';
  static const _kRunningSinceMs = 'workout_timer_running_since_ms';

  Timer? _ticker;
  Duration _banked = Duration.zero;
  DateTime? _runningSince;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isRunning => _runningSince != null;

  Duration get elapsed {
    final since = _runningSince;
    if (since == null) return _banked;
    return _banked + DateTime.now().difference(since);
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kDay) != _today()) {
      // New day: start fresh.
      _banked = Duration.zero;
      _runningSince = null;
      await _persist();
    } else {
      _banked = Duration(milliseconds: prefs.getInt(_kBankedMs) ?? 0);
      final sinceMs = prefs.getInt(_kRunningSinceMs);
      _runningSince =
          sinceMs == null ? null : DateTime.fromMillisecondsSinceEpoch(sinceMs);
    }
    _loaded = true;
    if (isRunning) _startTicker();
    notifyListeners();
  }

  Future<void> start() async {
    if (isRunning) return;
    _runningSince = DateTime.now();
    _startTicker();
    await _persist();
    notifyListeners();
  }

  Future<void> pause() async {
    final since = _runningSince;
    if (since == null) return;
    _banked += DateTime.now().difference(since);
    _runningSince = null;
    _stopTicker();
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    _banked = Duration.zero;
    _runningSince = null;
    _stopTicker();
    await _persist();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Display refresh only; elapsed is wall-clock, so dropped ticks are
    // cosmetic.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDay, _today());
    await prefs.setInt(_kBankedMs, _banked.inMilliseconds);
    final since = _runningSince;
    if (since == null) {
      await prefs.remove(_kRunningSinceMs);
    } else {
      await prefs.setInt(_kRunningSinceMs, since.millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
