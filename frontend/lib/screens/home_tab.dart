import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/goal_ring.dart';

/// The overview / dashboard shown on the Home tab: goal ring, streak, weekly
/// stats and achievements. The actual set logging lives on the Workout tab.
///
/// Entries are owned by the shell and passed in, so logging or deleting on the
/// Workout tab refreshes these figures too.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.entriesFuture,
    required this.onReload,
  });

  final Future<List<WorkoutEntry>> entriesFuture;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return RefreshIndicator(
      onRefresh: onReload,
      color: c.accent,
      backgroundColor: c.surface,
      child: FutureBuilder<List<WorkoutEntry>>(
        future: entriesFuture,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <WorkoutEntry>[];
          final stats = WeekStats.from(entries);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (snapshot.hasError) ...[
                _BackendError(error: snapshot.error),
                const SizedBox(height: 20),
              ],

              const SectionHeader(title: "Today's Overview", action: 'Edit Goal →'),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MovaraCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // TODO: wire to a real step source; 72% is from the mockup.
                          const GoalRing(percent: 72, size: 130),
                          const SizedBox(height: 10),
                          Text(
                            'Daily Goal',
                            style: AppTheme.display(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '7,200 / 10,000 steps',
                            style: TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: StreakCard(days: stats.streak)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  // Real: total sets logged this week.
                  Expanded(
                    child: MiniStat(
                      label: 'Sets',
                      value: '${stats.totalSetsThisWeek}',
                      unit: 'wk',
                    ),
                  ),
                  // TODO: placeholders -- no distance/active-minutes source yet.
                  const SizedBox(width: 10),
                  const Expanded(child: MiniStat(label: 'Distance', value: '4.2', unit: 'km')),
                  const SizedBox(width: 10),
                  const Expanded(child: MiniStat(label: 'Active', value: '38', unit: 'min')),
                ],
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Self Achievements', action: 'See all →'),
              // Streak card is real; the other two are still mockup content.
              if (stats.streak > 0) ...[
                AchievementCard(
                  emoji: '🔥',
                  title: stats.streak == 1
                      ? 'First Day Logged'
                      : '${stats.streak}-Day Streak',
                  description: 'Keep the momentum going',
                  date: 'Today',
                  tint: c.greenSoft,
                ),
                const SizedBox(height: 10),
              ],
              AchievementCard(
                emoji: '🏅',
                title: '10,000 Steps',
                description: 'Daily goal crushed!',
                date: 'Today',
                tint: c.accentSoft,
              ),
              const SizedBox(height: 10),
              AchievementCard(
                emoji: '⚡',
                title: 'Personal Best',
                description: '5K run in 24 min',
                date: 'Yesterday',
                tint: c.blueSoft,
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'This Week'),
              WeeklyChart(
                values: stats.normalizedByWeekday,
                todayIndex: DateTime.now().weekday - 1,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackendError extends StatelessWidget {
  const _BackendError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return MovaraCard(
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: c.textMuted, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Couldn't reach the backend",
                  style: AppTheme.display(color: c.textPrimary, fontSize: 13),
                ),
                Text(
                  'Pull down to retry.',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Week-level figures derived from the real entry list.
class WeekStats {
  const WeekStats({
    required this.normalizedByWeekday,
    required this.streak,
    required this.totalSetsThisWeek,
  });

  /// Seven values in 0..1, Monday first, scaled against the busiest day.
  final List<double> normalizedByWeekday;

  /// Consecutive days with at least one entry, counting back from today.
  final int streak;

  /// Sets logged Monday-to-today of the current week.
  final int totalSetsThisWeek;

  factory WeekStats.from(List<WorkoutEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final setsPerWeekday = List<int>.filled(7, 0);
    final daysWithEntries = <DateTime>{};

    for (final e in entries) {
      final day = DateTime(
        e.performedAt.year,
        e.performedAt.month,
        e.performedAt.day,
      );
      daysWithEntries.add(day);

      final offset = day.difference(monday).inDays;
      if (offset >= 0 && offset < 7) {
        setsPerWeekday[offset] += e.sets;
      }
    }

    final busiest = setsPerWeekday.fold<int>(0, (m, v) => v > m ? v : m);
    final normalized = busiest == 0
        ? List<double>.filled(7, 0)
        : setsPerWeekday.map((v) => v / busiest).toList();

    // Walk backwards from today until a day has no entries.
    var streak = 0;
    var cursor = today;
    while (daysWithEntries.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return WeekStats(
      normalizedByWeekday: normalized,
      streak: streak,
      totalSetsThisWeek: setsPerWeekday.fold<int>(0, (a, b) => a + b),
    );
  }
}
