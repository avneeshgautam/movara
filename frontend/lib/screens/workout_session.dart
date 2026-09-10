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
                return GestureDetector(
                  onTap: () => setState(() => _active = cat),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: active ? c.accent : c.surface2,
                      border: Border.all(color: active ? c.accent : c.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cat,
                      style: AppTheme.display(
                        color: active ? Colors.white : c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
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
    required this.onLogSet,
    required this.onUnlogSet,
  });

  final _Exercise exercise;
  final List<WorkoutEntry> todayEntries;
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
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ex.icon, color: c.accent, size: 22),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: s.done ? c.accentSoft : c.surface2,
        border: Border.all(color: s.done ? c.accent.withValues(alpha: 0.35) : c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Done toggle.
          GestureDetector(
            onTap: () => _toggleDone(i),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.done ? c.accent : c.surface3,
                shape: BoxShape.circle,
                border: Border.all(color: s.done ? c.accent : c.border, width: 1.5),
              ),
              child: s.done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text(
              'Set ${i + 1}',
              style: AppTheme.display(
                color: s.done ? c.accent : c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _roundBtn(context, '−', () => _changeReps(i, -1), c.textSecondary),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _editReps(i),
            child: Container(
              constraints: const BoxConstraints(minWidth: 34),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(width: 6),
          _roundBtn(context, '+', () => _changeReps(i, 1), c.accent),
          const Spacer(),
          // Weight control.
          _roundBtn(context, '−', () => _changeWeight(i, -0.5), c.textSecondary),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _editWeight(i),
            child: Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 3),
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
          const SizedBox(width: 6),
          _roundBtn(context, '+', () => _changeWeight(i, 0.5), c.accent),
          // Removable down to a single set, so 1–2-set workouts are easy.
          if (_sets.length > 1) ...[
            const SizedBox(width: 6),
            _roundBtn(context, '×', () => _removeSet(i), c.textMuted),
          ],
        ],
      ),
    );
  }

  Widget _roundBtn(BuildContext context, String label, VoidCallback onTap, Color fg) {
    final c = context.movara;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
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
          // Figure area.
          Container(
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(widget.exercise.icon, size: 56, color: c.accent.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 10),
          // Step dots.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _step ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _step ? c.accent : c.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          // Step content.
          Container(
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
                    style: AppTheme.display(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[_step],
                    style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.4),
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
                  onTap: () => setState(() => _step--),
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
                        onTap: () => setState(() => _step++),
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

// ── Data ────────────────────────────────────────────────────────────

class _Exercise {
  const _Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.steps,
    required this.icon,
  });

  final String id;
  final String name;
  final String muscle;
  final List<_SetSpec> sets;
  final List<String> steps;
  final IconData icon;
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

const _workoutData = <String, List<_Exercise>>{
  'Chest': [
    _Exercise(
      id: 'bench-press',
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
  ],
  'Shoulders': [
    _Exercise(
      id: 'overhead-press',
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
  ],
  'Bicep': [
    _Exercise(
      id: 'barbell-curl',
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
  ],
  'Tricep': [
    _Exercise(
      id: 'tricep-pushdown',
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
  ],
  'Arms': [
    _Exercise(
      id: 'wrist-curl',
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
  ],
  'Back': [
    _Exercise(
      id: 'deadlift',
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
  ],
  'Abs': [
    _Exercise(
      id: 'crunches',
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
  ],
  'Legs': [
    _Exercise(
      id: 'squat',
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
  ],
};
