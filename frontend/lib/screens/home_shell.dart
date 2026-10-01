import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/reminder_scheduler.dart';
import '../services/chat_controller.dart';
import '../services/fcm_service.dart';
import '../services/goal_store.dart';
import '../services/habit_store.dart';
import '../services/inbox.dart';
import '../services/water_notifications.dart';
import '../services/motivation_reminders.dart';
import '../services/run_store.dart';
import '../models/run_record.dart' show formatDuration;
import '../services/workout_timer.dart';
import '../services/workout_log.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/movara_header.dart';
import '../widgets/workout_timer_bar.dart';
import 'account_tab.dart';
import 'feed_tab.dart';
import 'leaderboard_tab.dart';
import 'habits_screen.dart';
import 'home_tab.dart';
import 'reminders_tab.dart';
import 'running_tab.dart';
import 'upgrade_screen.dart';
import 'workout_tab.dart';

/// The bottom tabs, in order. Named so nothing addresses a tab by a raw
/// index — inserting or reordering a tab can't silently send you elsewhere.
enum MovaraTab {
  home(Icons.home_outlined, 'Home'),
  workout(Icons.fitness_center, 'Workout'),
  activity(Icons.directions_run, 'Activity'),
  habits(Icons.eco_outlined, 'Habits'),
  reminders(Icons.water_drop_outlined, 'Reminders'),
  feed(Icons.chat_bubble_outline, 'Feed'),
  account(Icons.person_outline, 'Account');

  const MovaraTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final ApiService _api =
      ApiService(tokenProvider: widget.auth.idToken);
  final _reminders = ReminderScheduler();
  final _workoutTimer = WorkoutTimer();
  final _workoutLog = WorkoutLog();
  final _habits = HabitStore();
  final _goals = GoalStore();
  late final ChatController _chat = ChatController(api: _api);
  late final RunStore _runs =
      RunStore(uploader: _api.uploadRun, downloader: _api.fetchRuns);
  late final FcmService _fcm = FcmService(_api);
  MovaraTab _tab = MovaraTab.home;

  /// The user's chosen public name, once loaded; the greeting uses it so the
  /// app shows one name everywhere.
  String? _publicName;

