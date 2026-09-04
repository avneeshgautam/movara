import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../services/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/movara_header.dart';
import 'account_tab.dart';
import 'home_tab.dart';
import 'reminders_tab.dart';
import 'workout_tab.dart';

/// App shell: sticky header, tab content, and the bottom tab bar from the
/// design (Workout / Running / Account).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _api = ApiService();
  final _reminders = ReminderScheduler();
  int _index = 0;

  // Entry list lives here, shared by Home (stats) and Workout (log), so a
  // create/delete on one tab refreshes the other.
  late Future<List<WorkoutEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _api.fetchWorkoutEntries();
    _reminders.load();
  }

  @override
  void dispose() {
    _reminders.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _entriesFuture = _api.fetchWorkoutEntries());
    await _entriesFuture;
  }

  void _onTab(int i) {
    setState(() => _index = i);
    // Re-fetch when opening Home so its stats reflect sets just logged on the
    // Workout tab, even if the live refresh was missed.
    if (i == 0) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          MovaraHeader(
            // TODO: replace with the signed-in user once auth exists.
            username: 'Avneesh',
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeTab(entriesFuture: _entriesFuture, onReload: _reload),
                WorkoutTab(
                  api: _api,
                  entriesFuture: _entriesFuture,
                  onReload: _reload,
                ),
                const _ComingSoon(
                  emoji: '🏃',
                  title: 'Running',
                  message: 'Route tracking and pace history will live here.',
                ),
                RemindersTab(scheduler: _reminders),
                AccountTab(entriesFuture: _entriesFuture),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _TabBar(
        index: _index,
        onChanged: _onTab,
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.fitness_center, label: 'Workout'),
    (icon: Icons.directions_run, label: 'Running'),
    (icon: Icons.water_drop_outlined, label: 'Reminders'),
    (icon: Icons.person_outline, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == index;
            final item = _items[i];
            final color = active ? c.accent : c.textMuted;

            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active tab gets the small accent dot from the design.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.icon, size: 22, color: color),
                          if (active)
                            Positioned(
                              top: -2,
                              right: -3,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTheme.display(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.emoji,
    required this.title,
    required this.message,
  });

  final String emoji;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.display(color: c.textPrimary, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
