import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import 'water_notifications.dart';

/// Human label for an interval in minutes: "30 min", "1 hour", "1h 30m".
String formatInterval(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  return '${hours}h ${rest}m';
}

/// Manages a list of repeating reminders: create, edit, enable, delete, and
/// fire them.
///
/// On iOS the OS holds the schedule, so reminders arrive with the app closed.
/// On the web a timer fires due reminders and catches up on ones that came due
/// while the tab was shut — a browser cannot wake a closed tab.
class ReminderScheduler extends ChangeNotifier {
  ReminderScheduler({
    WaterNotifications notifications = const WaterNotifications(),
    bool seedDefaults = true,
  })  : _notifications = notifications,
        _seedDefaults = seedDefaults;

  /// Presets offered when picking an interval, in minutes. Any other value can
  /// still be typed.
  static const intervalOptions = [15, 30, 45, 60, 90, 120, 180];

  /// Common reminders offered as one-tap suggestions.
  static const suggestions = <({String emoji, String label, int minutes})>[
    (emoji: '💧', label: 'Drink water', minutes: 45),
    (emoji: '🧍', label: 'Stand up & stretch', minutes: 60),
    (emoji: '🚶', label: 'Walk break', minutes: 90),
    (emoji: '👀', label: 'Rest your eyes', minutes: 20),
    (emoji: '🪑', label: 'Posture check', minutes: 30),
    (emoji: '😮‍💨', label: 'Deep breaths', minutes: 120),
  ];

  static const defaultIntervalMinutes = 30;
  static const minIntervalMinutes = 1;
  static const maxIntervalMinutes = 24 * 60;

  static const _kReminders = 'reminders_v2';
  // Set once the default reminder has been offered, so deleting it is sticky.
  static const _kSeeded = 'reminders_seeded_v1';
  // Legacy single-water-reminder keys, migrated once.
  static const _kLegacyEnabled = 'water_reminder_enabled';
  static const _kLegacyIntervalMinutes = 'water_reminder_interval_minutes';
  static const _kLegacyIntervalHours = 'water_reminder_interval_hours';

  final WaterNotifications _notifications;
  final bool _seedDefaults;
  Timer? _ticker;

  List<Reminder> _reminders = [];
  int _nextNotifId = 1;
  bool _loaded = false;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  bool get isLoaded => _loaded;
  bool get hasAnyEnabled => _reminders.any((r) => r.enabled);

  bool hasReminderNamed(String label) => _reminders
      .any((r) => r.label.toLowerCase() == label.trim().toLowerCase());

