import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_record.dart';
import '../services/health_service.dart';
import '../services/run_store.dart';
import '../services/run_tracker.dart';
import '../services/share_image.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/overlay_card.dart';
import '../widgets/route_map.dart';
import '../widgets/share_card.dart';

/// Running tab: record a run with GPS, see the route, share it as an image.
///
/// Every figure shown comes from a run actually recorded on this device —
/// there is no sample or simulated data. Runs are stored locally (see
/// [RunStore]), so history does not follow you to another device yet.
class RunningTab extends StatefulWidget {
  const RunningTab({super.key, required this.store});

  final RunStore store;

  @override
  State<RunningTab> createState() => _RunningTabState();
}

enum _Screen { feed, ready, live, summary }

class _RunningTabState extends State<RunningTab> {
  final _tracker = RunTracker();
  _Screen _screen = _Screen.feed;
  RunRecord? _finished;

  static const _healthPrefKey = 'health_connected';
  bool _healthConnected = false;
  Timer? _hrTimer;
  int? _liveHr;

  /// The activity chosen on the feed, shown on the ready screen before the
  /// GPS actually starts.
  ActivityType _pendingType = ActivityType.run;

  @override
  void initState() {
    super.initState();
    _loadHealthFlag();
  }

  @override
  void dispose() {
    _hrTimer?.cancel();
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _loadHealthFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _healthConnected = prefs.getBool(_healthPrefKey) ?? false);
    }
  }

  Future<void> _connectHealth() async {
    final granted = await HealthService.instance.requestPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_healthPrefKey, granted);
    if (!mounted) return;
    setState(() => _healthConnected = granted);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(granted
          ? 'Apple Health connected — heart rate & steps will appear.'
          : 'Health access was not granted. You can enable it in Settings › Health.'),
    ));
  }

  /// A choice on the feed opens the ready screen; it does not start GPS yet.
  void _selectActivity(ActivityType type) {
    setState(() {
      _pendingType = type;
      _screen = _Screen.ready;
    });
  }

  /// The Start button on the ready screen actually begins recording.
  Future<void> _beginRecording() async {
    setState(() {
      _screen = _Screen.live;
      _liveHr = null;
    });
    await _tracker.start(type: _pendingType);
    // Poll Apple Health for the latest heart rate while recording.
    if (_healthConnected && HealthService.instance.isSupported) {
      _hrTimer?.cancel();
      _hrTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
        final hr = await HealthService.instance.latestHeartRate();
        if (mounted) setState(() => _liveHr = hr);
      });
    }
  }

  void _finishRun() {
    _hrTimer?.cancel();
    final run = _tracker.finish();
    if (run == null) {
      setState(() => _screen = _Screen.feed);
      return;
    }
    setState(() {
      _finished = run;
      _screen = _Screen.summary;
    });
  }

  void _discardRun() {
    _hrTimer?.cancel();
    _tracker.discard();
    setState(() {
      _finished = null;
      _liveHr = null;
      _screen = _Screen.feed;
    });
  }

  Future<void> _saveRun(RunRecord run) async {
    await widget.store.add(run);
    if (!mounted) return;
    setState(() {
      _finished = null;
      _screen = _Screen.feed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      color: c.bg,
      child: switch (_screen) {
        _Screen.feed => _Feed(
            store: widget.store,
            onRecord: _selectActivity,
            healthConnected: _healthConnected,
            onConnectHealth: _connectHealth,
          ),
        _Screen.ready => _ReadyScreen(
            type: _pendingType,
            onStart: _beginRecording,
            onCancel: () => setState(() => _screen = _Screen.feed),
          ),
        _Screen.live => _LiveTracker(
            tracker: _tracker,
            heartRate: _liveHr,
            onFinish: _finishRun,
            onDiscard: _discardRun,
          ),
        _Screen.summary => _Summary(
            run: _finished!,
            onSave: () => _saveRun(_finished!),
            onDiscard: _discardRun,
          ),
      },
    );
  }
}

// ── Feed ────────────────────────────────────────────────────────────

class _Feed extends StatelessWidget {
  const _Feed({
    required this.store,
    required this.onRecord,
    required this.healthConnected,
    required this.onConnectHealth,
  });

