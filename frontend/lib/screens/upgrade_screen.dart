import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/daily_pitch.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Movara Pro: a daily AI-written pitch, what Pro includes, and a waitlist.
///
/// Billing isn't wired yet (it needs App Store / Play Store in-app purchases),
/// so the call to action is "Notify me" and no payment is taken.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  static const _kWaitlist = 'pro_waitlist';

  late final DailyPitch _pitch = DailyPitch(widget.api);
  late String _message = _pitch.fallbackForToday();
  bool _onWaitlist = false;

  static const perks = <({String emoji, String title, String body})>[
    (
      emoji: '🤖',
      title: 'Unlimited AI coach',
      body: 'Personal plans and answers whenever you need them.'
    ),
    (
      emoji: '📈',
      title: 'Deep insights',
      body: 'Trends in volume, pace and consistency over months.'
    ),
    (
      emoji: '🏆',
      title: 'Exclusive badges & challenges',
      body: 'Pro-only goals to chase every week.'
    ),
    (
      emoji: '🎨',
      title: 'Pro themes & share cards',
      body: 'Stand out when you post your runs.'
    ),
    (
      emoji: '☁️',
      title: 'Sync everything',
      body: 'Workouts, goals and reminders on all your devices.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _onWaitlist = prefs.getBool(_kWaitlist) ?? false);
    } catch (_) {}
    final line = await _pitch.today();
    if (mounted && line != _message) setState(() => _message = line);
  }

  Future<void> _joinWaitlist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWaitlist, true);
    if (!mounted) return;
    setState(() => _onWaitlist = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You're on the list — we'll let you know when Pro launches. ⚡")));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Movara Pro',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _hero(c),
          const SizedBox(height: 24),
          Text("WHAT'S COMING IN PRO",
              style: TextStyle(
                  color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
          const SizedBox(height: 12),
          for (final p in perks) ...[
            _perk(c, p.emoji, p.title, p.body),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const ValueKey('pro-notify'),
              onPressed: _onWaitlist ? null : _joinWaitlist,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.surface2,
                disabledForegroundColor: c.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _onWaitlist
                    ? "You're on the list ✓"
                    : 'Notify me when Pro launches',
                style: AppTheme.display(
                    color: _onWaitlist ? c.textSecondary : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pro is launching soon. No payment is taken today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _hero(MovaraColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, Color.lerp(c.accent, Colors.black, 0.35)!],
        ),
        boxShadow: [
          BoxShadow(
              color: c.accentGlow, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('⚡ MOVARA PRO',
                style: AppTheme.display(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6)),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _message,
              key: ValueKey(_message),
              style: AppTheme.display(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text("Today's message · a fresh one every day ✨",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _perk(MovaraColors c, String emoji, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
