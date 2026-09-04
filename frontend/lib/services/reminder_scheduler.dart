import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'water_notifications.dart';

/// Human label for an interval in minutes: "30 min", "1 hour", "1h 30m".
String formatInterval(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  return '${hours}h ${rest}m';
}

/// Drives the water reminder: stores whether it is on, how often it repeats,
/// and when it is next due, then fires a browser notification when that time
/// passes.
///
/// The due time is persisted, so reopening the app after being away still
/// surfaces a reminder that came due while it was closed. A browser cannot
/// wake a closed tab on its own, so this is catch-up rather than true push.
class ReminderScheduler extends ChangeNotifier {
  ReminderScheduler({WaterNotifications notifications = const WaterNotifications()})
      : _notifications = notifications;

  /// Presets offered in the dropdown, in minutes. Any other value can still be
  /// set by typing a custom one.
  static const intervalOptions = [15, 30, 45, 60, 90, 120, 180];

  static const defaultIntervalMinutes = 30;
  static const minIntervalMinutes = 1;
  static const maxIntervalMinutes = 24 * 60;

  static const _kEnabled = 'water_reminder_enabled';
  static const _kIntervalMinutes = 'water_reminder_interval_minutes';
  static const _kLegacyIntervalHours = 'water_reminder_interval_hours';
  static const _kNextDue = 'water_reminder_next_due_ms';

  final WaterNotifications _notifications;
  Timer? _ticker;

  bool _enabled = false;
  int _intervalMinutes = defaultIntervalMinutes;
  DateTime? _nextDue;
  bool _loaded = false;

  bool get enabled => _enabled;
  int get intervalMinutes => _intervalMinutes;
  String get intervalLabel => formatInterval(_intervalMinutes);
  DateTime? get nextDue => _nextDue;
  bool get isLoaded => _loaded;

  bool get isSupported => _notifications.isSupported;
  String get permission => _notifications.permission;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;

    // Older builds stored whole hours; carry that value over once.
    final minutes = prefs.getInt(_kIntervalMinutes);
    final legacyHours = prefs.getInt(_kLegacyIntervalHours);
    _intervalMinutes = minutes ??
        (legacyHours != null ? legacyHours * 60 : defaultIntervalMinutes);

    final due = prefs.getInt(_kNextDue);
    _nextDue = due == null ? null : DateTime.fromMillisecondsSinceEpoch(due);
    _loaded = true;

    if (_enabled) _startTicker();
    _fireIfDue();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (value) {
      if (_notifications.permission != 'granted') {
        await _notifications.requestPermission();
      }
      _nextDue = DateTime.now().add(Duration(minutes: _intervalMinutes));
      _startTicker();
    } else {
      _nextDue = null;
      _stopTicker();
    }
    await _persist();
    notifyListeners();
  }

  /// Sets a new interval in minutes; values outside the supported range are
  /// clamped rather than rejected.
  Future<void> setIntervalMinutes(int minutes) async {
    _intervalMinutes =
        minutes.clamp(minIntervalMinutes, maxIntervalMinutes).toInt();
    // Re-base the countdown so a change takes effect immediately.
    if (_enabled) {
      _nextDue = DateTime.now().add(Duration(minutes: _intervalMinutes));
    }
    await _persist();
    notifyListeners();
  }

  void sendTest() {
    _notifications.show(
      'Time to drink water 💧',
      'This is a test reminder from Movara.',
    );
  }

  /// Fires and re-schedules if the due time has passed.
  void _fireIfDue() {
    if (!_enabled) return;
    final due = _nextDue;
    if (due == null || DateTime.now().isBefore(due)) return;

    _notifications.show(
      'Time to drink water 💧',
      'Stay hydrated — next reminder in $intervalLabel.',
    );
    _nextDue = DateTime.now().add(Duration(minutes: _intervalMinutes));
    _persist();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Short poll rather than one long timer: browsers throttle long timers in
    // background tabs, and this also refreshes the countdown in the UI.
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _fireIfDue());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, _enabled);
    await prefs.setInt(_kIntervalMinutes, _intervalMinutes);
    final due = _nextDue;
    if (due == null) {
      await prefs.remove(_kNextDue);
    } else {
      await prefs.setInt(_kNextDue, due.millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
