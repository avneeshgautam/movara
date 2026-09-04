import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_entry.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Profile / account screen, ported from the React `AccountPage` design.
///
/// Workout counts and personal records are derived from real logged entries.
/// Body stats, goals, badges and the settings menu are still local/placeholder
/// state — there is no data source for them yet (see the TODOs).
class AccountTab extends StatefulWidget {
  const AccountTab({
    super.key,
    required this.entriesFuture,
    this.displayName = 'Athlete',
    this.email,
    this.photoUrl,
    this.onSignOut,
  });

  final Future<List<WorkoutEntry>> entriesFuture;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final Future<void> Function()? onSignOut;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String get _name => widget.displayName;
  String get _handle => widget.email ?? 'Signed in';

  // Local-only for now; nothing persists these yet.
  final Map<String, double> _body = {
    'Weight': 74.5,
    'Height': 178,
    'Body Fat': 16,
    'Muscle Mass': 58.2,
    'Resting HR': 62,
  };

  final Map<String, bool> _toggles = {
    'Notifications': true,
    'Sleep Tracking': false,
  };

  double get _bmi {
    final h = (_body['Height'] ?? 0) / 100;
    if (h <= 0) return 0;
    return (_body['Weight'] ?? 0) / (h * h);
  }

  String get _bmiTag {
    final b = _bmi;
    if (b < 18.5) return 'Under';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Over';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return FutureBuilder<List<WorkoutEntry>>(
      future: widget.entriesFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <WorkoutEntry>[];
        final summary = _Summary.from(entries);

        return Container(
          color: c.bg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _hero(context, summary),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Body Stats'),
                    _bodyStats(context),
                    const SizedBox(height: 22),
                    _title('Daily Goals'),
                    _goals(context),
                    const SizedBox(height: 22),
                    _title('Personal Records 🏆'),
                    _records(context, summary.records),
                    const SizedBox(height: 22),
                    _title('Badges'),
                    _badges(context),
                    const SizedBox(height: 22),
                    ..._menu(context),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Movara v1.0.0 · Built with 🔥',
                        style: TextStyle(color: c.textMuted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, _Summary s) {
    final c = context.movara;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surface, c.bg],
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.accent, width: 3),
                        boxShadow: [
                          BoxShadow(color: c.accentGlow, blurRadius: 20),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.photoUrl != null
                          ? Image.network(
                              widget.photoUrl!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                _name.isEmpty ? '?' : _name[0].toUpperCase(),
                                style: AppTheme.display(
                                  color: c.accent,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : Text(
                              _name.isEmpty ? '?' : _name[0].toUpperCase(),
                              style: AppTheme.display(
                                color: c.accent,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: AppTheme.display(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(_handle,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: c.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '🔥 PRO ATHLETE',
                        style: AppTheme.display(
                          color: c.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Real: derived from logged entries.
              _quickStat(context, '🏋️', '${s.workoutDays}', 'Workouts'),
              const SizedBox(width: 8),
              _quickStat(context, '📅', '${s.thisMonthDays}', 'This Month'),
              const SizedBox(width: 8),
              // TODO: no duration/calorie source yet.
              _quickStat(context, '⏱️', '94', 'Total Time'),
              const SizedBox(width: 8),
              _quickStat(context, '🔥', '52k', 'Calories'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStat(
      BuildContext context, String icon, String value, String label) {
    final c = context.movara;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.display(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 9, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────

  Widget _title(String text) {
    final c = context.movara;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.display(
          color: c.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, List<Widget> rows) {
    final c = context.movara;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: rows),
    );
  }

  Widget _bodyStats(BuildContext context) {
    final rows = <Widget>[];
    final specs = <({String label, String unit, bool editable})>[
      (label: 'Weight', unit: 'kg', editable: true),
      (label: 'Height', unit: 'cm', editable: true),
      (label: 'BMI', unit: '', editable: false),
      (label: 'Body Fat', unit: '%', editable: true),
      (label: 'Muscle Mass', unit: 'kg', editable: false),
      (label: 'Resting HR', unit: 'bpm', editable: false),
    ];

    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      // BMI is computed from weight + height rather than stored.
      final value = s.label == 'BMI' ? _bmi : (_body[s.label] ?? 0);
      rows.add(_bodyRow(
        context,
        label: s.label,
        value: value,
        unit: s.unit,
        editable: s.editable,
        tag: s.label == 'BMI' ? _bmiTag : null,
        striped: i.isOdd,
      ));
    }
    return _panel(context, rows);
  }

  Widget _bodyRow(
    BuildContext context, {
    required String label,
    required double value,
    required String unit,
    required bool editable,
    String? tag,
    required bool striped,
  }) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: striped ? c.surface2 : c.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          if (tag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.greenSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: TextStyle(
                    color: c.green, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: editable ? () => _editBody(label, value) : null,
            child: Container(
              decoration: editable
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.textMuted, width: 1),
                      ),
                    )
                  : null,
              child: RichText(
                text: TextSpan(
                  text: _fmt(value),
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                            color: c.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBody(String label, double current) async {
    final c = context.movara;
    final controller = TextEditingController(text: _fmt(current));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(label,
            style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(
                context, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _body[label] = result);
    }
  }

  Widget _goals(BuildContext context) {
    final c = context.movara;
    // TODO: placeholder targets until goals are stored server-side.
    final goals = <({String label, double current, double target, String unit, Color color})>[
      (label: 'Daily Steps', current: 7200, target: 10000, unit: 'steps', color: c.accent),
      (label: 'Weekly Workouts', current: 4, target: 5, unit: 'sessions', color: c.green),
      (label: 'Water Intake', current: 1.8, target: 2.5, unit: 'L', color: c.blue),
      (label: 'Sleep', current: 6.5, target: 8, unit: 'hrs', color: const Color(0xFFA78BFA)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < goals.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _goalBar(context, goals[i]),
          ],
        ],
      ),
    );
  }

  Widget _goalBar(
    BuildContext context,
    ({String label, double current, double target, String unit, Color color}) g,
  ) {
    final c = context.movara;
    final pct = (g.current / g.target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              g.label,
              style: AppTheme.display(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            RichText(
              text: TextSpan(
                text: _fmt(g.current),
                style: TextStyle(
                    color: g.color, fontSize: 12, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: ' / ${_fmt(g.target)} ${g.unit}',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: c.surface3,
            valueColor: AlwaysStoppedAnimation(g.color),
          ),
        ),
      ],
    );
  }

  Widget _records(BuildContext context, List<_Record> records) {
    final c = context.movara;

    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text('🏆', style: TextStyle(fontSize: 26, color: c.textMuted)),
            const SizedBox(height: 10),
            Text('No records yet',
                style: AppTheme.display(color: c.textPrimary, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Log a set with a weight to set your first PR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: [
        for (final r in records)
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
                Text(
                  r.exercise.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(
                    color: c.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  r.value,
                  style: AppTheme.display(
                    color: c.accent,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text('Set ${r.date}',
                    style: TextStyle(color: c.textMuted, fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badges(BuildContext context) {
    final c = context.movara;
    // TODO: earned flags are placeholders until achievements are tracked.
    const badges = <({String icon, String label, bool earned})>[
      (icon: '🏅', label: '10K Steps', earned: true),
      (icon: '🔥', label: '7-Day Streak', earned: true),
      (icon: '💪', label: '100kg Bench', earned: true),
      (icon: '🏃', label: '5K Runner', earned: true),
      (icon: '⚡', label: '30-Day Warrior', earned: false),
      (icon: '🥇', label: 'Elite Lifter', earned: false),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        for (final b in badges)
          Opacity(
            opacity: b.earned ? 1 : 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: b.earned ? c.surface : c.surface2,
                border: Border.all(color: b.earned ? c.accent : c.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    b.label,
                    textAlign: TextAlign.center,
                    style: AppTheme.display(
                      color: b.earned ? c.textPrimary : c.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _menu(BuildContext context) {
    final sections = <({String title, List<_MenuItem> items})>[
      (
        title: 'Preferences',
        items: [
          _MenuItem('🎯', 'Edit Goals', arrow: true),
          _MenuItem('📊', 'Progress History', arrow: true),
          _MenuItem('🔔', 'Notifications', toggle: true),
          _MenuItem('📏', 'Units (Metric)', arrow: true),
        ],
      ),
      (
        title: 'Health',
        items: [
          _MenuItem('❤️', 'Heart Rate Zones', arrow: true),
          _MenuItem('🩺', 'Health Metrics', arrow: true),
          _MenuItem('😴', 'Sleep Tracking', toggle: true),
        ],
      ),
      (
        title: 'Account',
        items: [
          _MenuItem('🔒', 'Privacy', arrow: true),
          _MenuItem('🔗', 'Connected Apps', arrow: true),
          _MenuItem('🚪', 'Sign Out', danger: true),
        ],
      ),
    ];

    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(_title(section.title));
      widgets.add(_panel(
        context,
        [
          for (var i = 0; i < section.items.length; i++)
            _menuRow(context, section.items[i], divider: i > 0),
        ],
      ));
      widgets.add(const SizedBox(height: 22));
    }
    return widgets;
  }

  Widget _menuRow(BuildContext context, _MenuItem item, {required bool divider}) {
    final c = context.movara;
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            )
          : null,
      child: InkWell(
        // TODO: wire these up as the corresponding screens are built.
        onTap: item.toggle
            ? null
            : item.label == 'Sign Out'
                ? () => widget.onSignOut?.call()
                : () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(item.icon,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.danger ? const Color(0xFFEF4444) : c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (item.toggle)
                _switch(context, _toggles[item.label] ?? false,
                    () => setState(() => _toggles[item.label] =
                        !(_toggles[item.label] ?? false)))
              else if (item.arrow)
                Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch(BuildContext context, bool on, VoidCallback onTap) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: on ? c.accent : c.surface3,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? c.accent : c.border, width: 1.5),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              left: on ? 19 : 1,
              top: 1,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _MenuItem {
  _MenuItem(this.icon, this.label,
      {this.arrow = false, this.toggle = false, this.danger = false});

  final String icon;
  final String label;
  final bool arrow;
  final bool toggle;
  final bool danger;
}

class _Record {
  const _Record({required this.exercise, required this.value, required this.date});
  final String exercise;
  final String value;
  final String date;
}

/// Figures derived from the real entry list.
class _Summary {
  const _Summary({
    required this.workoutDays,
    required this.thisMonthDays,
    required this.records,
  });

  /// Distinct days with at least one logged set.
  final int workoutDays;

  /// Distinct days logged in the current calendar month.
  final int thisMonthDays;

  /// Heaviest logged set per exercise, best first.
  final List<_Record> records;

  factory _Summary.from(List<WorkoutEntry> entries) {
    final now = DateTime.now();
    final days = <DateTime>{};
    final best = <String, WorkoutEntry>{};

    for (final e in entries) {
      final d = DateTime(
          e.performedAt.year, e.performedAt.month, e.performedAt.day);
      days.add(d);

      final weight = e.weightKg;
      if (weight == null || weight <= 0) continue;
      final current = best[e.exerciseName];
      if (current == null || weight > (current.weightKg ?? 0)) {
        best[e.exerciseName] = e;
      }
    }

    final ranked = best.values.toList()
      ..sort((a, b) => (b.weightKg ?? 0).compareTo(a.weightKg ?? 0));

    return _Summary(
      workoutDays: days.length,
      thisMonthDays: days
          .where((d) => d.year == now.year && d.month == now.month)
          .length,
      records: ranked
          .take(4)
          .map((e) => _Record(
                exercise: e.exerciseName,
                value: '${_fmt(e.weightKg ?? 0)} kg',
                date: DateFormat.MMMd().format(e.performedAt),
              ))
          .toList(),
    );
  }
}