  // Entry list lives here, shared by Home (stats) and Workout (log), so a
  // create/delete on one tab refreshes the other.
  late Future<List<WorkoutEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _api.fetchWorkoutEntries();
    _reminders.load();
    // Restore the 6am/5pm gym notifications if they're on but missing.
    MotivationReminders(_api).ensureScheduled();
    _loadPublicName();
    _runs.load();
    _workoutTimer.load();
    _workoutLog.load();
    _habits.load();
    _goals.load();
    // Register name/photo so this user shows on the leaderboard.
    _api.upsertProfile(_displayName,
        photoUrl: widget.auth.currentUser?.photoURL);
    WidgetsBinding.instance.addObserver(this);
    _checkInbox();
    // Start FCM: request permission, obtain token, send it to backend.
    _fcm.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No push service yet: pick up admin messages whenever the app returns.
    if (state == AppLifecycleState.resumed) _checkInbox();
  }

  late final Inbox _inbox = Inbox(_api);
  bool _checkingInbox = false;

  /// Shows new messages from the Movara team as a notification and a card
  /// at the top of the screen.
  Future<void> _checkInbox() async {
    if (_checkingInbox) return;
    _checkingInbox = true;
    try {
      final messages = await _inbox.fetchNew();
      if (messages.isEmpty || !mounted) return;
      final latest = messages.last;
      // System notification (shows if the user allowed notifications).
      const WaterNotifications().show(latest.title, latest.body);
      _showInboxBanner(messages);
    } catch (_) {
      // Offline or backend asleep: try again on the next resume.
    } finally {
      _checkingInbox = false;
    }
  }

  void _showInboxBanner(List<InboxMessage> messages) {
    final c = context.movara;
    final shown = messages.reversed.take(3).toList(); // newest first
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner();
    messenger.showMaterialBanner(MaterialBanner(
      backgroundColor: c.surface,
      leading: const Text('📣', style: TextStyle(fontSize: 22)),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in shown) ...[
            Text(m.title,
                style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(m.body,
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          if (messages.length > shown.length)
            Text('+${messages.length - shown.length} more',
                style: TextStyle(color: c.textMuted, fontSize: 11)),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('inbox-dismiss'),
          onPressed: messenger.hideCurrentMaterialBanner,
          child: Text('Got it', style: TextStyle(color: c.accent)),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminders.dispose();
    _runs.dispose();
    _workoutTimer.dispose();
    _workoutLog.dispose();
    _habits.dispose();
    _goals.dispose();
    _chat.dispose();
    _fcm.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _entriesFuture = _api.fetchWorkoutEntries());
    await _entriesFuture;
  }

  Future<void> _loadPublicName() async {
    try {
      final me = await _api.fetchMyProfile();
      final chosen = me.username?.trim();
      if (mounted && chosen != null && chosen.isNotEmpty) {
        setState(() => _publicName = chosen);
      }
    } catch (_) {
      // Keep the sign-in name.
    }
  }

  void _openUpgrade() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => UpgradeScreen(api: _api),
    ));
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

  void _onTab(MovaraTab tab) {
    setState(() => _tab = tab);
    // Re-fetch when opening Home so its stats reflect sets just logged on the
    // Workout tab, even if the live refresh was missed.
    if (tab == MovaraTab.home) _reload();
  }

  /// The workout stopwatch + rest timer, opened from the header button.
  void _openTimer() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        // A compact card near the top, not a full-height centered panel.
        alignment: Alignment.topCenter,
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          right: 12,
        ),
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
          body: FeedTab(controller: _chat),
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
            username: _publicName ?? _displayName,
            onUpgrade: _openUpgrade,
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
            action: _TimerButton(timer: _workoutTimer, onTap: _openTimer),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab.index,
              children: [
                HomeTab(
                  entriesFuture: _entriesFuture,
                  runStore: _runs,
                  goalStore: _goals,
                  workoutLog: _workoutLog,
                  habitStore: _habits,
                  onReload: _reload,
                ),
                WorkoutTab(
                  api: _api,
                  entriesFuture: _entriesFuture,
                  workoutTimer: _workoutTimer,
                  workoutLog: _workoutLog,
                  onReload: _reload,
                ),
                RunningTab(store: _runs),
                HabitsScreen(store: _habits, embedded: true),
                RemindersTab(scheduler: _reminders),
                LeaderboardTab(api: _api),
                AccountTab(
                  api: _api,
                  entriesFuture: _entriesFuture,
                  runStore: _runs,
                  workoutLog: _workoutLog,
                  displayName: _displayName,
                  email: widget.auth.currentUser?.email,
                  photoUrl: widget.auth.currentUser?.photoURL,
                  onSignOut: widget.auth.signOut,
                  onNameChanged: (name) => setState(() => _publicName = name),
                  onOpenUpgrade: _openUpgrade,
                  habitStore: _habits,
                  onOpenTab: _onTab,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _ChatFab(onTap: _openChat),
      bottomNavigationBar: MovaraTabBar(current: _tab, onChanged: _onTab),
    );
  }
}

/// The bottom tab bar. Public so a test can check every tab fits a phone.
class MovaraTabBar extends StatelessWidget {
  const MovaraTabBar({super.key, required this.current, required this.onChanged});

  final MovaraTab current;
  final ValueChanged<MovaraTab> onChanged;

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
          children: MovaraTab.values.map((tab) {
            final active = tab == current;
            final item = tab;
            final color = active ? c.accent : c.textMuted;

            return Expanded(
              child: InkWell(
                onTap: () => onChanged(tab),
                child: Padding(
                  // Tight horizontal padding: seven tabs share a phone width.
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
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
                      // Scales down rather than clipping "Reminders" when
                      // seven tabs share a narrow screen.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: AppTheme.display(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
