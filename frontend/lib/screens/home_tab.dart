import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/run_record.dart';
import '../models/workout_entry.dart';
import '../services/goal_store.dart';
import '../services/run_store.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/dual_goal_ring.dart';

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
                    _goalCard(context, stats, entries),
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
              if (_goalReached(stats, entries)) ...[
                AchievementCard(
                  emoji: '🎯',
                  title: '${goalStore.periodLabel} Goal Reached',
                  description: 'Both your sets and distance goals are done',
                  date: goalStore.periodLabel,
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

  int _todaySets(List<WorkoutEntry> entries) {
    final now = DateTime.now();
    return entries
        .where((e) =>
            e.performedAt.year == now.year &&
            e.performedAt.month == now.month &&
            e.performedAt.day == now.day)
        .fold<int>(0, (a, e) => a + e.sets);
  }

  ({int sets, double km}) _current(WeekStats stats, List<WorkoutEntry> entries) {
    if (goalStore.period == GoalPeriod.daily) {
      return (sets: _todaySets(entries), km: runStore.kmToday());
    }
    return (sets: stats.totalSetsThisWeek, km: runStore.totalKmThisWeek());
  }

  bool _goalReached(WeekStats stats, List<WorkoutEntry> entries) {
    final cur = _current(stats, entries);
    return goalStore.setsGoal > 0 &&
        goalStore.kmGoal > 0 &&
        cur.sets >= goalStore.setsGoal &&
        cur.km >= goalStore.kmGoal;
  }

  Widget _goalCard(
      BuildContext context, WeekStats stats, List<WorkoutEntry> entries) {
    final c = context.movara;
    final cur = _current(stats, entries);
    final setsPct =
        goalStore.setsGoal <= 0 ? 0.0 : cur.sets / goalStore.setsGoal;
    final kmPct = goalStore.kmGoal <= 0 ? 0.0 : cur.km / goalStore.kmGoal;

    return MovaraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DualGoalRing(
            outer: setsPct,
            inner: kmPct,
            outerColor: c.accent,
            innerColor: c.blue,
            centerTop: goalStore.periodLabel,
            centerBottom: 'goal',
            size: 118,
          ),
          const SizedBox(height: 12),
          _legend(context, c.accent, 'Sets', '${cur.sets} / ${goalStore.setsGoal}'),
          const SizedBox(height: 6),
          _legend(context, c.blue, 'Run',
              '${cur.km.toStringAsFixed(1)} / ${goalStore.kmGoal.toStringAsFixed(0)} km'),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color dot, String label, String value) {
    final c = context.movara;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value,
            style: AppTheme.display(
                color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _editGoal(BuildContext context) async {
    final result = await showDialog<({GoalPeriod period, int sets, double km})>(
      context: context,
      builder: (_) => _GoalDialog(
        period: goalStore.period,
        sets: goalStore.setsGoal,
        km: goalStore.kmGoal,
      ),
    );
    if (result != null) {
      await goalStore.save(
          period: result.period, sets: result.sets, km: result.km);
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connecting to server…',
                    style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('Waking it up — the free tier sleeps when idle.',
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ],
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

/// Sets the goal: a Daily/Weekly period plus sets and distance targets.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.period, required this.sets, required this.km});

  final GoalPeriod period;
  final int sets;
  final double km;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late GoalPeriod _period = widget.period;
  late final TextEditingController _sets =
      TextEditingController(text: '${widget.sets}');
  late final TextEditingController _km =
      TextEditingController(text: widget.km.toStringAsFixed(0));

  @override
  void dispose() {
    _sets.dispose();
    _km.dispose();
    super.dispose();
  }

  void _save() {
    final sets = int.tryParse(_sets.text.trim()) ?? widget.sets;
    final km = double.tryParse(_km.text.trim()) ?? widget.km;
    Navigator.pop(context, (period: _period, sets: sets, km: km));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Your goal',
          style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period toggle.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _periodSeg('Daily', GoalPeriod.daily),
                _periodSeg('Weekly', GoalPeriod.weekly),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _numberField(c, _sets, 'Workout sets', false),
          const SizedBox(height: 12),
          _numberField(c, _km, 'Running distance (km)', true),
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

  Widget _periodSeg(String label, GoalPeriod p) {
    final c = context.movara;
    final selected = _period == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = p),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: AppTheme.display(
                  color: selected ? Colors.white : c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _numberField(
      MovaraColors c, TextEditingController ctrl, String label, bool decimal) {
    return TextField(
      controller: ctrl,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textMuted),
        focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: c.accent)),
      ),
    );
  }
}
