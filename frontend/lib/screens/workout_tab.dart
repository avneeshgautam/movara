import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
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
    required this.onReload,
  });

  final ApiService api;
  final Future<List<WorkoutEntry>> entriesFuture;
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
                      : WorkoutSession(
                          entries: entries,
                          onLogSet: _logSet,
                          onUnlogSet: _unlogSet,
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
