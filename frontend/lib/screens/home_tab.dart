import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/run_record.dart';
import '../models/workout_entry.dart';
import '../services/goal_store.dart';
import '../services/run_store.dart';
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
    required this.runStore,
    required this.goalStore,
    required this.onReload,
  });

  final Future<List<WorkoutEntry>> entriesFuture;
  final RunStore runStore;
  final GoalStore goalStore;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return RefreshIndicator(
      onRefresh: onReload,
      color: c.accent,
      backgroundColor: c.surface,
      child: AnimatedBuilder(
        animation: Listenable.merge([runStore, goalStore]),
        builder: (context, _) => FutureBuilder<List<WorkoutEntry>>(
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
              ] else if (snapshot.connectionState ==
                  ConnectionState.waiting) ...[
                _WakingBanner(),
                const SizedBox(height: 20),
              ],

              SectionHeader(
                title: "Today's Overview",
                action: 'Edit Goal →',
                onAction: () => _editGoal(context),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MovaraCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Real: sets logged this week against the user's goal.
                          GoalRing(
                            percent: goalStore.weeklySets <= 0
                                ? 0
                                : (stats.totalSetsThisWeek /
                                        goalStore.weeklySets *
                                        100)
                                    .clamp(0, 100)
                                    .round(),
                            size: 130,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Weekly Goal',
                            style: AppTheme.display(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${stats.totalSetsThisWeek} / ${goalStore.weeklySets} sets',
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
                  // Real: distance run and minutes active this week.
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStat(
                      label: 'Distance',
                      value: runStore.totalKmThisWeek().toStringAsFixed(1),
                      unit: 'km',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStat(
                      label: 'Active',
                      value: '${runStore.activeMinutesThisWeek()}',
                      unit: 'min',
                    ),
                  ),
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
              if (stats.totalSetsThisWeek >= goalStore.weeklySets &&
                  goalStore.weeklySets > 0) ...[
                AchievementCard(
                  emoji: '🎯',
                  title: 'Weekly Goal Reached',
                  description:
                      '${stats.totalSetsThisWeek} of ${goalStore.weeklySets} sets this week',
                  date: 'This week',
                  tint: c.accentSoft,
                ),
                const SizedBox(height: 10),
              ],
              if (_runAchievement(context) case final card?) ...[
                const SizedBox(height: 10),
                card,
              ],
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
      ),
    );
  }

  Future<void> _editGoal(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(current: goalStore.weeklySets),
    );
    if (result != null) await goalStore.setWeeklySets(result);
  }

  /// A real running achievement from recorded runs, or null when none exist
  /// yet -- rather than the old hardcoded "5K in 24 min".
  Widget? _runAchievement(BuildContext context) {
    final c = context.movara;
    final longest = runStore.longestRun;
    if (longest == null || longest.distanceKm < 0.1) return null;

    final fastest = runStore.fastestPace;
    if (fastest != null) {
      return AchievementCard(
        emoji: '⚡',
        title: 'Best Pace',
        description: '${formatPace(fastest.paceSecondsPerKm)} /km over '
            '${fastest.distanceKm.toStringAsFixed(1)} km',
        date: _relativeDay(fastest.startedAt),
        tint: c.blueSoft,
      );
    }
    return AchievementCard(
      emoji: '🏃',
      title: 'Longest Run',
      description: '${longest.distanceKm.toStringAsFixed(2)} km',
      date: _relativeDay(longest.startedAt),
      tint: c.blueSoft,
    );
  }

  static String _relativeDay(DateTime when) {
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return '${when.day}/${when.month}';
  }
}

class _WakingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return MovaraCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waking the server… the free tier sleeps when idle.',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
        ],
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

/// Sets the weekly sets goal: a few presets plus a typed value.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.current});

  final int current;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  static const _presets = [20, 30, 40, 60];
  late final TextEditingController _field =
      TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final n = int.tryParse(_field.text.trim()) ?? widget.current;
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Weekly goal',
          style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many sets do you want to log each week?',
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _presets)
                GestureDetector(
                  onTap: () => setState(() => _field.text = '$p'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _field.text == '$p' ? c.accent : c.surface2,
                      border: Border.all(
                          color: _field.text == '$p' ? c.accent : c.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$p',
                        style: AppTheme.display(
                            color: _field.text == '$p'
                                ? Colors.white
                                : c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _field,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: c.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Sets per week',
              labelStyle: TextStyle(color: c.textMuted),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.accent)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textMuted))),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: c.accent, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
