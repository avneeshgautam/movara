import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/workout_entry_card.dart';
import 'add_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  late Future<List<WorkoutEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _api.fetchWorkoutEntries();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _entriesFuture = _api.fetchWorkoutEntries());
    await _entriesFuture;
  }

  Future<void> _openAddEntry() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEntryScreen(api: _api)),
    );
    if (added == true) {
      _refresh();
    }
  }

  Future<void> _delete(WorkoutEntry entry) async {
    if (entry.id == null) return;
    setState(() {
      _entriesFuture = _api.deleteWorkoutEntry(entry.id!).then((_) => _api.fetchWorkoutEntries());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movara')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddEntry,
        icon: const Icon(Icons.add),
        label: const Text('Log a set'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<WorkoutEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    message:
                        "Couldn't reach the backend.\nIs it running at localhost:8080?\n\n${snapshot.error}",
                  ),
                ],
              );
            }

            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(message: 'No sets logged yet.\nTap "Log a set" to get started.'),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return WorkoutEntryCard(entry: entry, onDelete: () => _delete(entry));
              },
            );
          },
        ),
      ),
    );
  }
}
