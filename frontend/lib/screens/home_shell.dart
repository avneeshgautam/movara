import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/reminder_scheduler.dart';
import '../services/run_store.dart';
import '../models/run_record.dart' show formatDuration;
import '../services/workout_timer.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/movara_header.dart';
import '../widgets/workout_timer_bar.dart';
import 'account_tab.dart';
import 'feed_tab.dart';
import 'leaderboard_tab.dart';
import 'home_tab.dart';
import 'reminders_tab.dart';
import 'running_tab.dart';
import 'workout_tab.dart';

/// App shell: sticky header, tab content, and the bottom tab bar from the
/// design (Workout / Running / Account).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.isDark,
    required this.onToggleTheme,
  });

  final AuthService auth;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ApiService _api =
      ApiService(tokenProvider: widget.auth.idToken);
  final _reminders = ReminderScheduler();
  final _workoutTimer = WorkoutTimer();
  late final RunStore _runs = RunStore(uploader: _api.uploadRun);
  int _index = 0;

  // Entry list lives here, shared by Home (stats) and Workout (log), so a
  // create/delete on one tab refreshes the other.
  late Future<List<WorkoutEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _api.fetchWorkoutEntries();
    _reminders.load();
    _runs.load();
    _workoutTimer.load();
    // Register name/photo so this user shows on the leaderboard.
    _api.upsertProfile(_displayName,
        photoUrl: widget.auth.currentUser?.photoURL);
  }

  @override
  void dispose() {
    _reminders.dispose();
    _runs.dispose();
    _workoutTimer.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _entriesFuture = _api.fetchWorkoutEntries());
    await _entriesFuture;
  }

  /// Best available name for the signed-in user.
  String get _displayName {
    final user = widget.auth.currentUser;
    final name = user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Athlete';
  }

  void _onTab(int i) {
    setState(() => _index = i);
    // Re-fetch when opening Home so its stats reflect sets just logged on the
    // Workout tab, even if the live refresh was missed.
    if (i == 0) _reload();
  }

  /// The workout stopwatch + rest timer, opened from the header button.
  void _openTimer() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: WorkoutTimerBar(stopwatch: _workoutTimer),
      ),
    );
  }

  /// The Movara assistant, opened from the floating button.
  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) {
        final c = context.movara;
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: Text('Movara Assistant',
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          body: FeedTab(api: _api),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          MovaraHeader(
            username: _displayName,
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
            action: _TimerButton(timer: _workoutTimer, onTap: _openTimer),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeTab(
                  entriesFuture: _entriesFuture,
                  runStore: _runs,
                  onReload: _reload,
                ),
                WorkoutTab(
                  api: _api,
                  entriesFuture: _entriesFuture,
                  onReload: _reload,
                ),
                RunningTab(store: _runs),
                RemindersTab(scheduler: _reminders),
                LeaderboardTab(api: _api),
                AccountTab(
                  api: _api,
                  entriesFuture: _entriesFuture,
                  displayName: _displayName,
                  email: widget.auth.currentUser?.email,
                  photoUrl: widget.auth.currentUser?.photoURL,
                  onSignOut: widget.auth.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _ChatFab(onTap: _openChat),
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
    (icon: Icons.chat_bubble_outline, label: 'Feed'),
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

/// Floating button that opens the Movara assistant, sitting above the tab bar.
class _ChatFab extends StatelessWidget {
  const _ChatFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Padding(
      // Lift it clear of the bottom tab bar.
      padding: const EdgeInsets.only(bottom: 64),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: c.accentGlow, blurRadius: 18, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Compact header control: a timer icon that shows the running workout time
/// when the stopwatch is going, and opens the full timer sheet on tap.
class _TimerButton extends StatelessWidget {
  const _TimerButton({required this.timer, required this.onTap});

  final WorkoutTimer timer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) {
        // Rest countdown takes precedence (it's time-sensitive); otherwise the
        // running stopwatch; otherwise just the icon.
        final resting = timer.isResting;
        final running = timer.isRunning;
        final active = resting || running;
        final tint = resting ? c.green : c.accent;
        final label = resting
            ? formatDuration(timer.restRemaining)
            : formatDuration(timer.elapsed);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: active ? 12 : 10),
            decoration: BoxDecoration(
              color: active ? tint.withValues(alpha: 0.15) : c.surface2,
              border: Border.all(color: active ? tint : c.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(resting ? Icons.hourglass_bottom : Icons.timer_outlined,
                    size: 18, color: active ? tint : c.textSecondary),
                if (active) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTheme.display(
                        color: tint, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
