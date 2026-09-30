import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import 'api_service.dart';

/// The Movara Pro "message of the day": written by the AI assistant once per
/// day and cached for the rest of it, so the upgrade screen reads fresh every
/// day without an AI call on every open. Falls back to a curated line that
/// also rotates daily when the assistant can't be reached.
class DailyPitch {
  DailyPitch(this._api, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ApiService _api;
  final DateTime Function() _clock;

  static const _kDay = 'pro_pitch_day';
  static const _kText = 'pro_pitch_text';

  /// Each day's AI line is steered to a different angle so consecutive days
  /// don't read alike.
  static const _themes = [
    'consistency beating motivation',
    'breaking a personal record',
    'the first kilometre being the hardest',
    'recovery and rest days being part of training',
    'small daily wins compounding',
    'showing up even on low-energy days',
    'future you thanking present you',
  ];

  static const fallbacks = [
    "Champions aren't made on the good days. Go Pro and own every day. ⚡",
    'Your next PR is closer than you think. Pro helps you find it.',
    'Discipline is a skill. Pro is your training partner for it. 💪',
    'Every rep tells a story. Pro reads it back to you.',
    'Stronger than yesterday isn’t luck — it’s a plan. Go Pro.',
    'The only bad workout is the one you skipped. Pro keeps you showing up.',
    'Built different starts today. Unlock Movara Pro. 🔥',
  ];

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _dayIndex(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(DateTime(2026)).inDays;

  /// Today's curated line — instant, no network. Shown while the AI loads.
  String fallbackForToday() {
    final i = _dayIndex(_clock()) % fallbacks.length;
    return fallbacks[i < 0 ? i + fallbacks.length : i];
  }

  /// Today's message: cached if already fetched today, else a new AI line.
  Future<String> today() async {
    final now = _clock();
    final key = _dayKey(now);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kDay) == key) {
      final cached = prefs.getString(_kText);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    try {
      final theme = _themes[_dayIndex(now) % _themes.length];
      final reply = await _api.sendChat([
        ChatMessage(
          role: 'user',
          content: 'Write ONE bold, punchy line (max 110 characters) inviting '
              'a fitness app user to upgrade to Movara Pro, themed around '
              '$theme. At most one emoji. No quotes, no hashtags.',
        ),
      ]);
      final cleaned = reply.trim().replaceAll('"', '');
      if (cleaned.isNotEmpty && cleaned.length <= 160) {
        // Only an AI line is cached, so a cold backend gets retried on the
        // next open instead of pinning the fallback for the whole day.
        await prefs.setString(_kDay, key);
        await prefs.setString(_kText, cleaned);
        return cleaned;
      }
    } catch (_) {
      // Assistant unavailable: use today's curated line.
    }
    return fallbackForToday();
  }
}