  final RunStore store;
  final void Function(ActivityType) onRecord;
  final bool healthConnected;
  final VoidCallback onConnectHealth;

  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static String _activityBlurb(ActivityType type) => switch (type) {
        ActivityType.run => 'Pace · calories',
        ActivityType.walk => 'Steps · calories',
        ActivityType.hike => 'Elevation · calories',
      };

  /// The three activity choices, shown inline on the feed. Tapping one opens
  /// the ready screen (it does not start recording yet).
  Widget _activityChooser(BuildContext context) {
    final c = context.movara;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECORD ACTIVITY',
            style: TextStyle(
                color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final type in ActivityType.values) ...[
              if (type != ActivityType.values.first)
                const SizedBox(width: 10),
              Expanded(child: _activityCard(context, type)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _activityCard(BuildContext context, ActivityType type) {
    final c = context.movara;
    return GestureDetector(
      onTap: () => onRecord(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFC2410C), c.accent],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: c.accentGlow, blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(type.label,
                style: AppTheme.display(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_activityBlurb(type),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final runs = store.runs;
        final weekKm = store.kmByWeekday();
        final maxKm = weekKm.fold<double>(1, (m, v) => v > m ? v : m);
        final todayIndex = DateTime.now().weekday - 1;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('ACTIVITY FEED',
                style: TextStyle(
                    color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Activity',
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),

            _activityChooser(context),
            if (HealthService.instance.isSupported) ...[
              const SizedBox(height: 12),
              _healthButton(context),
            ],
            const SizedBox(height: 20),

            // Weekly totals, from real runs.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('THIS WEEK',
                              style: TextStyle(
                                  color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
                          RichText(
                            text: TextSpan(
                              text: store.totalKmThisWeek().toStringAsFixed(1),
                              style: AppTheme.display(
                                  color: c.accent, fontSize: 24, fontWeight: FontWeight.w800),
                              children: [
                                TextSpan(
                                  text: ' km',
                                  style: TextStyle(color: c.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('ACTIVITIES',
                              style: TextStyle(
                                  color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
                          Text('${store.runsThisWeek()}',
                              style: AppTheme.display(
                                  color: c.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: c.surface3,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        widthFactor: 1,
                                        heightFactor: weekKm[i] == 0
                                            ? 0.06
                                            : (weekKm[i] / maxKm).clamp(0.15, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: weekKm[i] == 0
                                                ? c.border
                                                : (i == todayIndex
                                                    ? c.accent
                                                    : c.accent.withValues(alpha: 0.4)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(_weekDays[i],
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: i == todayIndex ? c.accent : c.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (runs.isNotEmpty) ...[
              Text('YOUR BESTS',
                  style: AppTheme.display(
                      color: c.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _best(context, '📏', 'Longest',
                      '${(store.longestRun?.distanceKm ?? 0).toStringAsFixed(2)} km'),
                  const SizedBox(width: 10),
                  _best(context, '⚡', 'Best pace',
                      formatPace(store.fastestPace?.paceSecondsPerKm ?? 0)),
                  const SizedBox(width: 10),
                  _best(context, '⏱️', 'Longest time',
                      formatDuration(store.longestDuration?.elapsed ?? Duration.zero)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            Text('YOUR ACTIVITIES',
                style: AppTheme.display(
                    color: c.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8)),
            const SizedBox(height: 12),
            if (runs.isEmpty)
              _emptyState(context)
            else
              for (final run in runs) ...[
                _RunCard(run: run, onDelete: () => store.remove(run.id)),
                const SizedBox(height: 14),
              ],
          ],
        );
      },
    );
  }

  Widget _healthButton(BuildContext context) {
    final c = context.movara;
    final connected = healthConnected;
    return GestureDetector(
      onTap: connected ? null : onConnectHealth,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(
              color: connected ? c.green.withValues(alpha: 0.5) : c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(connected ? Icons.favorite : Icons.watch_outlined,
                size: 18, color: connected ? c.green : c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(connected ? 'Apple Health connected' : 'Connect Apple Watch',
                      style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(
                      connected
                          ? 'Heart rate & real steps from Health'
                          : 'Pull heart rate & steps from Apple Health',
                      style: TextStyle(color: c.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (!connected)
              Icon(Icons.chevron_right, size: 18, color: c.textMuted)
            else
              Icon(Icons.check_circle, size: 18, color: c.green),
          ],
        ),
      ),
    );
  }

  Widget _best(BuildContext context, String icon, String label, String value) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(
                    color: c.accent, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text('🏃', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 12),
          Text('No activities yet',
              style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Tap Record Activity, pick Run, Walk or Hike, and your route '
              'will be mapped as you go.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Saved run card ──────────────────────────────────────────────────

class _RunCard extends StatefulWidget {
  const _RunCard({required this.run, required this.onDelete});

  final RunRecord run;
  final VoidCallback onDelete;

  @override
  State<_RunCard> createState() => _RunCardState();
}

class _RunCardState extends State<_RunCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final run = widget.run;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                      child: Text(run.activityType.emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title(run.startedAt, run.activityType),
                              style: AppTheme.display(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(DateFormat('E d MMM · h:mm a').format(run.startedAt),
                              style: TextStyle(color: c.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: c.textMuted,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat(context, 'DISTANCE', '${run.distanceKm.toStringAsFixed(2)} km'),
                    const SizedBox(width: 8),
                    if (run.activityType == ActivityType.hike)
                      _stat(context, 'ELEV GAIN',
                          '${run.elevationGainMeters.round()} m')
                    else if (run.activityType == ActivityType.walk)
                      _stat(context, 'STEPS', formatSteps(run.estimatedSteps))
                    else
                      _stat(context, 'PACE', '${formatPace(run.paceSecondsPerKm)}/km'),
                    const SizedBox(width: 8),
                    _stat(context, 'TIME', formatDuration(run.elapsed)),
                  ],
                ),
                if (run.route.length > 1) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_expanded ? '▲ Hide route' : '▼ Show route',
                          style: AppTheme.display(
                              color: c.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded && run.route.length > 1)
            SizedBox(
              height: 200,
              child: RouteMap(route: run.route, interactive: false),
            ),
        ],
      ),
    );
  }

  /// Activities are named by time of day and type, the way most trackers do.
  String _title(DateTime at, ActivityType type) {
    final h = at.hour;
    final part = h < 12
        ? 'Morning'
        : h < 17
            ? 'Afternoon'
            : h < 21
                ? 'Evening'
                : 'Night';
    return '$part ${type.label}';
  }

  Widget _stat(BuildContext context, String label, String value) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ── Ready screen ────────────────────────────────────────────────────

/// Shown after choosing an activity: confirms the pick and waits for a Start
/// tap before any GPS tracking begins.
class _ReadyScreen extends StatelessWidget {
  const _ReadyScreen({
    required this.type,
    required this.onStart,
    required this.onCancel,
  });

  final ActivityType type;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  String get _blurb => switch (type) {
        ActivityType.run => 'Maps your route and tracks pace, time and calories.',
        ActivityType.walk => 'Maps your route and tracks steps, time and calories.',
        ActivityType.hike =>
          'Maps your route and tracks elevation gain, time and calories.',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back to the chooser.
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: c.textMuted, size: 20),
                      Text('Change',
                          style: TextStyle(color: c.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(type.emoji, style: const TextStyle(fontSize: 46)),
                  ),
                  const SizedBox(height: 18),
                  Text('READY TO GO',
                      style: TextStyle(
                          color: c.textMuted, fontSize: 10, letterSpacing: 1.8)),
                  const SizedBox(height: 4),
                  Text(type.label,
                      style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_blurb,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 13, height: 1.4)),
                  ),
                ],
              ),
            ),
            // Start button.
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFC2410C), c.accent],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: c.accentGlow,
                        blurRadius: 22,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text('Start ${type.label}',
                        style: AppTheme.display(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Location starts when you tap Start.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Live tracking ───────────────────────────────────────────────────

class _LiveTracker extends StatelessWidget {
  const _LiveTracker({
    required this.tracker,
    required this.heartRate,
    required this.onFinish,
    required this.onDiscard,
  });

  final RunTracker tracker;

  /// Latest heart rate from Apple Health, or null when not connected.
  final int? heartRate;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  RouteMap(
                    route: tracker.route,
                    live: tracker.current,
                    followLive: true,
                  ),
                  if (_banner(context, tracker) case final banner?)
                    Positioned(top: 12, left: 12, right: 12, child: banner),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: tracker.isPaused ? c.textMuted : c.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${tracker.activityType.label.toUpperCase()} · '
                              '${tracker.isPaused ? 'PAUSED' : 'RECORDING'}',
                              style: AppTheme.display(
                                color: tracker.isPaused ? c.textMuted : c.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              )),
                        ],
                      ),
                  Row(
                        children: [
                          if (heartRate != null) ...[
                            Icon(Icons.favorite, size: 15, color: c.accent),
                            const SizedBox(width: 4),
                            Text('$heartRate',
                                style: AppTheme.display(
                                    color: c.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            Text(' bpm',
                                style: TextStyle(color: c.textMuted, fontSize: 10)),
                            const SizedBox(width: 12),
                          ],
                          Text(formatDuration(tracker.elapsed),
                              style: AppTheme.display(
                                  color: c.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _liveStat(context, 'DISTANCE',
                          tracker.distanceKm.toStringAsFixed(2), 'km'),
                      const SizedBox(width: 8),
                      _liveStat(context, 'PACE',
                          formatPace(tracker.paceSecondsPerKm), '/km'),
                      const SizedBox(width: 8),
                      if (tracker.activityType == ActivityType.hike)
                        _liveStat(context, 'ELEV',
                            '${tracker.elevationGainMeters.round()}', 'm ↑')
                      else if (tracker.activityType == ActivityType.walk)
                        _liveStat(context, 'STEPS',
                            formatSteps(tracker.estimatedSteps), 'est.')
                      else
                        _liveStat(
                            context, 'CAL', '${tracker.estimatedCalories}', 'est.'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: tracker.isPaused ? tracker.resume : tracker.pause,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tracker.isPaused ? c.greenSoft : c.surface2,
                              border: Border.all(
                                  color: tracker.isPaused ? c.green : c.border),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(tracker.isPaused ? '▶ Resume' : '⏸ Pause',
                                style: AppTheme.display(
                                    color: tracker.isPaused ? c.green : c.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: onFinish,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('■ Finish',
                                style: AppTheme.display(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDiscard,
                    child: Text('Discard',
                        style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// What to tell the user about the signal, or null when all is well.
  Widget? _banner(BuildContext context, RunTracker tracker) {
    if (tracker.error != null) {
      return _bannerBox(context, tracker.error!, isError: true);
    }
    if (tracker.hasWeakSignal) {
      final metres = tracker.accuracyMetres!.round();
      return _bannerBox(
        context,
        'Weak signal — your position is only accurate to about $metres m, '
        'which is too vague to map. Head outside for a proper fix.',
        isError: true,
      );
    }
    if (tracker.current == null) {
      return _bannerBox(context, 'Acquiring GPS…');
    }
    if (tracker.route.length < 2) {
      return _bannerBox(context,
          'Locked on. The route starts drawing once you begin moving.');
    }
    return null;
  }

  Widget _bannerBox(BuildContext context, String text, {bool isError = false}) {
    final c = context.movara;
    final colour = isError ? const Color(0xFFEF4444) : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.92),
        border: Border.all(color: isError ? colour : c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.gps_off : Icons.gps_not_fixed, size: 14, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colour, fontSize: 11, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _liveStat(
      BuildContext context, String label, String value, String unit) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: c.textMuted, fontSize: 8, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(value,
                style: AppTheme.display(
                    color: c.accent, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(unit, style: TextStyle(color: c.textMuted, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}

// ── Summary + share ─────────────────────────────────────────────────

class _Summary extends StatefulWidget {
  const _Summary({
    required this.run,
    required this.onSave,
    required this.onDiscard,
  });

  final RunRecord run;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  int? _avgHr;
  int? _realSteps;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  /// Pulls the average heart rate and real step count for this activity's
  /// time window from Apple Health, when connected.
  Future<void> _loadHealth() async {
    if (!HealthService.instance.isSupported) return;
    final run = widget.run;
    final start = run.startedAt;
    final end = run.startedAt.add(run.elapsed);
    final hr = await HealthService.instance.averageHeartRate(start, end);
    final steps = await HealthService.instance.steps(start, end);
    if (!mounted) return;
    setState(() {
      _avgHr = hr;
      _realSteps = steps;
    });
  }

  /// Shows the card the user is about to share, then saves it. Rendering it
  /// on screen (rather than offscreen) also gives the map tiles time to load,
  /// so the saved image is never a half-drawn map.
  void _share() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _SharePreview(run: widget.run),
    );
  }

  void _overlay() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _OverlayPreview(run: widget.run),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final run = widget.run;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('✓ ${run.activityType.label.toUpperCase()} COMPLETE',
                style: AppTheme.display(
                    color: c.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6)),
            const SizedBox(height: 2),
            Text('Activity Summary',
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 220,
                child: run.route.isNotEmpty
                    ? RouteMap(route: run.route, interactive: false)
                    : _noRoute(context),
              ),
            ),
            if (run.route.length == 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: c.textMuted),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'GPS found you, but you did not move far enough to '
                        'draw a route.',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _card(context, '📍', 'Distance',
                    '${run.distanceKm.toStringAsFixed(2)} km'),
                const SizedBox(width: 12),
                _card(context, '⏱️', 'Time', formatDuration(run.elapsed)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (run.activityType == ActivityType.walk)
                  _card(context, '👣', 'Steps',
                      _realSteps != null
                          ? formatSteps(_realSteps!)
                          : '~${formatSteps(run.estimatedSteps)}')
                else
                  _card(context, '⚡', 'Avg pace',
                      '${formatPace(run.paceSecondsPerKm)} /km'),
                const SizedBox(width: 12),
                _card(context, '🔥', 'Calories', '~${run.estimatedCalories} kcal'),
              ],
            ),
            if (_avgHr != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _card(context, '❤️', 'Avg heart rate', '$_avgHr bpm'),
                ],
              ),
            ],
            if (run.activityType == ActivityType.hike) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _card(context, '⛰️', 'Elev gain',
                      '${run.elevationGainMeters.round()} m'),
                  const SizedBox(width: 12),
                  _card(context, '🏔️', 'Max altitude',
                      run.maxAltitude != null
                          ? '${run.maxAltitude!.round()} m'
                          : '--'),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _primaryButton(context, 'Save Activity', widget.onSave),
            const SizedBox(height: 10),
            _secondaryButton(context, 'Share as image', _share),
            const SizedBox(height: 10),
            _secondaryButton(context, 'Story overlay (transparent)', _overlay),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: widget.onDiscard,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Discard',
                      style: AppTheme.display(
                          color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noRoute(BuildContext context) {
    final c = context.movara;
    return Container(
      color: c.surface2,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 26, color: c.textMuted),
          const SizedBox(height: 8),
          Text('No position recorded',
              style: AppTheme.display(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Location was never available. Check the browser allowed it, '
              'and that you are outdoors or near a window.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String icon, String label, String value) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(label.toUpperCase(),
                    style: TextStyle(
                        color: c.textMuted, fontSize: 9, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 5),
            Text(value,
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(BuildContext context, String label, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: c.accentGlow, blurRadius: 20, offset: const Offset(0, 6))
          ],
        ),
        child: Text(label,
            style: AppTheme.display(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _secondaryButton(
      BuildContext context, String label, VoidCallback? onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(color: c.accent.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ios_share, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTheme.display(
                      color: c.accent, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Strava-style share sheet: the card as it will be saved, plus the button
/// that writes the PNG.
class _SharePreview extends StatefulWidget {
  const _SharePreview({required this.run});

  final RunRecord run;

  @override
  State<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<_SharePreview> {
  final _cardKey = GlobalKey();
  bool _saving = false;
  String? _error;

  String get _fileName =>
      'movara-run-${DateFormat('yyyy-MM-dd').format(widget.run.startedAt)}.png';

  Future<void> _run(Future<bool> Function(Uint8List, String) action,
      {required String okMessage, required String failMessage}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await captureShareCard(_cardKey);
      if (bytes == null) throw StateError('nothing to capture');

      final ok = await action(bytes, _fileName);
      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(okMessage)));
      } else {
        setState(() => _error = failMessage);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the image.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveToPhotos() => _run(
        (b, n) => const ShareImage().saveToPhotos(b, n),
        okMessage: 'Saved to Photos',
        failMessage: 'Could not save to Photos. Allow photo access in Settings.',
      );

  Future<void> _share() => _run(
        (b, n) => const ShareImage().save(b, n),
        okMessage: 'Shared',
        failMessage: 'Sharing is not available here.',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ShareCard(run: widget.run, boundaryKey: _cardKey),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: ShareCard.width,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _saving ? null : _saveToPhotos,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(_saving ? 'Saving…' : 'Save to Photos',
                              style: AppTheme.display(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('Close',
                                style: AppTheme.display(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _saving ? null : _share,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.ios_share,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('Share',
                                    style: AppTheme.display(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview + save for the transparent Strava-style overlay. Lets the user drop
/// a photo behind the stats, then saves the result (transparent PNG when no
/// photo) to their library.
class _OverlayPreview extends StatefulWidget {
  const _OverlayPreview({required this.run});

  final RunRecord run;

  @override
  State<_OverlayPreview> createState() => _OverlayPreviewState();
}

class _OverlayPreviewState extends State<_OverlayPreview> {
  final _cardKey = GlobalKey();
  Uint8List? _photo;
  bool _busy = false;
  String? _error;

  /// The map/route colour the user can pick, remembered across sessions.
  static const _colorPrefKey = 'overlay_route_color';
  static const _routeColors = <(String, Color)>[
    ('Orange', Color(0xFFF97316)),
    ('Yellow', Color(0xFFFACC15)),
    ('Green', Color(0xFF22C55E)),
    ('Blue', Color(0xFF3B82F6)),
    ('White', Color(0xFFFFFFFF)),
    ('Black', Color(0xFF111827)),
  ];
  Color _routeColor = const Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _loadColor();
  }

  Future<void> _loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_colorPrefKey);
    if (v != null && mounted) setState(() => _routeColor = Color(v));
  }

  Future<void> _setColor(Color color) async {
    setState(() => _routeColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorPrefKey, color.toARGB32());
  }

  Widget _colorPicker() {
    return SizedBox(
      width: OverlayCard.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MAP COLOUR',
              style: TextStyle(
                  color: Colors.white70, fontSize: 10, letterSpacing: 1.4)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (name, color) in _routeColors)
                GestureDetector(
                  onTap: () => _setColor(color),
                  child: Semantics(
                    label: name,
                    selected: color.toARGB32() == _routeColor.toARGB32(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() == _routeColor.toARGB32()
                              ? Colors.white
                              : Colors.white24,
                          width: color.toARGB32() == _routeColor.toARGB32()
                              ? 2.5
                              : 1,
                        ),
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.15)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: source, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = source == ImageSource.camera
            ? 'Could not open the camera. Allow camera access in Settings.'
            : 'Could not open that photo.');
      }
    }
  }

  /// Lets the user take a new photo or pick an existing one.
  Future<void> _choosePhotoSource() async {
    final c = context.movara;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: c.accent),
              title: Text('Take photo',
                  style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.accent),
              title: Text('Choose from gallery',
                  style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  String get _fileName =>
      'movara-overlay-${DateFormat('yyyy-MM-dd').format(widget.run.startedAt)}.png';

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Let the card (and any photo) settle before rasterising.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final bytes = await captureOverlay(_cardKey);
      if (bytes == null) throw StateError('nothing to capture');

      final ok = await const ShareImage().saveToPhotos(bytes, _fileName);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Photos')));
      } else {
        setState(() =>
            _error = 'Could not save to Photos. Allow photo access in Settings.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final bytes = await captureOverlay(_cardKey);
      if (bytes == null) throw StateError('nothing to capture');
      await const ShareImage().save(bytes, _fileName);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A checkerboard sits behind the card so the transparent areas are
            // obvious in the preview (it is not part of the saved image).
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _photo == null ? _CheckerPainter() : null,
                child: OverlayCard(
                  run: widget.run,
                  boundaryKey: _cardKey,
                  photo: _photo,
                  accent: _routeColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _colorPicker(),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: OverlayCard.width,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _pill(
                          icon: Icons.image_outlined,
                          label: _photo == null ? 'Add photo' : 'Change photo',
                          onTap: _busy ? null : _choosePhotoSource,
                        ),
                      ),
                      if (_photo != null) ...[
                        const SizedBox(width: 10),
                        _pill(
                          icon: Icons.close,
                          label: 'Remove',
                          onTap: _busy ? null : () => setState(() => _photo = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _busy ? null : _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(_busy ? 'Saving…' : 'Save to Photos',
                              style: AppTheme.display(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _pill(
                          label: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pill(
                          icon: Icons.ios_share,
                          label: 'Share',
                          onTap: _busy ? null : _share,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({IconData? icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: AppTheme.display(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey checkerboard, the usual "this is transparent" backdrop. Preview only.
class _CheckerPainter extends CustomPainter {
  static const _cell = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A2A2A));
    for (var y = 0.0; y < size.height; y += _cell) {
      for (var x = 0.0; x < size.width; x += _cell) {
        if (((x ~/ _cell) + (y ~/ _cell)) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, _cell, _cell), light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
