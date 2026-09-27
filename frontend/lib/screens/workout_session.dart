import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Category-based workout session screen, ported from the React `WorkoutPage`
/// design: horizontal category tabs, exercise cards with per-set reps/weight
/// tracking and a step-by-step demo sheet.
///
/// Completed sets are reconstructed from the entries logged today, so ticks
/// survive a page refresh and moving between categories, and clear on their
/// own tomorrow. Reps/weight edits on not-yet-logged sets stay local.
class WorkoutSession extends StatefulWidget {
  const WorkoutSession({
    super.key,
    required this.entries,
    required this.onLogSet,
    required this.onUnlogSet,
  });

  /// All logged entries; only today's are used to restore ticks.
  final List<WorkoutEntry> entries;

  /// Logs a completed set; returns the created entry id (or null on failure).
  final Future<String?> Function(String exerciseName, int reps, double weightKg)
      onLogSet;

  /// Removes a previously logged set by its entry id.
  final Future<void> Function(String entryId) onUnlogSet;

  @override
  State<WorkoutSession> createState() => _WorkoutSessionState();
}

class _WorkoutSessionState extends State<WorkoutSession> {
  static const _categories = [
    'Chest',
    'Shoulders',
    'Bicep',
    'Tricep',
    'Arms',
    'Back',
    'Abs',
    'Legs',
  ];

  String _active = 'Chest';

  /// Today's entries per exercise name (lowercased), oldest first so they map
  /// onto set 1, set 2, ... in the order they were completed.
  /// Lifetime best reps and heaviest weight per exercise (lowercased name),
  /// across every logged entry — shown on each card for motivation.
  Map<String, ({int reps, double weight})> _bestsByExercise() {
    final map = <String, ({int reps, double weight})>{};
    for (final e in widget.entries) {
      final key = e.exerciseName.toLowerCase();
      final prev = map[key];
      final w = e.weightKg ?? 0;
      map[key] = (
        reps: prev == null ? e.reps : (e.reps > prev.reps ? e.reps : prev.reps),
        weight: prev == null ? w : (w > prev.weight ? w : prev.weight),
      );
    }
    return map;
  }

  Map<String, List<WorkoutEntry>> _loggedToday() {
    final now = DateTime.now();
    final grouped = <String, List<WorkoutEntry>>{};

    for (final e in widget.entries) {
      final d = e.performedAt;
      if (d.year != now.year || d.month != now.month || d.day != now.day) {
        continue;
      }
      grouped.putIfAbsent(e.exerciseName.toLowerCase(), () => []).add(e);
    }
    for (final list in grouped.values) {
      // ObjectId hex is time-ordered, so ascending id == chronological.
      list.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final exercises = _workoutData[_active] ?? const [];
    final loggedToday = _loggedToday();
    final bests = _bestsByExercise();

    // Categories with at least one exercise logged today — their pill lights up
    // so it's obvious at a glance which muscle groups have been trained.
    final doneCategories = <String>{
      for (final name in loggedToday.keys)
        if (_exerciseCategory[name] != null) _exerciseCategory[name]!,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S SESSION",
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Workout',
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Category tab bar.
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final active = cat == _active;
                final done = doneCategories.contains(cat);
                // Active pill stays accent; a trained-but-inactive category
                // turns green; an untouched one stays neutral.
                final bg = active
                    ? c.accent
                    : done
                        ? c.green.withValues(alpha: 0.15)
                        : c.surface2;
                final border = active
                    ? c.accent
                    : done
                        ? c.green
                        : c.border;
                final fg = active
                    ? Colors.white
                    : done
                        ? c.green
                        : c.textSecondary;
                return GestureDetector(
                  onTap: () => setState(() => _active = cat),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (done) ...[
                          Icon(Icons.check_circle,
                              size: 14,
                              color: active ? Colors.white : c.green),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          cat,
                          style: AppTheme.display(
                            color: fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // A fixed gap so the scrolling list never merges into the tabs.
          const SizedBox(height: 12),

          // Exercise list.
          Expanded(
            child: exercises.isEmpty
                ? _EmptyCategory(category: _active)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _ExerciseCard(
                      // Key by exercise id so each card keeps its own set
                      // state — without it Flutter reuses a card's State by
                      // list position, leaking "done" toggles across
                      // exercises when the category changes.
                      key: ValueKey(exercises[i].id),
                      exercise: exercises[i],
                      todayEntries:
                          loggedToday[exercises[i].name.toLowerCase()] ?? const [],
                      best: bests[exercises[i].name.toLowerCase()],
                      onLogSet: widget.onLogSet,
                      onUnlogSet: widget.onUnlogSet,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏋️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'No exercises yet for $category',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Exercise card ───────────────────────────────────────────────────

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.todayEntries,
    required this.best,
    required this.onLogSet,
    required this.onUnlogSet,
  });

  final _Exercise exercise;
  final List<WorkoutEntry> todayEntries;

  /// Lifetime best reps + heaviest weight for this exercise, or null if never
  /// logged.
  final ({int reps, double weight})? best;
  final Future<String?> Function(String, int, double) onLogSet;
  final Future<void> Function(String) onUnlogSet;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late List<_SetState> _sets;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _sets = _merge(const []);
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-derive ticks whenever the day's logged entries change, so the server
    // stays the source of truth for what is done.
    if (_signature(oldWidget.todayEntries) != _signature(widget.todayEntries)) {
      setState(() => _sets = _merge(_sets));
    }
  }

  String _signature(List<WorkoutEntry> entries) =>
      entries.map((e) => e.id ?? '').join(',');

  /// Rebuild the set rows from today's logged entries.
  ///
  /// The first N rows mirror the N sets logged today (ticked, with the reps
  /// and weight actually performed). Rows beyond that keep any local
  /// reps/weight edits the user has made but are never left ticked.
  List<_SetState> _merge(List<_SetState> current) {
    final logged = widget.todayEntries;
    final defaults = widget.exercise.sets;

    // Keep however many rows the user is currently working with, but always
    // show at least every set logged today.
    final baseline = current.isEmpty ? defaults.length : current.length;
    final total = logged.length > baseline ? logged.length : baseline;

    final result = <_SetState>[];
    for (var i = 0; i < total; i++) {
      if (i < logged.length) {
        final entry = logged[i];
        result.add(
          _SetState(reps: entry.reps, weight: entry.weightKg ?? 0)
            ..done = true
            ..loggedId = entry.id,
        );
      } else if (i < current.length) {
        // Preserve local edits, but this row is not logged, so never ticked.
        final existing = current[i]
          ..done = false
          ..loggedId = null;
        result.add(existing);
      } else {
        final spec = i < defaults.length ? defaults[i] : defaults.last;
        result.add(_SetState(reps: spec.reps, weight: spec.weight));
      }
    }
    return result;
  }

  Future<void> _toggleDone(int i) async {
    final set = _sets[i];
    // Optimistically flip; reconcile with backend result.
    if (!set.done) {
      setState(() => set.done = true);
      final id = await widget.onLogSet(
        widget.exercise.name,
        set.reps,
        set.weight,
      );
      if (!mounted) return;
      if (id == null) {
        setState(() => set.done = false); // logging failed, revert
      } else {
        set.loggedId = id;
      }
    } else {
      final id = set.loggedId;
      setState(() {
        set.done = false;
        set.loggedId = null;
      });
      if (id != null) await widget.onUnlogSet(id);
    }
  }

  void _changeReps(int i, int delta) {
    setState(() => _sets[i].reps = (_sets[i].reps + delta).clamp(1, 999).toInt());
  }

  void _changeWeight(int i, double delta) {
    setState(() {
      final w = (_sets[i].weight + delta).clamp(0, 999).toDouble();
      _sets[i].weight = double.parse(w.toStringAsFixed(1));
    });
  }

  Future<void> _editReps(int i) async {
    final controller = TextEditingController(text: '${_sets[i].reps}');
    final c = context.movara;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Reps', style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 10'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _sets[i].reps = result);
    }
  }

  Future<void> _editWeight(int i) async {
    final controller = TextEditingController(
      text: _sets[i].weight == 0 ? '' : _formatWeight(_sets[i].weight),
    );
    final c = context.movara;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Weight (kg)', style: AppTheme.display(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _sets[i].weight = result.clamp(0, 999).toDouble());
    }
  }

  void _addSet() {
    final last = _sets.last;
    setState(() => _sets.add(_SetState(reps: last.reps, weight: last.weight)));
  }

  Future<void> _removeSet(int i) async {
    final id = _sets[i].loggedId;
    setState(() => _sets.removeAt(i));
    if (id != null) await widget.onUnlogSet(id);
  }

  bool get _hasBest {
    final b = widget.best;
    return b != null && (b.reps > 0 || b.weight > 0);
  }

  /// Personal-best chip: your lifetime best reps and heaviest weight for this
  /// exercise, for a little motivation to beat it.
  Widget _prChip(BuildContext context) {
    final c = context.movara;
    final b = widget.best!;
    final parts = <String>[
      if (b.reps > 0) '${b.reps} reps',
      if (b.weight > 0) '${_formatWeight(b.weight)} kg',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '🏆 PR ${parts.join(' · ')}',
        style: AppTheme.display(
          color: c.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final ex = widget.exercise;
    final completed = _sets.where((s) => s.done).length;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap to expand/collapse. Collapsed by default so the whole
          // list is scannable; expand one to record it.
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 12, _expanded ? 10 : 14),
              child: Row(
                children: [
                  _ExerciseThumb(
                    exercise: ex,
                    size: 46,
                    radius: 12,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: AppTheme.display(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ex.muscle,
                          style: TextStyle(color: c.textMuted, fontSize: 11),
                        ),
                        if (_hasBest) ...[
                          const SizedBox(height: 4),
                          _prChip(context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Compact progress badge, always visible.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: completed > 0 ? c.accentSoft : c.surface2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$completed/${_sets.length}',
                      style: AppTheme.display(
                        color: completed > 0 ? c.accent : c.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
          // Demo.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _showDemo(context, ex),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: c.accent),
                      const SizedBox(width: 5),
                      Text(
                        'Demo',
                        style: AppTheme.display(
                          color: c.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Progress.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SETS PROGRESS',
                      style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.4),
                    ),
                    Text(
                      '$completed / ${_sets.length}',
                      style: TextStyle(color: c.accent, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _sets.isEmpty ? 0 : completed / _sets.length,
                    minHeight: 6,
                    backgroundColor: c.surface3,
                    valueColor: AlwaysStoppedAnimation(c.accent),
                  ),
                ),
              ],
            ),
          ),

          // Set rows.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                for (var i = 0; i < _sets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildSetRow(context, i),
                ],
              ],
            ),
          ),

          // Add set.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
              onTap: _addSet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Add Set ${_sets.length + 1}',
                      style: AppTheme.display(
                        color: c.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetRow(BuildContext context, int i) {
    final c = context.movara;
    final s = _sets[i];

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: s.done ? c.accentSoft : c.surface2,
        border: Border.all(color: s.done ? c.accent.withValues(alpha: 0.35) : c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Done toggle — opaque hit test so the whole circle is tappable.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleDone(i),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.done ? c.accent : c.surface3,
                shape: BoxShape.circle,
                border: Border.all(color: s.done ? c.accent : c.border, width: 1.5),
              ),
              child: s.done
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              'Set',
              style: AppTheme.display(
                color: s.done ? c.accent : c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _roundBtn(context, '−', () => _changeReps(i, -1), c.textSecondary),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editReps(i),
            child: Container(
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface3,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s.reps}',
                style: AppTheme.display(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _roundBtn(context, '+', () => _changeReps(i, 1), c.accent),
          const Spacer(),
          // Weight control.
          _roundBtn(context, '−', () => _changeWeight(i, -0.5), c.textSecondary),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editWeight(i),
            child: Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface3,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  text: s.weight == 0 ? '0' : _formatWeight(s.weight),
                  style: AppTheme.display(
                    color: s.weight == 0 ? c.textMuted : c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(color: c.textMuted, fontSize: 9, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _roundBtn(context, '+', () => _changeWeight(i, 0.5), c.accent),
        ],
      ),
    );

    // Swipe a set left to delete it (keeping at least one). Replaces the old
    // inline "×" that was pushed off the right edge on narrow phones.
    return Dismissible(
      key: ObjectKey(s),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => _sets.length > 1,
      onDismissed: (_) => _removeSet(i),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      child: row,
    );
  }

  Widget _roundBtn(BuildContext context, String label, VoidCallback onTap, Color fg) {
    final c = context.movara;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface3,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700, height: 1),
        ),
      ),
    );
  }

  void _showDemo(BuildContext context, _Exercise ex) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DemoSheet(exercise: ex),
    );
  }
}

