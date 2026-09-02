import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import 'workout_session.dart';

/// The Workout tab: a category-based exercise session (see [WorkoutSession]).
///
/// Marking a set "done" logs it to the backend so the Home dashboard's streak
/// and weekly stats stay in sync; un-checking removes that logged set.
class WorkoutTab extends StatelessWidget {
  const WorkoutTab({super.key, required this.api, required this.onReload});

  final ApiService api;
  final Future<void> Function() onReload;

  Future<String?> _logSet(String exerciseName, int reps, double weightKg) async {
    try {
      final entry = await api.addWorkoutEntry(WorkoutEntry(
        exerciseName: exerciseName,
        sets: 1,
        reps: reps,
        weightKg: weightKg > 0 ? weightKg : null,
        performedAt: DateTime.now(),
      ));
      await onReload();
      return entry.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _unlogSet(String entryId) async {
    try {
      await api.deleteWorkoutEntry(entryId);
      await onReload();
    } catch (_) {
      // Best-effort; the Home stats will reconcile on next reload.
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkoutSession(onLogSet: _logSet, onUnlogSet: _unlogSet);
  }
}
