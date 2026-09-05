import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Running tab, ported from the React `RunningPage` design.
///
/// Map rendering is deliberately left out for now (Google Maps comes later);
/// every place a map belongs shows a labelled placeholder. The activity feed,
/// weekly chart and personal bests use the design's sample data. The live
/// recorder's timer and controls are real; GPS-derived figures wait on the
/// mapping work.
class RunningTab extends StatefulWidget {
  const RunningTab({super.key});

  @override
  State<RunningTab> createState() => _RunningTabState();
}

enum _Screen { feed, live, summary }

class _RunningTabState extends State<RunningTab> {
  _Screen _screen = _Screen.feed;
  Duration _lastElapsed = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      color: c.bg,
      child: switch (_screen) {
        _Screen.feed => _Feed(onRecord: () => setState(() => _screen = _Screen.live)),
        _Screen.live => _LiveTracker(
            onFinish: (elapsed) => setState(() {
              _lastElapsed = elapsed;
              _screen = _Screen.summary;
            }),
            onCancel: () => setState(() => _screen = _Screen.feed),
          ),
        _Screen.summary => _Summary(
            elapsed: _lastElapsed,
            onDone: () => setState(() => _screen = _Screen.feed),
          ),
      },
    );
  }
}

// ── Placeholder standing in for the map ─────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.height, this.label});

  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 26, color: c.textMuted),
          const SizedBox(height: 8),
          Text(
            label ?? 'Route map',
            style: AppTheme.display(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Google Maps integration coming next',
            style: TextStyle(color: c.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Feed ────────────────────────────────────────────────────────────

class _Feed extends StatelessWidget {
  const _Feed({required this.onRecord});

  final VoidCallback onRecord;

  // Sample data carried over from the design.
  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekKm = [5.2, 0.0, 8.1, 0.0, 4.7, 12.3, 0.0];

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final totalKm = _weekKm.fold<double>(0, (a, b) => a + b);
    final runs = _weekKm.where((k) => k > 0).length;
    final maxKm = _weekKm.fold<double>(1, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('ACTIVITY FEED',
            style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Running',
                style: AppTheme.display(
                    color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('🔍 Explore',
                  style: AppTheme.display(
                      color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Record button.
        GestureDetector(
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
              boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: 24, offset: const Offset(0, 6))],
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
                    const Text('Live timer · Route map coming soon',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Weekly summary.
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
                          text: totalKm.toStringAsFixed(1),
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
                      Text('$runs',
                          style: AppTheme.display(
                              color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
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
                                    heightFactor: _weekKm[i] == 0
                                        ? 0.08
                                        : (_weekKm[i] / maxKm).clamp(0.15, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _weekKm[i] == 0
                                            ? c.border
                                            : (i == 0
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
                                    color: i == 0 ? c.accent : c.textMuted)),
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

        // Personal bests.
        Text('PERSONAL BESTS',
            style: AppTheme.display(
                color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _Best(icon: '⚡', label: '1K', value: '4:22'),
              _Best(icon: '🏃', label: '5K', value: '22:14'),
              _Best(icon: '🎯', label: '10K', value: '46:58'),
              _Best(icon: '🏅', label: 'Half', value: '1:48:32'),
              _Best(icon: '🏆', label: 'Marathon', value: '—'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT ACTIVITIES',
                style: AppTheme.display(
                    color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
            Text('All →',
                style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        for (final a in _sampleActivities) ...[
          _ActivityCard(activity: a),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _Best extends StatelessWidget {
  const _Best({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      width: 78,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTheme.display(
                  color: c.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTheme.display(
                color: value == '—' ? c.textMuted : c.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// ── Activity feed data + card ───────────────────────────────────────

class _Activity {
  const _Activity({
    required this.name,
    required this.date,
    required this.km,
    required this.pace,
    required this.time,
    required this.cal,
    required this.type,
    required this.hr,
  });

  final String name;
  final String date;
  final double km;
  final String pace;
  final String time;
  final int cal;
  final String type;
  final int hr;
}

const _sampleActivities = [
  _Activity(
      name: 'Morning Run', date: 'Today · 6:30 AM', km: 5.2, pace: '5:12',
      time: '27:02', cal: 380, type: 'Easy Run', hr: 142),
  _Activity(
      name: 'Long Run', date: 'Sat · 7:00 AM', km: 12.3, pace: '5:45',
      time: '1:10:43', cal: 890, type: 'Long Run', hr: 155),
  _Activity(
      name: 'Interval Training', date: 'Wed · 6:00 AM', km: 8.1, pace: '4:50',
      time: '39:11', cal: 620, type: 'Workout', hr: 168),
];

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.activity});

  final _Activity activity;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = false;

  (Color, Color) _typeColours(BuildContext context) {
    final c = context.movara;
    return switch (widget.activity.type) {
      'Easy Run' => (c.green, c.greenSoft),
      'Long Run' => (c.blue, c.blueSoft),
      _ => (c.accent, c.accentSoft),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final a = widget.activity;
    final (typeColour, typeBg) = _typeColours(context);

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
                      decoration: BoxDecoration(color: typeBg, shape: BoxShape.circle),
                      child: const Text('🏃', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: AppTheme.display(
                                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(a.date, style: TextStyle(color: c.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeBg,
                        border: Border.all(color: typeColour.withValues(alpha: 0.27)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(a.type,
                          style: AppTheme.display(
                              color: typeColour, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat(context, 'DISTANCE', '${a.km} km'),
                    const SizedBox(width: 8),
                    _miniStat(context, 'PACE', '${a.pace}/km'),
                    const SizedBox(width: 8),
                    _miniStat(context, 'TIME', a.time),
                  ],
                ),
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
                    child: Text(_expanded ? '▲ Hide map' : '▼ Show map',
                        style: AppTheme.display(
                            color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _MapPlaceholder(height: 150),
            ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(
              children: [
                _footerAction(context, '❤️', '${a.hr} bpm'),
                _footerAction(context, '🔥', '${a.cal} kcal'),
                _footerAction(context, '📤', 'Share'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
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

  Widget _footerAction(BuildContext context, String icon, String label) {
    final c = context.movara;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(label,
                style: AppTheme.display(
                    color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Live tracker ────────────────────────────────────────────────────

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _LiveTracker extends StatefulWidget {
  const _LiveTracker({required this.onFinish, required this.onCancel});

  final void Function(Duration elapsed) onFinish;
  final VoidCallback onCancel;

  @override
  State<_LiveTracker> createState() => _LiveTrackerState();
}

class _LiveTrackerState extends State<_LiveTracker> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Column(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _MapPlaceholder(
              height: double.infinity,
              label: 'Live route',
            ),
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
                          color: _paused ? c.textMuted : c.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_paused ? 'PAUSED' : 'RECORDING',
                          style: AppTheme.display(
                            color: _paused ? c.textMuted : c.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          )),
                    ],
                  ),
                  Text(formatDuration(_elapsed),
                      style: AppTheme.display(
                          color: c.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _liveStat(context, 'DISTANCE', '--', 'km'),
                  const SizedBox(width: 8),
                  _liveStat(context, 'PACE', '--:--', '/km'),
                  const SizedBox(width: 8),
                  _liveStat(context, 'HR', '--', 'bpm'),
                  const SizedBox(width: 8),
                  _liveStat(context, 'CAL', '--', 'kcal'),
                ],
              ),
              const SizedBox(height: 8),
              Text('Distance and pace arrive with GPS + map support',
                  style: TextStyle(color: c.textMuted, fontSize: 10)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paused = !_paused),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _paused ? c.greenSoft : c.surface2,
                          border: Border.all(color: _paused ? c.green : c.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_paused ? '▶ Resume' : '⏸ Pause',
                            style: AppTheme.display(
                                color: _paused ? c.green : c.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onFinish(_elapsed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('■ Finish',
                            style: AppTheme.display(
                                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onCancel,
                child: Text('Discard',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _liveStat(BuildContext context, String label, String value, String unit) {
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

// ── Summary ─────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.elapsed, required this.onDone});

  final Duration elapsed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    final stats = <(String, String, String)>[
      ('📍', 'Distance', '-- km'),
      ('⏱️', 'Duration', formatDuration(elapsed)),
      ('⚡', 'Avg Pace', '--:-- /km'),
      ('🔥', 'Calories', '-- kcal'),
      ('❤️', 'Avg HR', '-- bpm'),
      ('🏅', 'Points', '+${elapsed.inMinutes}'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('✓ RUN COMPLETE!',
            style: AppTheme.display(
                color: c.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
        const SizedBox(height: 2),
        Text('Activity Summary',
            style: AppTheme.display(
                color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const _MapPlaceholder(height: 160, label: 'Your route'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            for (final (icon, label, value) in stats)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
          ],
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onDone,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Text('Save & Share Activity',
                style: AppTheme.display(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: onDone,
            child: Text('Discard',
                style: AppTheme.display(
                    color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
