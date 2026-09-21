import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../models/run_record.dart' show formatDuration;
import '../services/api_service.dart';
import '../services/workout_log.dart';
import '../services/workout_timer.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/badges_grid.dart';
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
        final longest = log.longestSeconds;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('TODAY',
                      style: AppTheme.display(
                          color: c.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const Spacer(),
                  _pill(context,
                      '$count workout${count == 1 ? '' : 's'}', c.accent),
                  if (log.timeToday() > Duration.zero) ...[
                    const SizedBox(width: 8),
                    _pill(context, formatWorkoutDuration(log.timeToday()),
                        c.textSecondary),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (!active)
                _StartButton(onTap: timer.start)
              else
                _ActiveControls(
                  elapsed: formatDuration(timer.elapsed),
                  running: timer.isRunning,
                  onFinish: () => _finish(context),
                  onPauseResume: timer.isRunning ? timer.pause : timer.start,
                  onDiscard: () => _discard(context),
                ),
              const SizedBox(height: 12),
              WorkoutRecordChip(
                hasRecord: longest > 0,
                longestLabel:
                    formatWorkoutDuration(Duration(seconds: longest)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: AppTheme.display(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: c.accentGlow, blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text('Start Workout',
                style: AppTheme.display(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.elapsed,
    required this.running,
    required this.onFinish,
    required this.onPauseResume,
    required this.onDiscard,
  });

  final String elapsed;
  final bool running;
  final VoidCallback onFinish;
  final VoidCallback onPauseResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, color: c.accent, size: 20),
            const SizedBox(width: 8),
            Text(elapsed,
                style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text(running ? 'in progress' : 'paused',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onFinish,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text('Finish Workout',
                          style: AppTheme.display(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _iconBtn(context, running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPauseResume),
            const SizedBox(width: 8),
            _iconBtn(context, Icons.close_rounded, onDiscard),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: c.textSecondary, size: 22),
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