  bool get isSupported => _notifications.isSupported;
  String get permission => _notifications.permission;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kReminders);
    if (raw != null) {
      _reminders = Reminder.decode(raw);
    } else {
      _reminders = _migrateLegacy(prefs);
      await _persist();
    }
    _nextNotifId = _reminders.fold<int>(0, (m, r) => r.notifId > m ? r.notifId : m) + 1;

    // One-time default: give a new (or previously empty) install a water
    // reminder to start from -- off, so nothing fires until the user opts in.
    // The flag makes it a one-shot, so deleting it later actually sticks.
    if (_seedDefaults && !(prefs.getBool(_kSeeded) ?? false)) {
      if (_reminders.isEmpty) {
        _reminders = [
          Reminder(
            id: _newId(),
            notifId: _nextNotifId++,
            label: 'Drink water',
            intervalMinutes: 45,
            enabled: false,
          ),
        ];
        await _persist();
      }
      await prefs.setBool(_kSeeded, true);
    }
    _loaded = true;

    if (hasAnyEnabled) _startTicker();
    await _reschedule(requestPermission: false);
    _fireDue();
    notifyListeners();
  }

  /// Turns the old single water reminder into the first item in the list, so
  /// nothing is lost across the upgrade. Returns an empty list on a genuinely
  /// fresh install, where none of the legacy keys were ever written.
  List<Reminder> _migrateLegacy(SharedPreferences prefs) {
    final hasLegacy = prefs.containsKey(_kLegacyEnabled) ||
        prefs.containsKey(_kLegacyIntervalMinutes) ||
        prefs.containsKey(_kLegacyIntervalHours);
    if (!hasLegacy) return [];

    final enabled = prefs.getBool(_kLegacyEnabled) ?? false;
    final minutes = prefs.getInt(_kLegacyIntervalMinutes) ??
        ((prefs.getInt(_kLegacyIntervalHours) ?? 0) * 60);
    return [
      Reminder(
        id: _newId(),
        notifId: 1,
        label: 'Drink water',
        intervalMinutes: minutes > 0 ? minutes : defaultIntervalMinutes,
        enabled: enabled,
        nextDue: enabled
            ? DateTime.now().add(Duration(
                minutes: minutes > 0 ? minutes : defaultIntervalMinutes))
            : null,
      ),
    ];
  }

  Future<void> addReminder({
    required String label,
    required int intervalMinutes,
  }) async {
    final trimmed = label.trim();
    final reminder = Reminder(
      id: _newId(),
      notifId: _nextNotifId++,
      label: trimmed.isEmpty ? 'Reminder' : trimmed,
      intervalMinutes: _clampInterval(intervalMinutes),
      enabled: true,
      nextDue: DateTime.now().add(Duration(minutes: _clampInterval(intervalMinutes))),
    );
    _reminders = [..._reminders, reminder];
    await _afterChange(requestPermission: true);
  }

  Future<void> updateReminder(
    String id, {
    String? label,
    int? intervalMinutes,
  }) async {
    _reminders = _reminders.map((r) {
      if (r.id != id) return r;
      final minutes =
          intervalMinutes == null ? r.intervalMinutes : _clampInterval(intervalMinutes);
      return r.copyWith(
        label: label?.trim().isEmpty ?? true ? r.label : label!.trim(),
        intervalMinutes: minutes,
        // Re-base so an interval change takes effect immediately.
        nextDue: r.enabled ? DateTime.now().add(Duration(minutes: minutes)) : null,
      );
    }).toList();
    await _afterChange(requestPermission: false);
  }

  Future<void> setReminderEnabled(String id, bool enabled) async {
    _reminders = _reminders.map((r) {
      if (r.id != id) return r;
      return r.copyWith(
        enabled: enabled,
        nextDue:
            enabled ? DateTime.now().add(Duration(minutes: r.intervalMinutes)) : null,
        clearNextDue: !enabled,
      );
    }).toList();
    await _afterChange(requestPermission: enabled);
  }

  Future<void> removeReminder(String id) async {
    _reminders = _reminders.where((r) => r.id != id).toList();
    await _afterChange(requestPermission: false);
  }

  /// Sends a one-off reminder now. Returns false when the platform will not
  /// deliver it, so the UI can say why instead of appearing to do nothing.
  Future<bool> sendTest() async {
    if (!_notifications.isSupported) return false;
    if (_notifications.permission != 'granted') {
      final result = await _notifications.requestPermission();
      notifyListeners();
      if (result != 'granted') return false;
    }
    await _notifications.show(
      'Test reminder 💧',
      'This is a test reminder from Movara.',
    );
    return true;
  }

  Future<void> _afterChange({required bool requestPermission}) async {
    if (hasAnyEnabled) {
      _startTicker();
    } else {
      _stopTicker();
    }
    await _persist();
    await _reschedule(requestPermission: requestPermission);
    notifyListeners();
  }

  /// Re-lays the OS notification schedule to match the current list. Called on
  /// every change; on the web this is a no-op beyond permission.
  Future<void> _reschedule({required bool requestPermission}) async {
    if (!_notifications.isSupported) return;

    final enabled = _reminders.where((r) => r.enabled).toList();
    if (requestPermission &&
        enabled.isNotEmpty &&
        _notifications.permission != 'granted') {
      await _notifications.requestPermission();
    }

    if (!_notifications.schedulesInBackground) return;

    await _notifications.cancelAll();
    if (enabled.isEmpty) return;

    // iOS caps pending notifications, so share the budget across reminders.
    const budget = WaterNotifications.maxSeries;
    final per = (budget ~/ enabled.length).clamp(1, budget);
    for (final r in enabled) {
      await _notifications.scheduleReminder(
        baseId: r.notifId,
        title: r.label,
        body: 'Reminder from Movara — ${r.label}.',
        everyMinutes: r.intervalMinutes,
        count: per,
      );
    }
  }

  /// Fires any web reminders whose time has passed and re-bases them. On iOS
  /// the OS has already delivered them, so this only advances the countdown.
  void _fireDue() {
    var changed = false;
    _reminders = _reminders.map((r) {
      if (!r.enabled || r.nextDue == null) return r;
      if (DateTime.now().isBefore(r.nextDue!)) return r;

      if (!_notifications.schedulesInBackground) {
        _notifications.show(r.label, 'Reminder from Movara — ${r.label}.');
      }
      changed = true;
      return r.copyWith(
        nextDue: DateTime.now().add(Duration(minutes: r.intervalMinutes)),
      );
    }).toList();

    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    // Short poll, so a throttled background tab still catches up and the UI
    // countdown stays fresh.
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _fireDue());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReminders, Reminder.encode(_reminders));
  }

  int _clampInterval(int minutes) =>
      minutes.clamp(minIntervalMinutes, maxIntervalMinutes).toInt();

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_reminders.length}';

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
