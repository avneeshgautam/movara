import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_entry.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import 'dashboard_widgets.dart';

class WorkoutEntryCard extends StatelessWidget {
  const WorkoutEntryCard({super.key, required this.entry, required this.onDelete});

  final WorkoutEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final weight = entry.weightKg;

    return MovaraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.fitness_center, size: 20, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.exerciseName,
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.sets} sets × ${entry.reps} reps'
                  '${weight != null ? ' @ ${_formatWeight(weight)} kg' : ''}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                Text(
                  DateFormat.yMMMd().format(entry.performedAt),
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: c.textMuted,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatWeight(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
