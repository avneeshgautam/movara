import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_entry.dart';

class WorkoutEntryCard extends StatelessWidget {
  const WorkoutEntryCard({super.key, required this.entry, required this.onDelete});

  final WorkoutEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weight = entry.weightKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.fitness_center, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.sets} sets × ${entry.reps} reps'
                    '${weight != null ? ' @ ${_formatWeight(weight)} kg' : ''}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    DateFormat.yMMMd().format(entry.performedAt),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: scheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatWeight(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
