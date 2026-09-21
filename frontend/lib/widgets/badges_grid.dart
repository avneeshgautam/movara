import 'package:flutter/material.dart';

import '../services/badges.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// A grid of achievement badges. Earned ones are bright with an accent border;
/// locked ones are dimmed and show a thin progress bar toward earning them.
class BadgesGrid extends StatelessWidget {
  const BadgesGrid({super.key, required this.badges, this.crossAxisCount = 3});

  final List<BadgeInfo> badges;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.86,
      children: [for (final b in badges) _BadgeTile(badge: b)],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final earned = badge.earned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: earned ? c.surface : c.surface2,
        border: Border.all(
            color: earned ? c.accent.withValues(alpha: 0.45) : c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1 : 0.35,
            child: Text(badge.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 6),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: earned ? c.textPrimary : c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          if (earned && badge.detail != null) ...[
            const SizedBox(height: 3),
            Text(
              badge.detail!,
              style: AppTheme.display(
                  color: c.accent, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ] else if (!earned) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: badge.progress,
                minHeight: 3,
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation(c.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A wide highlight chip for the "highest workout time" record, used on both
/// the Home overview and the Workout tab so the personal best is always front
/// and centre.
class WorkoutRecordChip extends StatelessWidget {
  const WorkoutRecordChip({
    super.key,
    required this.longestLabel,
    required this.hasRecord,
  });

  final String longestLabel;
  final bool hasRecord;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent.withValues(alpha: 0.18), c.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Longest Workout',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  hasRecord ? longestLabel : 'Finish a workout to set it',
                  style: AppTheme.display(
                    color: hasRecord ? c.textPrimary : c.textMuted,
                    fontSize: hasRecord ? 20 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.emoji_events,
              color: hasRecord ? c.accent : c.textMuted, size: 22),
        ],
      ),
    );
  }
}
