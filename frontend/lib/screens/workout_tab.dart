import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/workout_entry_card.dart';
import 'add_entry_screen.dart';

/// The Workout tab: the log of every set, with the "Log a set" action.
///
/// Entries are owned by the shell and passed in; [onReload] re-fetches them
/// after a create or delete so the Home dashboard stays in sync.
class WorkoutTab extends StatelessWidget {
  const WorkoutTab({
    super.key,
    required this.api,
    required this.entriesFuture,
    required this.onReload,
  });

  final ApiService api;
  final Future<List<WorkoutEntry>> entriesFuture;
  final Future<void> Function() onReload;

  Future<void> _openAddEntry(BuildContext context) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEntryScreen(api: api)),
    );
    if (added == true) await onReload();
  }

  Future<void> _delete(BuildContext context, WorkoutEntry entry) async {
    if (entry.id == null) return;
    try {
      await api.deleteWorkoutEntry(entry.id!);
      await onReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEntry(context),
        icon: const Icon(Icons.add),
        label: Text(
          'Log a set',
          style: AppTheme.display(color: Colors.white, fontSize: 14),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onReload,
        color: c.accent,
        backgroundColor: c.surface,
        child: FutureBuilder<List<WorkoutEntry>>(
          future: entriesFuture,
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <WorkoutEntry>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                SectionHeader(
                  title: 'Workout Log',
                  action: entries.isEmpty ? null : '${entries.length} logged',
                ),
                ..._buildBody(context, snapshot, entries),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    AsyncSnapshot<List<WorkoutEntry>> snapshot,
    List<WorkoutEntry> entries,
  ) {
    final c = context.movara;

    if (snapshot.connectionState == ConnectionState.waiting) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(color: c.accent)),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        MovaraCard(
          child: Column(
            children: [
              Icon(Icons.cloud_off, color: c.textMuted, size: 32),
              const SizedBox(height: 12),
              Text(
                "Couldn't reach the backend.",
                style: AppTheme.display(color: c.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ];
    }

    if (entries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: MovaraCard(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              children: [
                const Text('🧘', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 14),
                Text(
                  'No sets logged yet',
                  style: AppTheme.display(color: c.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Log a set" to get started.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      for (final entry in entries) ...[
        WorkoutEntryCard(entry: entry, onDelete: () => _delete(context, entry)),
        const SizedBox(height: 10),
      ],
    ];
  }
}
