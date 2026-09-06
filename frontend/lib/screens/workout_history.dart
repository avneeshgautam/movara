import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_entry.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Past logged sets, grouped by day, newest first.
///
/// Reads the same entry list the rest of the app uses, so it needs no extra
/// fetch and stays in sync with logging on the Workout tab.
class WorkoutHistory extends StatelessWidget {
  const WorkoutHistory({super.key, required this.entries});

  final List<WorkoutEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final days = _byDay(entries);

    if (days.isEmpty) {
      return _empty(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final totalSets = day.entries.fold<int>(0, (a, e) => a + e.sets);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dayLabel(day.date),
                      style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$totalSets ${totalSets == 1 ? 'set' : 'sets'} · '
                      '${day.entries.length} ${day.entries.length == 1 ? 'exercise' : 'exercises'}',
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              for (final e in day.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.exerciseName,
                          style: AppTheme.display(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _detail(e),
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  static String _detail(WorkoutEntry e) {
    final base = '${e.sets} × ${e.reps}';
    if (e.weightKg != null && e.weightKg! > 0) {
      final w = e.weightKg!;
      final kg = w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      return '$base · $kg kg';
    }
    return base;
  }

  Widget _empty(BuildContext context) {
    final c = context.movara;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🗒️', style: TextStyle(fontSize: 30, color: c.textMuted)),
            const SizedBox(height: 12),
            Text('No history yet',
                style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Sets you log on the Log tab show up here, grouped by day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Today / Yesterday / weekday within the last week / a date beyond that.
  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(day);
    return DateFormat('EEE, d MMM').format(day);
  }

  static List<_Day> _byDay(List<WorkoutEntry> entries) {
    final map = <DateTime, List<WorkoutEntry>>{};
    for (final e in entries) {
      final day =
          DateTime(e.performedAt.year, e.performedAt.month, e.performedAt.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    final days = map.entries.map((m) => _Day(m.key, m.value)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return days;
  }
}

class _Day {
  _Day(this.date, this.entries);
  final DateTime date;
  final List<WorkoutEntry> entries;
}
