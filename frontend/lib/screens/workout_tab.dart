import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../models/run_record.dart' show formatDuration;
import '../services/api_service.dart';
import '../services/workout_log.dart';
import '../services/workout_timer.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import 'workout_history.dart';
import 'workout_session.dart';

/// The Workout tab: a category-based exercise session (see [WorkoutSession]).
///
/// Marking a set "done" logs it to the backend so the Home dashboard's streak
/// and weekly stats stay in sync; un-checking removes that logged set. Today's
/// entries are passed down so completed sets survive a refresh.
class WorkoutTab extends StatefulWidget {
  const WorkoutTab({
    super.key,
    required this.api,
    required this.entriesFuture,
    required this.workoutTimer,
    required this.workoutLog,
    required this.onReload,
  });

  final ApiService api;
  final Future<List<WorkoutEntry>> entriesFuture;
  final WorkoutTimer workoutTimer;
  final WorkoutLog workoutLog;
  final Future<void> Function() onReload;

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  bool _showHistory = false;

  Future<String?> _logSet(String exerciseName, int reps, double weightKg) async {
    try {
      final entry = await widget.api.addWorkoutEntry(WorkoutEntry(
        exerciseName: exerciseName,
        sets: 1,
        reps: reps,
        weightKg: weightKg > 0 ? weightKg : null,
        performedAt: DateTime.now(),
      ));
      await widget.onReload();
      return entry.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _unlogSet(String entryId) async {
    try {
      await widget.api.deleteWorkoutEntry(entryId);
      await widget.onReload();
    } catch (_) {
      // Best-effort; the next reload reconciles.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return FutureBuilder<List<WorkoutEntry>>(
      future: widget.entriesFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <WorkoutEntry>[];
        return Container(
          color: c.bg,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: _SegmentedToggle(
                    left: 'Log',
                    right: 'History',
                    rightSelected: _showHistory,
                    onChanged: (history) =>
                        setState(() => _showHistory = history),
                  ),
                ),
                Expanded(
                  child: _showHistory
                      ? WorkoutHistory(entries: entries)
                      : Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 4),
                              child: WorkoutSessionCard(
                                timer: widget.workoutTimer,
                                log: widget.workoutLog,
                              ),
                            ),
                            Expanded(
                              child: WorkoutSession(
                                entries: entries,
                                onLogSet: _logSet,
                                onUnlogSet: _unlogSet,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The "Start / Finish Workout" control shown above the exercise list.
///
/// Reuses the shared [WorkoutTimer] (so the header chip and this card show the
/// same running time) and records each finished session into [WorkoutLog],
/// which drives the daily workout count and the "longest workout" record.
class WorkoutSessionCard extends StatelessWidget {
  const WorkoutSessionCard({super.key, required this.timer, required this.log});

  final WorkoutTimer timer;
  final WorkoutLog log;

  Future<void> _finish(BuildContext context) async {
    final elapsed = timer.elapsed;
    final messenger = ScaffoldMessenger.of(context);
    if (elapsed.inSeconds < 20) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Keep going — workouts under 20s aren\'t logged.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    await log.add(duration: elapsed);
    await timer.reset();
    messenger.showSnackBar(SnackBar(
      content: Text('Workout logged · ${formatDuration(elapsed)} 💪'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _discard(BuildContext context) async {
    await timer.reset();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AnimatedBuilder(
      animation: Listenable.merge([timer, log]),
      builder: (context, _) {
        final count = log.countToday();
        final active = timer.isRunning || timer.elapsed > Duration.zero;
        final today = log.timeToday();
        // One compact row so the exercise list keeps the screen. The
        // longest-workout record lives on Home.
        return Container(
          height: 56,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (!active) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$count workout${count == 1 ? '' : 's'} today',
                          style: AppTheme.display(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      if (today > Duration.zero)
                        Text('${formatWorkoutDuration(today)} trained',
                            style:
                                TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                _pillButton(
                  context,
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  color: c.accent,
                  onTap: timer.start,
                ),
              ] else ...[
                // Scales down instead of overflowing on narrow phones or
                // once the timer reaches hours.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded, color: c.accent, size: 18),
                        const SizedBox(width: 6),
                        Text(formatDuration(timer.elapsed),
                            style: AppTheme.display(
                                color: c.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Text(timer.isRunning ? 'live' : 'paused',
                            style:
                                TextStyle(color: c.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _iconButton(
                  context,
                  timer.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  timer.isRunning ? timer.pause : timer.start,
                ),
                const SizedBox(width: 6),
                _iconButton(
                    context, Icons.close_rounded, () => _discard(context)),
                const SizedBox(width: 6),
                _pillButton(
                  context,
                  icon: Icons.check_rounded,
                  label: 'Finish',
                  color: c.green,
                  onTap: () => _finish(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _pillButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(label,
                style: AppTheme.display(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: c.textSecondary, size: 20),
      ),
    );
  }
}

/// Two-option pill toggle, used to switch a tab between two views.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segment(context, left, !rightSelected, () => onChanged(false)),
          _segment(context, right, rightSelected, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = context.movara;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: AppTheme.display(
              color: selected ? Colors.white : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