String _formatWeight(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// ── Demo sheet ──────────────────────────────────────────────────────

class _DemoSheet extends StatefulWidget {
  const _DemoSheet({required this.exercise});

  final _Exercise exercise;

  @override
  State<_DemoSheet> createState() => _DemoSheetState();
}

class _DemoSheetState extends State<_DemoSheet> {
  int _step = 0;

  void _setStep(int i) {
    final n = i.clamp(0, widget.exercise.steps.length - 1);
    if (n != _step) setState(() => _step = n);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final steps = widget.exercise.steps;
    final last = _step == steps.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEMO · TUTORIAL',
                      style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.exercise.name,
                      style: AppTheme.display(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                  child: Icon(Icons.close, size: 18, color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Swipe left/right anywhere over the figure and step to move
          // between steps — the Prev/Next buttons do the same.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -100) {
                _setStep(_step + 1);
              } else if (v > 100) {
                _setStep(_step - 1);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Figure area — flips between the start and end frame so the
                // movement reads as animated. Falls back to the icon if the
                // photos are missing or fail to load.
                _DemoFigure(exercise: widget.exercise),
                const SizedBox(height: 10),
                // Step dots.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _setStep(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _step ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _step ? c.accent : c.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                // Step content, animated so a swipe reads as a page change.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_step),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_step + 1}',
                            style: AppTheme.display(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            steps[_step],
                            style: TextStyle(
                                color: c.textPrimary, fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Nav.
          Row(
            children: [
              Expanded(
                child: _sheetBtn(
                  context,
                  label: '← Prev',
                  bg: c.surface2,
                  fg: c.textSecondary,
                  border: c.border,
                  enabled: _step > 0,
                  onTap: () => _setStep(_step - 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: last
                    ? _sheetBtn(
                        context,
                        label: '✓ Got it!',
                        bg: c.green,
                        fg: Colors.white,
                        onTap: () => Navigator.pop(context),
                      )
                    : _sheetBtn(
                        context,
                        label: 'Next →',
                        bg: c.accent,
                        fg: Colors.white,
                        onTap: () => _setStep(_step + 1),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetBtn(
    BuildContext context, {
    required String label,
    required Color bg,
    required Color fg,
    Color? border,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: border != null ? Border.all(color: border) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppTheme.display(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Exercise thumbnail ──────────────────────────────────────────────

/// Rounded thumbnail showing the exercise's real photo, with a graceful
/// fall back to the tinted [_Exercise.icon] while loading or on error.
class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({
    required this.exercise,
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final _Exercise exercise;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(exercise.icon, color: c.accent, size: iconSize),
    );

    if (exercise.images.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        exercise.images.first,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Decode down to the thumbnail size so a full-res gym photo doesn't
        // cost memory/CPU on every card — a big source of list jank.
        cacheWidth: 180,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress != null ? fallback : child,
      ),
    );
  }
}

/// Demo figure that cross-fades between the exercise's start and end frame
/// on a repeating timer so the movement reads as animated.
class _DemoFigure extends StatefulWidget {
  const _DemoFigure({required this.exercise});

  final _Exercise exercise;

  @override
  State<_DemoFigure> createState() => _DemoFigureState();
}

class _DemoFigureState extends State<_DemoFigure> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.exercise.images.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (mounted) {
          setState(() => _frame = _frame == 0 ? 1 : 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final images = widget.exercise.images;

    final fallback = Icon(
      widget.exercise.icon,
      size: 56,
      color: c.accent.withValues(alpha: 0.85),
    );

    Widget content;
    if (images.isEmpty) {
      content = Center(child: fallback);
    } else {
      content = AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Image.network(
          images[_frame.clamp(0, images.length - 1)],
          key: ValueKey(_frame),
          fit: BoxFit.contain,
          cacheWidth: 500,
          errorBuilder: (_, __, ___) => Center(child: fallback),
          loadingBuilder: (_, child, progress) =>
              progress != null ? Center(child: fallback) : child,
        ),
      );
    }

    return Container(
      height: 160,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}

// ── Data ────────────────────────────────────────────────────────────

class _Exercise {
  const _Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.steps,
    required this.icon,
    this.images = const [],
  });

  final String id;
  final String name;
  final String muscle;
  final List<_SetSpec> sets;
  final List<String> steps;
  final IconData icon;

  /// Real exercise photos (start → end frame) from the public-domain
  /// free-exercise-db. Empty falls back to [icon].
  final List<String> images;
}

class _SetSpec {
  const _SetSpec(this.reps, [this.weight = 0]);
  final int reps;
  final double weight;
}

class _SetState {
  _SetState({required this.reps, this.weight = 0});
  int reps;
  double weight;
  bool done = false;
  String? loggedId;
}

/// Lower-cased exercise name → its category, so a logged entry can light up
/// the category pill for the day.
final Map<String, String> _exerciseCategory = {
  for (final entry in _workoutData.entries)
    for (final ex in entry.value) ex.name.toLowerCase(): entry.key,
};

const _workoutData = <String, List<_Exercise>>{
  'Chest': [
    _Exercise(
      id: 'bench-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/1.jpg'],
      name: 'Bench Press',
      muscle: 'Chest · Shoulders · Triceps',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.fitness_center,
      steps: [
        'Lie flat on bench, grip bar slightly wider than shoulder-width',
        'Lower bar slowly to mid-chest, elbows at ~75°',
        'Press up powerfully, keep wrists stacked over elbows',
        'Lock out without bouncing the bar',
      ],
    ),
    _Exercise(
      id: 'chest-press-machine',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Bench_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Bench_Press/1.jpg'],
      name: 'Chest Press Machine',
      muscle: 'Chest · Anterior Deltoid',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Set seat so handles are at mid-chest height',
        'Press handles forward until arms nearly straight',
        'Squeeze chest at the end of the press',
        'Return slowly, keeping tension',
      ],
    ),
    _Exercise(
      id: 'incline-dumbbell-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/1.jpg'],
      name: 'Incline Dumbbell Press',
      muscle: 'Upper Chest · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Set bench to 30-45°, dumbbells at shoulder level',
        'Press up and slightly in until they nearly touch',
        'Lower under control to a deep stretch',
        'Keep shoulder blades pinned back',
      ],
    ),
    _Exercise(
      id: 'dumbbell-bench-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bench_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bench_Press/1.jpg'],
      name: 'Dumbbell Bench Press',
      muscle: 'Chest · Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Lie flat, dumbbells at chest, palms forward',
        'Press up until arms extend over chest',
        'Lower slowly to chest level',
        'Keep elbows at ~45° from torso',
      ],
    ),
    _Exercise(
      id: 'cable-fly',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/1.jpg'],
      name: 'Cable Fly',
      muscle: 'Chest · Inner Pec',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Set pulleys high, grab handles, step forward',
        'Slight elbow bend, bring hands together in an arc',
        'Squeeze chest at the middle',
        'Control the stretch back out',
      ],
    ),
    _Exercise(
      id: 'cable-crossover',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/1.jpg'],
      name: 'Cable Crossover',
      muscle: 'Lower Chest',
      sets: [_SetSpec(15), _SetSpec(15), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Set pulleys high, lean slightly forward',
        'Draw handles down and across the body',
        'Cross hands at the bottom, squeeze',
        'Return with control, chest stretched',
      ],
    ),
    _Exercise(
      id: 'chest-dips',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Chest_Version/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Chest_Version/1.jpg'],
      name: 'Chest Dips',
      muscle: 'Lower Chest · Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Grip parallel bars, lean torso forward',
        'Lower until you feel a chest stretch',
        'Press up without locking harshly',
        'Keep elbows flaring slightly out for chest',
      ],
    ),
    _Exercise(
      id: 'push-up',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pushups/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pushups/1.jpg'],
      name: 'Push-Up',
      muscle: 'Chest · Core',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(15)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Hands slightly wider than shoulders, body straight',
        'Lower chest to just above the floor',
        'Press up, keeping core tight',
        'Do not let hips sag',
      ],
    ),
    _Exercise(
      id: 'decline-bench-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Decline_Barbell_Bench_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Decline_Barbell_Bench_Press/1.jpg'],
      name: 'Decline Bench Press',
      muscle: 'Lower Chest · Triceps',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.fitness_center,
      steps: [
        'Set bench to a slight decline, feet locked in',
        'Lower bar to lower chest',
        'Press up over the shoulders',
        'Control the eccentric, no bounce',
      ],
    ),
    _Exercise(
      id: 'incline-barbell-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Incline_Bench_Press_-_Medium_Grip/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Incline_Bench_Press_-_Medium_Grip/1.jpg'],
      name: 'Incline Barbell Press',
      muscle: 'Chest · Shoulders · Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Lie back on an incline bench. Using a medium-width grip (a grip that creates a 90-degree angle…',
        'As you breathe in, come down slowly until you feel the bar on you upper chest',
        'After a second pause, bring the bar back to the starting position as you breathe out and push…',
        'Repeat the movement for the prescribed amount of repetitions',
      ],
    ),
    _Exercise(
      id: 'dumbbell-flyes',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Flyes/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Flyes/1.jpg'],
      name: 'Dumbbell Flyes',
      muscle: 'Chest',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Lie down on a flat bench with a dumbbell on each hand resting on top of your thighs. The palms…',
        'Then using your thighs to help raise the dumbbells, lift the dumbbells one at a time so you can…',
        'With a slight bend on your elbows in order to prevent stress at the biceps tendon, lower your…',
        'Return your arms back to the starting position as you squeeze your chest muscles and breathe…',
      ],
    ),
    _Exercise(
      id: 'pec-deck-butterfly',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Butterfly/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Butterfly/1.jpg'],
      name: 'Pec Deck (Butterfly)',
      muscle: 'Chest',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Sit on the machine with your back flat on the pad',
        'Take hold of the handles. Tip: Your upper arms should be positioned parallel to the floor;…',
        'Push the handles together slowly as you squeeze your chest in the middle. Breathe out during…',
        'Return back to the starting position slowly as you inhale until your chest muscles are fully…',
      ],
    ),
    _Exercise(
      id: 'decline-dumbbell-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Decline_Dumbbell_Bench_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Decline_Dumbbell_Bench_Press/1.jpg'],
      name: 'Decline Dumbbell Press',
      muscle: 'Chest · Shoulders · Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Secure your legs at the end of the decline bench and lie down with a dumbbell on each hand on…',
        'Once you are laying down, move the dumbbells in front of you at shoulder width',
        'Once at shoulder width, rotate your wrists forward so that the palms of your hands are facing…',
        'Bring down the weights slowly to your side as you breathe out. Keep full control of the…',
      ],
    ),
    _Exercise(
      id: 'dumbbell-pullover',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Straight-Arm_Dumbbell_Pullover/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Straight-Arm_Dumbbell_Pullover/1.jpg'],
      name: 'Dumbbell Pullover',
      muscle: 'Chest · Lats · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Place a dumbbell standing up on a flat bench',
        'Ensuring that the dumbbell stays securely placed at the top of the bench, lie perpendicular to…',
        'Grasp the dumbbell with both hands and hold it straight over your chest at arms length. Both…',
        'While keeping your arms straight, lower the weight slowly in an arc behind your head while…',
      ],
    ),
  ],
  'Shoulders': [
    _Exercise(
      id: 'overhead-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Military_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Military_Press/1.jpg'],
      name: 'Overhead Press',
      muscle: 'Shoulders · Triceps',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.fitness_center,
      steps: [
        'Bar at collarbone, grip just outside shoulders',
        'Brace core, press bar straight overhead',
        'Move head slightly back then through',
        'Lock out with bar over mid-foot',
      ],
    ),
    _Exercise(
      id: 'dumbbell-shoulder-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Dumbbell_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Dumbbell_Press/1.jpg'],
      name: 'Dumbbell Shoulder Press',
      muscle: 'Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Dumbbells at shoulder height, palms forward',
        'Press up until arms nearly straight',
        'Lower slowly to ear level',
        'Keep core braced, avoid arching back',
      ],
    ),
    _Exercise(
      id: 'lateral-raise',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/1.jpg'],
      name: 'Lateral Raise',
      muscle: 'Side Delts',
      sets: [_SetSpec(15), _SetSpec(15), _SetSpec(12)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Dumbbells at sides, slight forward lean',
        'Raise arms out to shoulder height',
        'Lead with elbows, small bend in arm',
        'Lower slowly, no swinging',
      ],
    ),
    _Exercise(
      id: 'front-raise',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Dumbbell_Raise/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Dumbbell_Raise/1.jpg'],
      name: 'Front Raise',
      muscle: 'Front Delts',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Dumbbells in front of thighs',
        'Raise one or both to shoulder height',
        'Keep a slight elbow bend',
        'Lower under control',
      ],
    ),
    _Exercise(
      id: 'arnold-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arnold_Dumbbell_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arnold_Dumbbell_Press/1.jpg'],
      name: 'Arnold Press',
      muscle: 'Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Start palms facing you at chest',
        'Rotate and press up until palms face forward',
        'Reverse the rotation on the way down',
        'Keep the motion smooth',
      ],
    ),
    _Exercise(
      id: 'face-pull',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/1.jpg'],
      name: 'Face Pull',
      muscle: 'Rear Delts · Upper Back',
      sets: [_SetSpec(15), _SetSpec(15), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Set cable at face height with a rope',
        'Pull rope toward your face, elbows high',
        'Squeeze rear delts and upper back',
        'Return slowly with control',
      ],
    ),
    _Exercise(
      id: 'shrugs',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shrug/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shrug/1.jpg'],
      name: 'Barbell Shrugs',
      muscle: 'Traps',
      sets: [_SetSpec(15), _SetSpec(15), _SetSpec(12)],
      icon: Icons.fitness_center,
      steps: [
        'Hold bar with arms straight',
        'Shrug shoulders straight up toward ears',
        'Hold the squeeze at the top',
        'Lower slowly, no rolling',
      ],
    ),
    _Exercise(
      id: 'upright-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Upright_Barbell_Row/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Upright_Barbell_Row/1.jpg'],
      name: 'Upright Row',
      muscle: 'Shoulders · Traps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Grasp a barbell with an overhand grip that is slightly less than shoulder width. The bar should…',
        'Now exhale and use the sides of your shoulders to lift the bar, raising your elbows up and to…',
        'Lower the bar back down slowly to the starting position. Inhale as you perform this portion of…',
        'Repeat for the recommended amount of repetitions',
      ],
    ),
    _Exercise(
      id: 'rear-delt-fly',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Flyes/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Flyes/1.jpg'],
      name: 'Rear Delt Fly',
      muscle: 'Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'To begin, lie down on an incline bench with the chest and stomach pressing against the incline.…',
        'Extend the arms in front of you so that they are perpendicular to the angle of the bench. The…',
        'Maintaining the slight bend of the elbows, move the weights out and away from each other (to…',
        'The arms should be elevated until they are parallel to the floor',
      ],
    ),
    _Exercise(
      id: 'reverse-pec-deck',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Machine_Flyes/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Machine_Flyes/1.jpg'],
      name: 'Reverse Pec Deck',
      muscle: 'Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Adjust the handles so that they are fully to the rear. Make an appropriate weight selection and…',
        'In a semicircular motion, pull your hands out to your side and back, contracting your rear…',
        'Keep your arms slightly bent throughout the movement, with all of the motion occurring at the…',
        'Pause at the rear of the movement, and slowly return the weight to the starting position',
      ],
    ),
    _Exercise(
      id: 'seated-military-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Barbell_Military_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Barbell_Military_Press/1.jpg'],
      name: 'Seated Military Press',
      muscle: 'Shoulders · Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Sit on a Military Press Bench with a bar behind your head and either have a spotter give you…',
        'Once you pick up the barbell with the correct grip length, lift the bar up over your head by…',
        'Lower the bar down to the collarbone slowly as you inhale',
        'Lift the bar back up to the starting position as you exhale',
      ],
    ),
    _Exercise(
      id: 'dumbbell-shrug',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/1.jpg'],
      name: 'Dumbbell Shrug',
      muscle: 'Traps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Stand erect with a dumbbell on each hand (palms facing your torso), arms extended on the sides',
        'Lift the dumbbells by elevating the shoulders as high as possible while you exhale. Hold the…',
        'Lower the dumbbells back to the original position',
        'Repeat for the recommended amount of repetitions',
      ],
    ),
  ],
  'Bicep': [
    _Exercise(
      id: 'barbell-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/1.jpg'],
      name: 'Barbell Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Stand tall, bar in underhand grip',
        'Curl up keeping elbows pinned to sides',
        'Squeeze at the top',
        'Lower slowly, full stretch at bottom',
      ],
    ),
    _Exercise(
      id: 'dumbbell-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bicep_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bicep_Curl/1.jpg'],
      name: 'Dumbbell Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.fitness_center,
      steps: [
        'Dumbbells at sides, palms forward',
        'Curl one or both up to shoulders',
        'Keep elbows fixed at your sides',
        'Lower with control',
      ],
    ),
    _Exercise(
      id: 'hammer-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hammer_Curls/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hammer_Curls/1.jpg'],
      name: 'Hammer Curl',
      muscle: 'Biceps · Brachialis',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.fitness_center,
      steps: [
        'Hold dumbbells with a neutral grip',
        'Curl up keeping palms facing each other',
        'Squeeze at the top',
        'Lower slowly and controlled',
      ],
    ),
    _Exercise(
      id: 'preacher-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Preacher_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Preacher_Curl/1.jpg'],
      name: 'Preacher Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Rest upper arms on the preacher pad',
        'Curl the bar up, do not swing',
        'Squeeze hard at the top',
        'Lower until arms are nearly straight',
      ],
    ),
    _Exercise(
      id: 'incline-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Curl/1.jpg'],
      name: 'Incline Dumbbell Curl',
      muscle: 'Biceps · Long Head',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.fitness_center,
      steps: [
        'Sit back on a 45-60° incline bench',
        'Let arms hang, curl dumbbells up',
        'Keep elbows back for a deep stretch',
        'Lower slowly',
      ],
    ),
    _Exercise(
      id: 'cable-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Biceps_Cable_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Biceps_Cable_Curl/1.jpg'],
      name: 'Cable Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Attach a bar to the low pulley',
        'Curl up with elbows pinned',
        'Squeeze at the top under constant tension',
        'Lower with control',
      ],
    ),
    _Exercise(
      id: 'concentration-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/1.jpg'],
      name: 'Concentration Curl',
      muscle: 'Biceps Peak',
      sets: [_SetSpec(12), _SetSpec(12), _SetSpec(10)],
      icon: Icons.fitness_center,
      steps: [
        'Seated, elbow braced on inner thigh',
        'Curl the dumbbell up to the shoulder',
        'Squeeze the peak hard',
        'Lower slowly, full extension',
      ],
    ),
    _Exercise(
      id: 'spider-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Spider_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Spider_Curl/1.jpg'],
      name: 'Spider Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Start out by setting the bar on the part of the preacher bench that you would normally sit on.…',
        'Move to the front side of the preacher bench (the part where the arms usually lay) and position…',
        'Make sure that your feet (especially the toes) are well positioned on the floor and place your…',
        'Use your arms to grab the barbell with a supinated grip (palms facing up) at about shoulder…',
      ],
    ),
    _Exercise(
      id: 'zottman-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Zottman_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Zottman_Curl/1.jpg'],
      name: 'Zottman Curl',
      muscle: 'Biceps · Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Stand up with your torso upright and a dumbbell in each hand being held at arms length. The…',
        'Make sure the palms of the hands are facing each other. This will be your starting position',
        'While holding the upper arm stationary, curl the weights while contracting the biceps as you…',
        'Hold the contracted position for a second as you squeeze the biceps',
      ],
    ),
    _Exercise(
      id: 'machine-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Bicep_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Bicep_Curl/1.jpg'],
      name: 'Machine Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Adjust the seat to the appropriate height and make your weight selection. Place your upper arms…',
        'Perform the movement by flexing the elbow, pulling your lower arm towards your upper arm',
        'Pause at the top of the movement, and then slowly return the weight to the starting position',
        'Avoid returning the weight all the way to the stops until the set is complete to keep tension…',
      ],
    ),
    _Exercise(
      id: 'cable-rope-hammer-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Hammer_Curls_-_Rope_Attachment/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Hammer_Curls_-_Rope_Attachment/1.jpg'],
      name: 'Cable Rope Hammer Curl',
      muscle: 'Biceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Attach a rope attachment to a low pulley and stand facing the machine about 12 inches away from…',
        'Grasp the rope with a neutral (palms-in) grip and stand straight up keeping the natural arch of…',
        'Put your elbows in by your side and keep them there stationary during the entire movement. Tip:…',
        'Using your biceps, pull your arms up as you exhale until your biceps touch your forearms. Tip:…',
      ],
    ),
    _Exercise(
      id: 'reverse-cable-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Cable_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Cable_Curl/1.jpg'],
      name: 'Reverse Cable Curl',
      muscle: 'Biceps · Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Stand up with your torso upright while holding a bar attachment that is attached to a low…',
        'While holding the upper arms stationary, curl the weights while contracting the biceps as you…',
        'Slowly begin to bring the bar back to starting position as your breathe in',
        'Repeat for the recommended amount of repetitions',
      ],
    ),
  ],
  'Tricep': [
    _Exercise(
      id: 'tricep-pushdown',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/1.jpg'],
      name: 'Tricep Pushdown',
      muscle: 'Triceps · Lateral Head',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(10)],
      icon: Icons.cable,
      steps: [
        'Grab the bar with an overhand grip',
        'Keep elbows pinned to sides',
        'Push down until arms fully extend',
        'Let the bar rise back slowly',
      ],
    ),
    _Exercise(
      id: 'rope-pushdown',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/1.jpg'],
      name: 'Rope Pushdown',
      muscle: 'Triceps',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Grab the rope, elbows at sides',
        'Push down and split the rope at the bottom',
        'Squeeze triceps hard',
        'Return under control',
      ],
    ),
    _Exercise(
      id: 'overhead-extension',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Dumbbell_Triceps_Extension/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Dumbbell_Triceps_Extension/1.jpg'],
      name: 'Overhead Extension',
      muscle: 'Triceps · Long Head',
      sets: [_SetSpec(12), _SetSpec(12), _SetSpec(10)],
      icon: Icons.fitness_center,
      steps: [
        'Hold one dumbbell overhead with both hands',
        'Lower behind the head, elbows pointing up',
        'Extend back up to lockout',
        'Keep elbows from flaring out',
      ],
    ),
    _Exercise(
      id: 'skull-crusher',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Triceps_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Triceps_Press/1.jpg'],
      name: 'Skull Crushers',
      muscle: 'Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Lie on a bench, bar over forehead',
        'Bend elbows to lower bar toward hairline',
        'Extend back up without moving elbows',
        'Control the descent',
      ],
    ),
    _Exercise(
      id: 'close-grip-bench',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Close-Grip_Barbell_Bench_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Close-Grip_Barbell_Bench_Press/1.jpg'],
      name: 'Close-Grip Bench Press',
      muscle: 'Triceps · Chest',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Grip the bar shoulder-width',
        'Lower to lower chest, elbows tucked',
        'Press up focusing on triceps',
        'Lock out under control',
      ],
    ),
    _Exercise(
      id: 'tricep-dips',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Triceps_Version/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Triceps_Version/1.jpg'],
      name: 'Tricep Dips',
      muscle: 'Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Grip parallel bars, torso upright',
        'Lower until elbows reach ~90°',
        'Press back up to lockout',
        'Keep elbows tracking backward',
      ],
    ),
    _Exercise(
      id: 'tricep-kickback',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Tricep_Dumbbell_Kickback/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Tricep_Dumbbell_Kickback/1.jpg'],
      name: 'Tricep Kickback',
      muscle: 'Triceps',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.fitness_center,
      steps: [
        'Hinge forward, upper arm parallel to floor',
        'Extend the forearm straight back',
        'Squeeze at full extension',
        'Lower slowly, keep elbow still',
      ],
    ),
    _Exercise(
      id: 'bench-dips',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Dips/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Dips/1.jpg'],
      name: 'Bench Dips',
      muscle: 'Triceps · Chest · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'For this exercise you will need to place a bench behind your back. With the bench perpendicular…',
        'Slowly lower your body as you inhale by bending at the elbows until you lower yourself far…',
        'Using your triceps to bring your torso up again, lift yourself back to the starting position',
        'Repeat for the recommended amount of repetitions',
      ],
    ),
    _Exercise(
      id: 'overhead-rope-extension',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Rope_Overhead_Triceps_Extension/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Rope_Overhead_Triceps_Extension/1.jpg'],
      name: 'Overhead Rope Extension',
      muscle: 'Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Attach a rope to the bottom pulley of the pulley machine',
        'Grasping the rope with both hands, extend your arms with your hands directly above your head…',
        'Slowly lower the rope behind your head as you hold the upper arms stationary. Inhale as you…',
        'Return to the starting position by flexing your triceps as you breathe out',
      ],
    ),
    _Exercise(
      id: 'triceps-extension-machine',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Triceps_Extension/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Triceps_Extension/1.jpg'],
      name: 'Triceps Extension Machine',
      muscle: 'Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Adjust the seat to the appropriate height and make your weight selection. Place your upper arms…',
        'Perform the movement by extending the elbow, pulling your lower arm away from your upper arm',
        'Pause at the completion of the movement, and then slowly return the weight to the starting…',
        'Avoid returning the weight all the way to the stops until the set is complete to keep tension…',
      ],
    ),
    _Exercise(
      id: 'reverse-grip-pushdown',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Grip_Triceps_Pushdown/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Grip_Triceps_Pushdown/1.jpg'],
      name: 'Reverse-Grip Pushdown',
      muscle: 'Triceps',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Start by setting a bar attachment (straight or e-z) on a high pulley machine',
        'Facing the bar attachment, grab it with the palms facing up (supinated grip) at shoulder width.…',
        'Slowly elevate the bar attachment up as you inhale so it is aligned with your chest. Only the…',
        'Then begin to lower the cable bar back down to the original staring position while exhaling and…',
      ],
    ),
    _Exercise(
      id: 'dip-machine',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dip_Machine/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dip_Machine/1.jpg'],
      name: 'Dip Machine',
      muscle: 'Triceps · Chest · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Sit securely in a dip machine, select the weight and firmly grasp the handles',
        'Now keep your elbows in at your sides in order to place emphasis on the triceps. The elbows…',
        'As you contract the triceps, extend your arms downwards as you exhale. Tip: At the bottom of…',
        'Now slowly let your arms come back up to the starting position as you inhale',
      ],
    ),
  ],
  'Arms': [
    _Exercise(
      id: 'wrist-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Palms-Up_Barbell_Wrist_Curl_Over_A_Bench/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Palms-Up_Barbell_Wrist_Curl_Over_A_Bench/1.jpg'],
      name: 'Wrist Curl',
      muscle: 'Forearms',
      sets: [_SetSpec(20, 10), _SetSpec(20, 10), _SetSpec(20, 10)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Rest forearms on thighs, palms up',
        'Let wrists drop to stretch the forearms',
        'Curl the wrists up as high as possible',
        'Lower slowly and repeat',
      ],
    ),
    _Exercise(
      id: 'reverse-wrist-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Palms-Down_Wrist_Curl_Over_A_Bench/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Palms-Down_Wrist_Curl_Over_A_Bench/1.jpg'],
      name: 'Reverse Wrist Curl',
      muscle: 'Forearm Extensors',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(15)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Forearms on thighs, palms facing down',
        'Let the wrists drop down',
        'Raise the backs of the hands up',
        'Lower with control',
      ],
    ),
    _Exercise(
      id: 'reverse-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Barbell_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Reverse_Barbell_Curl/1.jpg'],
      name: 'Reverse Curl',
      muscle: 'Forearms · Brachialis',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.fitness_center,
      steps: [
        'Hold the bar with an overhand grip',
        'Curl up keeping wrists firm',
        'Squeeze at the top',
        'Lower slowly',
      ],
    ),
    _Exercise(
      id: 'farmers-carry',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Farmers_Walk/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Farmers_Walk/1.jpg'],
      name: 'Farmer’s Carry',
      muscle: 'Forearms · Grip · Core',
      sets: [_SetSpec(1), _SetSpec(1), _SetSpec(1)],
      icon: Icons.fitness_center,
      steps: [
        'Hold a heavy dumbbell in each hand',
        'Stand tall, shoulders back, core braced',
        'Walk with short, controlled steps',
        'Set down under control',
      ],
    ),
    _Exercise(
      id: 'cable-wrist-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Wrist_Curl/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Wrist_Curl/1.jpg'],
      name: 'Cable Wrist Curl',
      muscle: 'Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Start out by placing a flat bench in front of a low pulley cable that has a straight bar…',
        'Use your arms to grab the cable bar with a narrow to shoulder width supinated grip (palms up)…',
        'Start out by curling your wrist upwards and exhaling. Keep the contraction for a second',
        'Slowly lower your wrists back down to the starting position while inhaling',
      ],
    ),
    _Exercise(
      id: 'finger-curls',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Finger_Curls/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Finger_Curls/1.jpg'],
      name: 'Finger Curls',
      muscle: 'Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Hold a barbell with both hands and your palms facing up; hands spaced about shoulder width',
        'Place your feet flat on the floor, at a distance that is slightly wider than shoulder width…',
        'Lower the bar as far as possible by extending the fingers. Allowing the bar to roll down the…',
        'Now curl bar up as high as possible by closing your hands while exhaling. Hold the contraction…',
      ],
    ),
    _Exercise(
      id: 'plate-pinch',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plate_Pinch/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plate_Pinch/1.jpg'],
      name: 'Plate Pinch',
      muscle: 'Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.back_hand,
      steps: [
        'Grab two wide-rimmed plates and put them together with the smooth sides facing outward',
        'Use your fingers to grip the outside part of the plate and your thumb for the other side thus…',
        'Squeeze the plate with your fingers and thumb. Hold this position for as long as you can',
        'Repeat for the recommended amount of sets prescribed in your program',
      ],
    ),
    _Exercise(
      id: 'wrist-roller',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wrist_Roller/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wrist_Roller/1.jpg'],
      name: 'Wrist Roller',
      muscle: 'Forearms · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'To begin, stand straight up grabbing a wrist roller using a pronated grip (palms facing down).…',
        'Slowly lift both arms until they are fully extended and parallel to the floor in front of you.…',
        'Rotate one wrist at a time in an upward motion to bring the weight up to the bar by rolling the…',
        'Once the weight has reached the bar, slowly begin to lower the weight back down by rotating the…',
      ],
    ),
  ],
  'Back': [
    _Exercise(
      id: 'deadlift',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/1.jpg'],
      name: 'Deadlift',
      muscle: 'Lower Back · Glutes · Hamstrings',
      sets: [_SetSpec(8), _SetSpec(6), _SetSpec(5)],
      icon: Icons.fitness_center,
      steps: [
        'Feet hip-width, bar over mid-foot',
        'Hinge at hips, grip just outside legs',
        'Drive through the floor, bar close to body',
        'Lock hips at the top, lower with control',
      ],
    ),
    _Exercise(
      id: 'pull-up',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pullups/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pullups/1.jpg'],
      name: 'Pull-Up',
      muscle: 'Lats · Upper Back',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Hang from the bar, hands past shoulder-width',
        'Pull chest toward the bar, drive elbows down',
        'Chin over the bar at the top',
        'Lower under control to a full hang',
      ],
    ),
    _Exercise(
      id: 'lat-pulldown',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/1.jpg'],
      name: 'Lat Pulldown',
      muscle: 'Lats',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.cable,
      steps: [
        'Grip the bar wider than shoulders',
        'Pull down to the upper chest',
        'Drive elbows down and back',
        'Return slowly to a full stretch',
      ],
    ),
    _Exercise(
      id: 'bent-over-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/1.jpg'],
      name: 'Bent-Over Row',
      muscle: 'Mid Back · Lats',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Hinge forward, back flat, bar hanging',
        'Row the bar to the lower ribs',
        'Squeeze the shoulder blades together',
        'Lower under control',
      ],
    ),
    _Exercise(
      id: 'seated-cable-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/1.jpg'],
      name: 'Seated Cable Row',
      muscle: 'Mid Back',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.cable,
      steps: [
        'Sit tall, slight lean, grab the handle',
        'Pull to the stomach, elbows close',
        'Squeeze the back at the end',
        'Return slowly, stretch the lats',
      ],
    ),
    _Exercise(
      id: 't-bar-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_T-Bar_Row/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_T-Bar_Row/1.jpg'],
      name: 'T-Bar Row',
      muscle: 'Mid Back · Lats',
      sets: [_SetSpec(10), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Straddle the bar, hinge forward',
        'Row the handle to the chest',
        'Squeeze the shoulder blades',
        'Lower with control',
      ],
    ),
    _Exercise(
      id: 'chin-up',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chin-Up/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chin-Up/1.jpg'],
      name: 'Chin-Up',
      muscle: 'Lats · Biceps · Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Grab the pull-up bar with the palms facing your torso and a grip closer than the shoulder width',
        'As you have both arms extended in front of you holding the bar at the chosen grip width, keep…',
        'As you breathe out, pull your torso up until your head is around the level of the pull-up bar.…',
        'After a second of squeezing the biceps in the contracted position, slowly lower your torso back…',
      ],
    ),
    _Exercise(
      id: 'one-arm-dumbbell-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/One-Arm_Dumbbell_Row/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/One-Arm_Dumbbell_Row/1.jpg'],
      name: 'One-Arm Dumbbell Row',
      muscle: 'Middle Back · Biceps · Lats',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Choose a flat bench and place a dumbbell on each side of it',
        'Place the right leg on top of the end of the bench, bend your torso forward from the waist…',
        'Use the left hand to pick up the dumbbell on the floor and hold the weight while keeping your…',
        'Pull the resistance straight up to the side of your chest, keeping your upper arm close to your…',
      ],
    ),
    _Exercise(
      id: 'inverted-row',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Inverted_Row/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Inverted_Row/1.jpg'],
      name: 'Inverted Row',
      muscle: 'Middle Back · Lats',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Position a bar in a rack to about waist height. You can also use a smith machine',
        'Take a wider than shoulder width grip on the bar and position yourself hanging underneath the…',
        'Begin by flexing the elbow, pulling your chest towards the bar. Retract your shoulder blades as…',
        'Pause at the top of the motion, and return yourself to the start position',
      ],
    ),
    _Exercise(
      id: 'sumo-deadlift',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sumo_Deadlift/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sumo_Deadlift/1.jpg'],
      name: 'Sumo Deadlift',
      muscle: 'Hamstrings · Adductors · Forearms',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Begin with a bar loaded on the ground. Approach the bar so that the bar intersects the middle…',
        'Take a breath, and then lower your hips, looking forward with your head with your chest up.…',
        'As the bar passes through the knees, lean back and drive the hips into the bar, pulling your…',
        'Return the weight to the ground by bending at the hips and controlling the weight on the way…',
      ],
    ),
    _Exercise(
      id: 'back-extension',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hyperextensions_Back_Extensions/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hyperextensions_Back_Extensions/1.jpg'],
      name: 'Back Extension',
      muscle: 'Lower Back · Glutes · Hamstrings',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Lie face down on a hyperextension bench, tucking your ankles securely under the footpads',
        'Adjust the upper pad if possible so your upper thighs lie flat across the wide pad, leaving…',
        'With your body straight, cross your arms in front of you (my preference) or behind your head.…',
        'Start bending forward slowly at the waist as far as you can while keeping your back flat.…',
      ],
    ),
  ],
  'Abs': [
    _Exercise(
      id: 'crunches',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Crunches/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Crunches/1.jpg'],
      name: 'Crunches',
      muscle: 'Rectus Abdominis',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(20)],
      icon: Icons.grid_view,
      steps: [
        'Lie on back, knees bent, hands light behind head',
        'Exhale and lift shoulder blades off the floor',
        'Hold briefly, do not pull the neck',
        'Lower slowly',
      ],
    ),
    _Exercise(
      id: 'plank',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/1.jpg'],
      name: 'Plank',
      muscle: 'Core · Transverse Abdominis',
      sets: [_SetSpec(1), _SetSpec(1), _SetSpec(1)],
      icon: Icons.self_improvement,
      steps: [
        'Forearms down, body in a straight line',
        'Brace the core and squeeze glutes',
        'Hold the position, breathe steadily',
        'Do not let the hips sag or pike',
      ],
    ),
    _Exercise(
      id: 'leg-raises',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Leg_Raises/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Leg_Raises/1.jpg'],
      name: 'Leg Raises',
      muscle: 'Lower Abs',
      sets: [_SetSpec(15), _SetSpec(15), _SetSpec(12)],
      icon: Icons.grid_view,
      steps: [
        'Lie flat, legs straight, hands at sides',
        'Raise legs to vertical, keep them straight',
        'Lower slowly without touching the floor',
        'Keep the lower back pressed down',
      ],
    ),
    _Exercise(
      id: 'russian-twist',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Russian_Twist/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Russian_Twist/1.jpg'],
      name: 'Russian Twist',
      muscle: 'Obliques',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(20)],
      icon: Icons.grid_view,
      steps: [
        'Sit, lean back slightly, feet off the floor',
        'Rotate the torso side to side',
        'Tap the floor by each hip',
        'Keep the movement controlled',
      ],
    ),
    _Exercise(
      id: 'bicycle-crunch',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Air_Bike/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Air_Bike/1.jpg'],
      name: 'Bicycle Crunch',
      muscle: 'Abs · Obliques',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(20)],
      icon: Icons.grid_view,
      steps: [
        'Lie back, hands behind head, legs up',
        'Bring opposite elbow to opposite knee',
        'Extend the other leg out',
        'Alternate in a smooth pedaling motion',
      ],
    ),
    _Exercise(
      id: 'mountain-climbers',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Mountain_Climbers/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Mountain_Climbers/1.jpg'],
      name: 'Mountain Climbers',
      muscle: 'Core · Cardio',
      sets: [_SetSpec(30), _SetSpec(30), _SetSpec(30)],
      icon: Icons.self_improvement,
      steps: [
        'Start in a high plank, hands under shoulders',
        'Drive one knee toward the chest',
        'Switch legs quickly',
        'Keep the hips level and core tight',
      ],
    ),
    _Exercise(
      id: 'hanging-leg-raise',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hanging_Leg_Raise/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hanging_Leg_Raise/1.jpg'],
      name: 'Hanging Leg Raise',
      muscle: 'Lower Abs',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Hang from a bar, arms straight',
        'Raise the legs toward parallel or higher',
        'Avoid swinging the body',
        'Lower slowly with control',
      ],
    ),
    _Exercise(
      id: 'sit-up',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sit-Up/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sit-Up/1.jpg'],
      name: 'Sit-Up',
      muscle: 'Abdominals',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.self_improvement,
      steps: [
        'Lie down on the floor placing your feet either under something that will not move or by having…',
        'Place your hands behind your head and lock them together by clasping your fingers. This is the…',
        'Elevate your upper body so that it creates an imaginary V-shape with your thighs. Breathe out…',
        'Once you feel the contraction for a second, lower your upper body back down to the starting…',
      ],
    ),
    _Exercise(
      id: 'cable-crunch',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crunch/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crunch/1.jpg'],
      name: 'Cable Crunch',
      muscle: 'Abdominals',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.cable,
      steps: [
        'Kneel below a high pulley that contains a rope attachment',
        'Grasp cable rope attachment and lower the rope until your hands are placed next to your face',
        'Flex your hips slightly and allow the weight to hyperextend the lower back. This will be your…',
        'With the hips stationary, flex the waist as you contract the abs so that the elbows travel…',
      ],
    ),
    _Exercise(
      id: 'flutter-kicks',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Flutter_Kicks/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Flutter_Kicks/1.jpg'],
      name: 'Flutter Kicks',
      muscle: 'Glutes · Hamstrings',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.self_improvement,
      steps: [
        'On a flat bench lie facedown with the hips on the edge of the bench, the legs straight with…',
        'Squeeze your glutes and hamstrings and straighten the legs until they are level with the hips.…',
        'Start the movement by lifting the left leg higher than the right leg',
        'Then lower the left leg as you lift the right leg',
      ],
    ),
    _Exercise(
      id: 'ab-crunch-machine',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Ab_Crunch_Machine/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Ab_Crunch_Machine/1.jpg'],
      name: 'Ab Crunch Machine',
      muscle: 'Abdominals',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Select a light resistance and sit down on the ab machine placing your feet under the pads…',
        'At the same time, begin to lift the legs up as you crunch your upper torso. Breathe out as you…',
        'After a second pause, slowly return to the starting position as you breathe in',
        'Repeat the movement for the prescribed amount of repetitions',
      ],
    ),
    _Exercise(
      id: 'toe-touches',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Toe_Touchers/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Toe_Touchers/1.jpg'],
      name: 'Toe Touches',
      muscle: 'Abdominals',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.self_improvement,
      steps: [
        'To begin, lie down on the floor or an exercise mat with your back pressed against the floor.…',
        'Your legs should be touching each other. Slowly elevate your legs up in the air until they are…',
        'Move your arms so that they are fully extended at a 45 degree angle from the floor. This is the…',
        'While keeping your lower back pressed against the floor, slowly lift your torso and use your…',
      ],
    ),
  ],
  'Legs': [
    _Exercise(
      id: 'squat',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Squat/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Squat/1.jpg'],
      name: 'Barbell Squat',
      muscle: 'Quads · Glutes · Hamstrings',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.directions_walk,
      steps: [
        'Bar on upper traps, stance shoulder-width',
        'Brace core, push knees out as you descend',
        'Lower until thighs are at least parallel',
        'Drive through heels, squeeze glutes at top',
      ],
    ),
    _Exercise(
      id: 'leg-press',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/1.jpg'],
      name: 'Leg Press',
      muscle: 'Quads · Glutes',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.directions_walk,
      steps: [
        'Feet shoulder-width on the platform',
        'Lower until knees reach ~90°',
        'Press through the whole foot',
        'Do not lock the knees harshly',
      ],
    ),
    _Exercise(
      id: 'lunges',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Walking_Lunge/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Walking_Lunge/1.jpg'],
      name: 'Walking Lunges',
      muscle: 'Quads · Glutes',
      sets: [_SetSpec(12), _SetSpec(12), _SetSpec(10)],
      icon: Icons.directions_walk,
      steps: [
        'Step forward into a lunge, torso upright',
        'Lower until the back knee nearly touches',
        'Push through the front heel to stand',
        'Alternate legs each rep',
      ],
    ),
    _Exercise(
      id: 'romanian-deadlift',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/1.jpg'],
      name: 'Romanian Deadlift',
      muscle: 'Hamstrings · Glutes',
      sets: [_SetSpec(10), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Hold the bar, slight knee bend',
        'Hinge at the hips, bar close to legs',
        'Feel the hamstring stretch, back flat',
        'Drive hips forward to stand tall',
      ],
    ),
    _Exercise(
      id: 'leg-curl',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/1.jpg'],
      name: 'Leg Curl',
      muscle: 'Hamstrings',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.directions_walk,
      steps: [
        'Lie or sit on the machine, pad at ankles',
        'Curl the heels toward the glutes',
        'Squeeze the hamstrings at the top',
        'Lower slowly',
      ],
    ),
    _Exercise(
      id: 'leg-extension',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/1.jpg'],
      name: 'Leg Extension',
      muscle: 'Quads',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.directions_walk,
      steps: [
        'Sit, pad against the lower shins',
        'Extend the legs to straight',
        'Squeeze the quads at the top',
        'Lower under control',
      ],
    ),
    _Exercise(
      id: 'calf-raise',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/1.jpg'],
      name: 'Standing Calf Raise',
      muscle: 'Calves',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(15)],
      icon: Icons.directions_walk,
      steps: [
        'Balls of feet on a step, heels hanging',
        'Rise up onto the toes as high as possible',
        'Squeeze the calves at the top',
        'Lower slowly for a deep stretch',
      ],
    ),
    _Exercise(
      id: 'front-squat',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Barbell_Squat/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Barbell_Squat/1.jpg'],
      name: 'Front Squat',
      muscle: 'Quadriceps · Calves · Glutes',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'This exercise is best performed inside a squat rack for safety purposes. To begin, first set…',
        'Lift the bar off the rack by first pushing with your legs and at the same time straightening…',
        'Step away from the rack and position your legs using a shoulder width medium stance with the…',
        'Begin to slowly lower the bar by bending the knees as you maintain a straight posture with the…',
      ],
    ),
    _Exercise(
      id: 'goblet-squat',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/1.jpg'],
      name: 'Goblet Squat',
      muscle: 'Quadriceps · Calves · Glutes',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Stand holding a light kettlebell by the horns close to your chest. This will be your starting…',
        'Squat down between your legs until your hamstrings are on your calves. Keep your chest and head…',
        'At the bottom position, pause and use your elbows to push your knees out. Return to the…',
      ],
    ),
    _Exercise(
      id: 'bulgarian-split-squat',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Split_Squat_with_Dumbbells/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Split_Squat_with_Dumbbells/1.jpg'],
      name: 'Bulgarian Split Squat',
      muscle: 'Quadriceps · Glutes · Hamstrings',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Position yourself into a staggered stance with the rear foot elevated and front foot forward',
        'Hold a dumbbell in each hand, letting them hang at the sides. This will be your starting…',
        'Begin by descending, flexing your knee and hip to lower your body down. Maintain good posture…',
        'At the bottom of the movement, drive through the heel to extend the knee and hip to return to…',
      ],
    ),
    _Exercise(
      id: 'hip-thrust',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/1.jpg'],
      name: 'Hip Thrust',
      muscle: 'Glutes · Calves · Hamstrings',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Begin seated on the ground with a bench directly behind you. Have a loaded barbell over your…',
        'Roll the bar so that it is directly above your hips, and lean back against the bench so that…',
        'Begin the movement by driving through your feet, extending your hips vertically through the…',
      ],
    ),
    _Exercise(
      id: 'hack-squat',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hack_Squat/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hack_Squat/1.jpg'],
      name: 'Hack Squat',
      muscle: 'Quadriceps · Calves · Glutes',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Place the back of your torso against the back pad of the machine and hook your shoulders under…',
        'Position your legs in the platform using a shoulder width medium stance with the toes slightly…',
        'Place your arms on the side handles of the machine and disengage the safety bars (which on most…',
        'Now straighten your legs without locking the knees. This will be your starting position. (Note:…',
      ],
    ),
    _Exercise(
      id: 'seated-calf-raise',
      images: ['https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Calf_Raise/0.jpg', 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Calf_Raise/1.jpg'],
      name: 'Seated Calf Raise',
      muscle: 'Calves',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Sit on the machine and place your toes on the lower portion of the platform provided with the…',
        'Place your lower thighs under the lever pad, which will need to be adjusted according to the…',
        'Lift the lever slightly by pushing your heels up and release the safety bar. This will be your…',
        'Slowly lower your heels by bending at the ankles until the calves are fully stretched. Inhale…',
      ],
    ),
  ],
};
