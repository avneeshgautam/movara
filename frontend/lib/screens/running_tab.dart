import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/run_record.dart';
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

enum _Screen { feed, live, summary }

class _RunningTabState extends State<RunningTab> {
  final _tracker = RunTracker();
  _Screen _screen = _Screen.feed;
  RunRecord? _finished;

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _startRun() async {
    setState(() => _screen = _Screen.live);
    await _tracker.start();
  }

  void _finishRun() {
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
    _tracker.discard();
    setState(() {
      _finished = null;
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
        _Screen.feed => _Feed(store: widget.store, onRecord: _startRun),
        _Screen.live => _LiveTracker(
            tracker: _tracker,
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
  const _Feed({required this.store, required this.onRecord});

  final RunStore store;
  final VoidCallback onRecord;

  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
            Text('Running',
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),

            _recordButton(context),
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
                          Text('RUNS',
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

            Text('YOUR RUNS',
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

  Widget _recordButton(BuildContext context) {
    final c = context.movara;
    return GestureDetector(
      onTap: onRecord,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFC2410C), c.accent],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: c.accentGlow, blurRadius: 24, offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏃', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Record Activity',
                    style: AppTheme.display(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('GPS · Live route · Share as image',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
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
          Text('No runs yet',
              style: AppTheme.display(color: c.textPrimary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Tap Record Activity and your route will be mapped as you go.',
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
                      child: const Text('🏃', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title(run.startedAt),
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

  /// Runs are named by time of day, the way most trackers do it.
  String _title(DateTime at) {
    final h = at.hour;
    if (h < 12) return 'Morning Run';
    if (h < 17) return 'Afternoon Run';
    if (h < 21) return 'Evening Run';
    return 'Night Run';
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

// ── Live tracking ───────────────────────────────────────────────────

class _LiveTracker extends StatelessWidget {
  const _LiveTracker({
    required this.tracker,
    required this.onFinish,
    required this.onDiscard,
  });

  final RunTracker tracker;
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
                          Text(tracker.isPaused ? 'PAUSED' : 'RECORDING',
                              style: AppTheme.display(
                                color: tracker.isPaused ? c.textMuted : c.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              )),
                        ],
                      ),
                      Text(formatDuration(tracker.elapsed),
                          style: AppTheme.display(
                              color: c.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
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
                      _liveStat(context, 'CAL', '${tracker.estimatedCalories}', 'est.'),
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
            Text('✓ RUN COMPLETE',
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
                _card(context, '⚡', 'Avg pace',
                    '${formatPace(run.paceSecondsPerKm)} /km'),
                const SizedBox(width: 12),
                _card(context, '🔥', 'Calories', '~${run.estimatedCalories} kcal'),
              ],
            ),
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
                  accent: c.blue,
                ),
              ),
            ),
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
