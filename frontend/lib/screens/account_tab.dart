import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Profile / account screen.
///
/// Workout counts and personal records come from real logged entries. Body
/// stats are editable and persisted on the device. The leaderboard username
/// and the settings menu (reminders, goal, privacy, about, sign out) are all
/// wired to real actions.
class AccountTab extends StatefulWidget {
  const AccountTab({
    super.key,
    required this.api,
    required this.entriesFuture,
    this.onOpenTab,
    this.displayName = 'Athlete',
    this.email,
    this.photoUrl,
    this.onSignOut,
  });

  final ApiService api;
  final Future<List<WorkoutEntry>> entriesFuture;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final Future<void> Function()? onSignOut;

  /// Switches the shell to another bottom tab (0=Home,1=Workout,3=Reminders).
  final void Function(int index)? onOpenTab;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String get _name => widget.displayName;
  String get _handle => widget.email ?? 'Signed in';

  final _usernameController = TextEditingController();
  bool _savingUsername = false;
  String? _usernameMsg;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadBody();
  }

  Future<void> _loadBody() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _body.keys.toList()) {
        final v = prefs.getDouble('body_$key');
        if (v != null) _body[key] = v;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    try {
      final me = await widget.api.fetchMyProfile();
      if (!mounted) return;
      // Only prefill if the user hasn't already started typing.
      if (_usernameController.text.isEmpty) {
        setState(() => _usernameController.text = me.username ?? '');
      }
    } catch (_) {
      // Prefill is best-effort; the field is editable regardless.
    }
  }

  Future<void> _saveUsername() async {
    final value = _usernameController.text.trim();
    setState(() {
      _savingUsername = true;
      _usernameMsg = null;
    });
    try {
      await widget.api.upsertProfile(widget.displayName,
          photoUrl: widget.photoUrl, username: value);
      if (mounted) {
        setState(() => _usernameMsg = value.isEmpty
            ? 'Cleared — others will see your first name.'
            : 'Saved. Others see “$value” on the leaderboard.');
      }
    } catch (_) {
      if (mounted) setState(() => _usernameMsg = "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  // Local-only for now; nothing persists these yet.
  final Map<String, double> _body = {
    'Weight': 70,
    'Height': 170,
    'Body Fat': 18,
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
                    _title('Leaderboard Name'),
                    _leaderboardName(context),
                    const SizedBox(height: 22),
                    _title('Body Stats'),
                    _bodyStats(context),
                    const SizedBox(height: 22),
                    _title('Personal Records 🏆'),
                    _records(context, summary.records),
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

  Widget _leaderboardName(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The name others see on the leaderboard. Leave it blank to show '
            'just your first name.',
            style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  maxLength: 40,
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. IronMike',
                    hintStyle: TextStyle(color: c.textMuted),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: c.surface2,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _savingUsername ? null : _saveUsername,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_savingUsername ? '…' : 'Save',
                      style: AppTheme.display(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          if (_usernameMsg != null) ...[
            const SizedBox(height: 8),
            Text(_usernameMsg!,
                style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ],
      ),
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
              _quickStat(context, '📈', '${s.totalSets}', 'Total Sets'),
              const SizedBox(width: 8),
              _quickStat(context, '🏅', '${s.prCount}', 'PRs'),
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('body_$label', result);
    }
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


  List<Widget> _menu(BuildContext context) {
    final items = <_MenuAction>[
      _MenuAction('🎯', 'Edit weekly goal', () => widget.onOpenTab?.call(0)),
      _MenuAction('💧', 'Water reminders', () => widget.onOpenTab?.call(3)),
      _MenuAction('🔒', 'Privacy & data', () => _showPrivacy(context)),
      _MenuAction('ℹ️', 'About Movara', () => _showAbout(context)),
      _MenuAction('🚪', 'Sign out', () => widget.onSignOut?.call(),
          danger: true),
    ];
    return [
      _title('Settings'),
      _panel(context, [
        for (var i = 0; i < items.length; i++)
          _menuRow(context, items[i], divider: i > 0),
      ]),
      const SizedBox(height: 22),
    ];
  }

  Widget _menuRow(BuildContext context, _MenuAction item, {required bool divider}) {
    final c = context.movara;
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(top: BorderSide(color: c.border)))
          : null,
      child: InkWell(
        onTap: item.onTap,
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
                child: Text(item.label,
                    style: TextStyle(
                      color:
                          item.danger ? const Color(0xFFEF4444) : c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    )),
              ),
              if (!item.danger)
                Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacy(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy & data',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        content: Text(
          'Your workouts and runs are tied to your account and only you can '
          'see your own data. On the leaderboard, others see only your chosen '
          'username (or first name) and your weekly totals — never your '
          'individual entries. Body stats stay on this device. Sign-in is '
          'handled by Google; Movara never sees your password.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Got it', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final c = context.movara;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Movara',
            style: AppTheme.display(color: c.accent, fontSize: 20)),
        content: Text(
          'Movara v1.0.0\n\nTrack workouts and runs, share your route, and '
          'stay on the leaderboard. Built with 🔥.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _MenuAction {
  _MenuAction(this.icon, this.label, this.onTap, {this.danger = false});
  final String icon;
  final String label;
  final VoidCallback onTap;
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
    required this.totalSets,
    required this.prCount,
    required this.records,
  });

  /// Distinct days with at least one logged set.
  final int workoutDays;

  /// Distinct days logged in the current calendar month.
  final int thisMonthDays;

  /// Every set ever logged, and how many exercises have a weight PR.
  final int totalSets;
  final int prCount;

  /// Heaviest logged set per exercise, best first.
  final List<_Record> records;

  factory _Summary.from(List<WorkoutEntry> entries) {
    final now = DateTime.now();
    final days = <DateTime>{};
    final best = <String, WorkoutEntry>{};
    var totalSets = 0;

    for (final e in entries) {
      final d = DateTime(
          e.performedAt.year, e.performedAt.month, e.performedAt.day);
      days.add(d);
      totalSets += e.sets;

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
      totalSets: totalSets,
      prCount: best.length,
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
