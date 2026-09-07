import 'package:flutter/material.dart';

import '../models/run_record.dart' show formatDuration;
import '../services/workout_timer.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Sits above the exercises: a stopwatch for total workout time (counts up,
/// persisted for the day) and a rest timer that counts down between sets.
class WorkoutTimerBar extends StatefulWidget {
  const WorkoutTimerBar({super.key, required this.stopwatch});

  final WorkoutTimer stopwatch;

  @override
  State<WorkoutTimerBar> createState() => _WorkoutTimerBarState();
}

class _WorkoutTimerBarState extends State<WorkoutTimerBar> {
  static const _presets = [30, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AnimatedBuilder(
      animation: widget.stopwatch,
      builder: (context, _) => Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stopwatchRow(context),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 12),
          _restRow(context),
        ],
      ),
      ),
    );
  }

  Widget _stopwatchRow(BuildContext context) {
    final c = context.movara;
    return AnimatedBuilder(
      animation: widget.stopwatch,
      builder: (context, _) {
        final sw = widget.stopwatch;
        return Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: c.accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORKOUT TIME',
                    style: TextStyle(
                        color: c.textMuted, fontSize: 9, letterSpacing: 1.2)),
                Text(formatDuration(sw.elapsed),
                    style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            _pill(
              context,
              icon: sw.isRunning ? Icons.pause : Icons.play_arrow,
              label: sw.isRunning ? 'Pause' : 'Start',
              filled: !sw.isRunning,
              onTap: () => sw.isRunning ? sw.pause() : sw.start(),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sw.elapsed == Duration.zero ? null : sw.reset,
              child: Icon(Icons.replay,
                  size: 20,
                  color: sw.elapsed == Duration.zero ? c.border : c.textMuted),
            ),
          ],
        );
      },
    );
  }

  Widget _restRow(BuildContext context) {
    final c = context.movara;
    final sw = widget.stopwatch;
    final resting = sw.isResting;

    if (resting) {
      final left = sw.restRemaining;
      final progress = sw.restProgress;
      return Row(
        children: [
          Icon(Icons.hourglass_bottom, size: 18, color: c.green),
          const SizedBox(width: 8),
          Text('REST',
              style: TextStyle(
                  color: c.textMuted, fontSize: 9, letterSpacing: 1.2)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: c.surface3,
                valueColor: AlwaysStoppedAnimation(c.green),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(formatDuration(left),
              style: AppTheme.display(
                  color: c.green, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sw.cancelRest,
            child: Icon(Icons.close, size: 18, color: c.textMuted),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.hourglass_empty, size: 18, color: c.textMuted),
        const SizedBox(width: 8),
        Text('REST',
            style:
                TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 1.2)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            children: [
              for (final s in _presets)
                GestureDetector(
                  onTap: () => widget.stopwatch.startRest(s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_presetLabel(s),
                        style: AppTheme.display(
                            color: c.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _presetLabel(int s) {
    if (s < 60) return '${s}s';
    if (s % 60 == 0) return '${s ~/ 60}m';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _pill(BuildContext context,
      {required IconData icon,
      required String label,
      required bool filled,
      required VoidCallback onTap}) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.surface2,
          border: Border.all(color: filled ? c.accent : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : c.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: AppTheme.display(
                    color: filled ? Colors.white : c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
