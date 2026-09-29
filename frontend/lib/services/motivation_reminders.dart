import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import 'api_service.dart';
import 'water_notifications.dart';

/// Daily motivation notifications: a morning wake-up and an evening gym nudge,
/// at times the user picks (default 6:00 AM and 5:00 PM). The message is
/// written by the app's AI assistant when it can be reached, and falls back to
/// a curated pool otherwise.
class MotivationReminders {
  const MotivationReminders(this._api);

  final ApiService _api;

  static const _notif = WaterNotifications();

  // Fixed ids so they can be cancelled without touching water reminders.
  static const _wakeId = 910001;
  static const _gymId = 910002;

  bool get isSupported => _notif.isSupported;

  Future<String> requestPermission() => _notif.requestPermission();

  static const _wakeMessages = [
    "Rise and grind 💪 Every rep today builds the best version of you.",
    "Good morning, champion — your goals won't chase themselves. Let's move.",
    "New day, new gains. Get up, hydrate, and own it. 🔥",
    "Winners wake up with purpose. That's you. Let's go. 🌅",
    "Small steps today, big results tomorrow. Up and at it! 🚀",
  ];

  static const _gymMessages = [
    "It's gym o'clock 🏋️ 45 minutes for yourself changes everything.",
    "Time to train. Beat yesterday, not someone else. 💯",
    "Your future self is watching — make them proud. Hit the gym. 🔥",
    "No excuses, just reps. Let's get after it. 💪",
    "Consistency beats intensity. Show up today — you've got this.",
  ];

  static const defaultMorningMinute = 6 * 60;
  static const defaultEveningMinute = 17 * 60;
  static const _kMorning = 'gym_motivation_morning_min';
  static const _kEvening = 'gym_motivation_evening_min';

  /// The user's chosen times, as minutes after midnight.
  static Future<({int morning, int evening})> times() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      morning: prefs.getInt(_kMorning) ?? defaultMorningMinute,
      evening: prefs.getInt(_kEvening) ?? defaultEveningMinute,
    );
  }

  static Future<void> saveTimes({required int morning, required int evening}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMorning, morning);
    await prefs.setInt(_kEvening, evening);
  }

  /// Schedules both daily notifications at the saved times (call after
  /// permission is granted). Re-calling replaces the previous schedule.
  Future<void> enable() async {
    final t = await times();
    final wake = await _line(morning: true, pool: _wakeMessages);
    final gym = await _line(morning: false, pool: _gymMessages);
    await _notif.scheduleDailyAt(
      id: _wakeId,
      hour: t.morning ~/ 60,
      minute: t.morning % 60,
      title: 'Movara · Wake up 🌅',
      body: wake,
    );
    await _notif.scheduleDailyAt(
      id: _gymId,
      hour: t.evening ~/ 60,
      minute: t.evening % 60,
      title: 'Movara · Gym time 🏋️',
      body: gym,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVersion, _scheduleVersion);
  }

  /// Bumped when the scheduling logic changes so existing installs get their
  /// daily notifications rebuilt. v2: scheduled in the phone's own timezone
  /// (v1 used UTC, so 6am/5pm arrived at 11:30am/10:30pm in India).
  static const _scheduleVersion = 2;
  static const _kToggle = 'toggle_Gym Motivation';
  static const _kVersion = 'gym_motivation_schedule_v';

  /// Called at launch. If the user has Gym Motivation on but the OS no longer
  /// holds the notifications (an older build wiped them on every launch), or
  /// they were scheduled by an older version, schedule them again. Does
  /// nothing -- and makes no AI call -- when they are already in place.
  Future<void> ensureScheduled() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kToggle) != true) return;
    final current = prefs.getInt(_kVersion) == _scheduleVersion &&
        await _notif.isScheduled(_wakeId) &&
        await _notif.isScheduled(_gymId);
    if (current) return;
    await enable();
  }

  Future<void> disable() async {
    await _notif.cancel(_wakeId);
    await _notif.cancel(_gymId);
  }

  /// One line from the AI assistant, or a curated fallback.
  Future<String> _line({required bool morning, required List<String> pool}) async {
    try {
      final prompt = morning
          ? 'Write ONE short punchy morning wake-up motivation line for a gym '
              "app notification. Max 90 characters, at most one emoji, no quotes."
          : 'Write ONE short punchy "time to hit the gym" motivation line '
              'for a notification. Max 90 characters, at most one emoji, no quotes.';
      final reply =
          await _api.sendChat([ChatMessage(role: 'user', content: prompt)]);
      final line = reply.trim().replaceAll('"', '');
      if (line.isNotEmpty && line.length <= 140) return line;
    } catch (_) {
      // Assistant unavailable — use the curated pool below.
    }
    return pool[Random().nextInt(pool.length)];
  }
}
