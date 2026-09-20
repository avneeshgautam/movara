import 'dart:math';

import '../models/chat_message.dart';
import 'api_service.dart';
import 'water_notifications.dart';

/// Daily motivation notifications: a morning wake-up (6am) and a gym nudge
/// (5pm). The message is written by the app's AI assistant when it can be
/// reached, and falls back to a curated pool otherwise.
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

  /// Schedules both daily notifications (call after permission is granted).
  Future<void> enable() async {
    final wake = await _line(morning: true, pool: _wakeMessages);
    final gym = await _line(morning: false, pool: _gymMessages);
    await _notif.scheduleDailyAt(
      id: _wakeId,
      hour: 6,
      minute: 0,
      title: 'Movara · Wake up 🌅',
      body: wake,
    );
    await _notif.scheduleDailyAt(
      id: _gymId,
      hour: 17,
      minute: 0,
      title: 'Movara · Gym time 🏋️',
      body: gym,
    );
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
          : 'Write ONE short punchy 5pm "time to hit the gym" motivation line '
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
