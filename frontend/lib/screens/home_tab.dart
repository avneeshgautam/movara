import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/run_record.dart';
import '../models/workout_entry.dart';
import '../services/badges.dart';
import '../services/goal_store.dart';
import '../services/health_service.dart';
import '../services/run_store.dart';
import '../services/workout_log.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/badges_grid.dart';
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
    required this.workoutLog,
    required this.onReload,
  });

  final Future<List<WorkoutEntry>> entriesFuture;
  final RunStore runStore;
  final GoalStore goalStore;
  final WorkoutLog workoutLog;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return RefreshIndicator(
      onRefresh: onReload,
      color: c.accent,
      backgroundColor: c.surface,
      child: AnimatedBuilder(
        animation: Listenable.merge([runStore, goalStore, workoutLog]),
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
              // Streak on top of the reports.
              _StreakBanner(
                streak: stats.streak,
                activeDays: [for (final v in stats.normalizedByWeekday) v > 0],
                todayIndex: DateTime.now().weekday - 1,
              ),
              const SizedBox(height: 12),
              // Two goal rings: today and this week, each sets/distance/steps.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _goalRingCard(
                        context,
                        title: 'Today',
                        v: _todayValues(entries),
                        setsGoal: goalStore.dailySetsGoal,
                        kmGoal: goalStore.dailyKmGoal,
                        stepsGoal: goalStore.dailyStepsGoal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _goalRingCard(
                        context,
                        title: 'Week',
                        v: _weekValues(stats),
                        setsGoal: goalStore.setsGoal,
                        kmGoal: goalStore.kmGoal,
                        stepsGoal: goalStore.stepsGoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2×2 grid so each value has room (4-in-a-row clipped them).
              Row(
                children: [
                  Expanded(
                    child: MiniStat(
                      label: 'Sets',
                      value: '${stats.totalSetsThisWeek}',
                      unit: 'wk',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStat(
                      label: 'Distance',
                      value: runStore.totalKmThisWeek().toStringAsFixed(1),
                      unit: 'km',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MiniStat(
                      label: 'Active',
                      value: '${runStore.activeMinutesThisWeek()}',
                      unit: 'min',
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Today's real steps from Apple Health when connected,
                  // otherwise this week's steps estimated from activities.
                  Expanded(
                    child: _StepsStat(
                      weeklyEstimate: runStore.stepsThisWeek(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Self Achievements'),
              ..._achievements(context, stats, entries),
              const SizedBox(height: 24),

              _badgesSection(context, stats),
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

  ({int sets, double km, int steps}) _todayValues(List<WorkoutEntry> entries) =>
      (
        sets: _todaySets(entries),
        km: runStore.kmToday(),
        steps: runStore.stepsToday(),
      );

  ({int sets, double km, int steps}) _weekValues(WeekStats stats) => (
        sets: stats.totalSetsThisWeek,
        km: runStore.totalKmThisWeek(),
        steps: runStore.stepsThisWeek(),
      );

  bool _goalReached(WeekStats stats) {
    return goalStore.setsGoal > 0 &&
        goalStore.kmGoal > 0 &&
        stats.totalSetsThisWeek >= goalStore.setsGoal &&
        runStore.totalKmThisWeek() >= goalStore.kmGoal;
  }

  static String _shortK(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  BadgeStats _badgeStats(WeekStats stats) {
    final longestRun = runStore.longestRun;
    final types = runStore.runs.map((r) => r.activityType).toSet();
    return BadgeStats(
      workoutCount: workoutLog.totalCount,
      longestWorkoutSeconds: workoutLog.longestSeconds,
      workoutStreakDays: workoutLog.streakDays,
      workoutsThisWeek: workoutLog.countThisWeek(),
      totalKm: runStore.totalKmAllTime,
      longestRunKm: longestRun?.distanceKm ?? 0,
      runCount: runStore.runs.length,
      stepsThisWeek: runStore.stepsThisWeek(),
      activityTypes: types.length,
    );
  }

  /// The full badge wall on Home: the highlighted "longest workout" record on
  /// top, then every badge (earned and locked with progress).
  Widget _badgesSection(BuildContext context, WeekStats stats) {
    final badges = computeBadges(_badgeStats(stats));
    final earned = earnedCount(badges);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Badges', action: '$earned/${badges.length} earned'),
        WorkoutRecordChip(
          hasRecord: workoutLog.longestSeconds > 0,
          longestLabel: formatWorkoutDuration(
              Duration(seconds: workoutLog.longestSeconds)),
        ),
        const SizedBox(height: 12),
        BadgesGrid(badges: badges),
      ],
    );
  }

  Widget _goalRingCard(
    BuildContext context, {
    required String title,
    required ({int sets, double km, int steps}) v,
    required int setsGoal,
    required double kmGoal,
    required int stepsGoal,
  }) {
    final c = context.movara;
    double pct(num cur, num goal) => goal <= 0 ? 0 : (cur / goal).toDouble();

    return MovaraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DualGoalRing(
            outer: pct(v.sets, setsGoal),
            inner: pct(v.km, kmGoal),
            third: pct(v.steps, stepsGoal),
            outerColor: c.accent,
            innerColor: c.blue,
            thirdColor: c.green,
            centerTop: title,
            centerBottom: 'goal',
            size: 104,
          ),
          const SizedBox(height: 10),
          _legend(context, c.accent, 'Sets', '${v.sets}/$setsGoal'),
          const SizedBox(height: 5),
          _legend(context, c.blue, 'Km',
              '${v.km.toStringAsFixed(1)}/${kmGoal.toStringAsFixed(0)}'),
          const SizedBox(height: 5),
          _legend(context, c.green, 'Steps',
              '${_shortK(v.steps)}/${_shortK(stepsGoal)}'),
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
    final result = await showDialog<({int sets, double km, int steps})>(
      context: context,
      builder: (_) => _GoalDialog(
        sets: goalStore.setsGoal,
        km: goalStore.kmGoal,
        steps: goalStore.stepsGoal,
      ),
    );
    if (result != null) {
      await goalStore.save(
        period: GoalPeriod.weekly,
        sets: result.sets,
        km: result.km,
        steps: result.steps,
      );
    }
  }

  /// Achievements derived from real trends in the user's own history — a
  /// streak, week-over-week progress, personal bests and lifetime milestones.
  /// Returns cards spaced by gaps, or an encouraging empty state.
  List<Widget> _achievements(
      BuildContext context, WeekStats stats, List<WorkoutEntry> entries) {
    final c = context.movara;
    final cards = <Widget>[];

    if (stats.streak > 0) {
      cards.add(AchievementCard(
        emoji: '🔥',
        title: stats.streak == 1
            ? 'First Day Logged'
            : '${stats.streak}-Day Streak',
        description: 'Keep the momentum going',
        date: 'Today',
        tint: c.greenSoft,
      ));
    }

    if (_goalReached(stats)) {
      cards.add(AchievementCard(
        emoji: '🎯',
        title: 'Weekly Goal Reached',
        description: 'Your sets and distance goals are done',
        date: 'This week',
        tint: c.accentSoft,
      ));
    }

    // Trending up: more distance this week than last.
    final thisWk = runStore.totalKmThisWeek();
    final lastWk = runStore.totalKmLastWeek();
    if (lastWk > 0.1 && thisWk > lastWk) {
      final pct = ((thisWk - lastWk) / lastWk * 100).round();
      cards.add(AchievementCard(
        emoji: '📈',
        title: 'Trending Up',
        description: '$pct% more distance than last week',
        date: 'This week',
        tint: c.greenSoft,
      ));
    }

    // Personal best pace.
    final fastest = runStore.fastestPace;
    if (fastest != null && fastest.paceSecondsPerKm > 0) {
      cards.add(AchievementCard(
        emoji: '⚡',
        title: 'Best Pace',
        description: '${formatPace(fastest.paceSecondsPerKm)} /km over '
            '${fastest.distanceKm.toStringAsFixed(1)} km',
        date: _relativeDay(fastest.startedAt),
        tint: c.blueSoft,
      ));
    }

    // Lifetime distance milestone.
    final total = runStore.totalKmAllTime;
    final milestone = [100, 50, 25, 10, 5, 1]
        .cast<int>()
        .firstWhere((m) => total >= m, orElse: () => 0);
    if (milestone > 0) {
      cards.add(AchievementCard(
        emoji: '🏅',
        title: '$milestone km Club',
        description: '${total.toStringAsFixed(1)} km all-time',
        date: 'Lifetime',
        tint: c.accentSoft,
      ));
    }

    // Variety: tried more than one activity type.
    final types = runStore.runs.map((r) => r.activityType).toSet();
    if (types.length >= 2) {
      cards.add(AchievementCard(
        emoji: '🧭',
        title: 'All-Rounder',
        description: '${types.length} activity types tried',
        date: 'Lifetime',
        tint: c.greenSoft,
      ));
    }

    if (cards.isEmpty) {
      return [
        AchievementCard(
          emoji: '🌱',
          title: 'Just Getting Started',
          description: 'Log a workout or record a run to unlock achievements',
          date: 'Now',
          tint: c.surface2,
        ),
      ];
    }

    // Show the strongest few, spaced out.
    final top = cards.take(4).toList();
    return [
      for (var i = 0; i < top.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        top[i],
      ],
    ];
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

/// Sets the weekly goals (sets, distance, steps). Daily targets are derived.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog(
      {required this.sets, required this.km, required this.steps});

  final int sets;
  final double km;
  final int steps;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _sets =
      TextEditingController(text: '${widget.sets}');
  late final TextEditingController _km =
      TextEditingController(text: widget.km.toStringAsFixed(0));
  late final TextEditingController _steps =
      TextEditingController(text: '${widget.steps}');

  @override
  void dispose() {
    _sets.dispose();
    _km.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _save() {
    final sets = int.tryParse(_sets.text.trim()) ?? widget.sets;
    final km = double.tryParse(_km.text.trim()) ?? widget.km;
    final steps = int.tryParse(_steps.text.trim()) ?? widget.steps;
    Navigator.pop(context, (sets: sets, km: km, steps: steps));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Weekly goals',
          style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your daily targets are these divided by 7.',
              style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          _numberField(c, _sets, 'Workout sets / week', false),
          const SizedBox(height: 12),
          _numberField(c, _km, 'Distance / week (km)', true),
          const SizedBox(height: 12),
          _numberField(c, _steps, 'Steps / week', false),
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

/// The Home steps tile: shows today's real steps from Apple Health when it is
/// connected, otherwise falls back to steps estimated from this week's logged
/// activities. Reads once when the tab is built.
class _StepsStat extends StatefulWidget {
  const _StepsStat({required this.weeklyEstimate});

  final int weeklyEstimate;

  @override
  State<_StepsStat> createState() => _StepsStatState();
}

class _StepsStatState extends State<_StepsStat> with WidgetsBindingObserver {
  int? _today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-read after the user comes back — e.g. from granting Health access in
    // Settings, or after walking around with the app backgrounded.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!HealthService.instance.isSupported) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final steps = await HealthService.instance.steps(start, now);
    if (mounted && steps != null && steps > 0) setState(() => _today = steps);
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return MiniStat(
      label: 'Steps',
      value: formatSteps(today ?? widget.weeklyEstimate),
      unit: today != null ? 'today' : 'wk',
    );
  }
}

/// The streak, shown on top of the overview: an animated count-up with the
/// week's active days as dots.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({
    required this.streak,
    required this.activeDays,
    required this.todayIndex,
  });

  final int streak;
  final List<bool> activeDays;
  final int todayIndex;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return MovaraCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: streak),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    builder: (context, val, _) => Text(
                      '$val',
                      style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('day streak',
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(streak > 0 ? 'Keep it going!' : 'Log today to start one',
                  style: TextStyle(color: c.textMuted, fontSize: 10)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeDays[i] ? c.accent : c.surface3,
                        border: i == todayIndex
                            ? Border.all(color: c.accent, width: 1.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_days[i],
                        style: TextStyle(
                            fontSize: 8,
                            color: i == todayIndex ? c.accent : c.textMuted)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
