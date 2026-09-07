import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Feed tab, first slice: a global leaderboard ranked by sets logged this
/// week. Friends and stories come later.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key, required this.api});

  final ApiService api;

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchLeaderboard();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.fetchLeaderboard());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      color: c.bg,
      child: RefreshIndicator(
        onRefresh: _reload,
        color: c.accent,
        backgroundColor: c.surface,
        child: FutureBuilder<List<LeaderboardEntry>>(
          future: _future,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text('THIS WEEK',
                    style: TextStyle(
                        color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
                const SizedBox(height: 2),
                Text('Leaderboard',
                    style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Points = 10 per set + 20 per km, this week.',
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  _loading(context)
                else if (snapshot.hasError)
                  _error(context)
                else if ((snapshot.data ?? []).isEmpty)
                  _empty(context)
                else
                  for (final e in snapshot.data!) ...[
                    _row(context, e),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, LeaderboardEntry e) {
    final c = context.movara;
    final medal = switch (e.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: e.isMe ? c.accentSoft : c.surface,
        border: Border.all(color: e.isMe ? c.accent : c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 20))
                : Text('${e.rank}',
                    textAlign: TextAlign.center,
                    style: AppTheme.display(
                        color: c.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle),
            child: e.photoUrl != null && e.photoUrl!.isNotEmpty
                ? Image.network(e.photoUrl!,
                    fit: BoxFit.cover,
                    width: 38,
                    height: 38,
                    errorBuilder: (_, __, ___) => _initial(context, e))
                : _initial(context, e),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.isMe ? '${e.displayName} (you)' : e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.setsThisWeek} sets · ${e.kmThisWeek.toStringAsFixed(1)} km',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              text: '${e.points}',
              style: AppTheme.display(
                  color: c.accent, fontSize: 18, fontWeight: FontWeight.w800),
              children: [
                TextSpan(
                  text: ' pts',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(BuildContext context, LeaderboardEntry e) {
    final c = context.movara;
    final ch = e.displayName.isEmpty ? '?' : e.displayName[0].toUpperCase();
    return Text(ch,
        style: AppTheme.display(
            color: c.accent, fontSize: 15, fontWeight: FontWeight.w700));
  }

  Widget _loading(BuildContext context) {
    final c = context.movara;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(child: CircularProgressIndicator(color: c.accent)),
    );
  }

  Widget _error(BuildContext context) {
    return _card(
      context,
      icon: Icons.cloud_off,
      title: "Couldn't load the leaderboard",
      body: 'Pull down to retry.',
    );
  }

  Widget _empty(BuildContext context) {
    return _card(
      context,
      icon: Icons.emoji_events_outlined,
      title: 'No one here yet',
      body: 'Log some sets on the Workout tab and you\'ll show up here.',
    );
  }

  Widget _card(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: c.textMuted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
          const SizedBox(height: 4),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
