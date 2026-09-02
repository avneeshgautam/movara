import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Category-based workout session screen, ported from the React `WorkoutPage`
/// design: horizontal category tabs, exercise cards with per-set reps/weight
/// tracking and a step-by-step demo sheet.
///
/// Reps, weight and set add/remove are local session state (as in the source).
/// Marking a set "done" logs it to the backend via [onLogSet]; un-checking
/// removes it via [onUnlogSet], so the Home dashboard stays in sync.
class WorkoutSession extends StatefulWidget {
  const WorkoutSession({
    super.key,
    required this.onLogSet,
    required this.onUnlogSet,
  });

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
    'Bicep',
    'Tricep',
    'Arms',
    'Back',
    'Abs',
    'Legs',
  ];

  String _active = 'Chest';

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final exercises = _workoutData[_active] ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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

          // Exercise list.
          Expanded(
            child: exercises.isEmpty
                ? _EmptyCategory(category: _active)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _ExerciseCard(
                      exercise: exercises[i],
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
    required this.exercise,
    required this.onLogSet,
    required this.onUnlogSet,
  });

  final _Exercise exercise;
  final Future<String?> Function(String, int, double) onLogSet;
  final Future<void> Function(String) onUnlogSet;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late List<_SetState> _sets;

  @override
  void initState() {
    super.initState();
    _sets = widget.exercise.sets
        .map((s) => _SetState(reps: s.reps, weight: s.weight))
        .toList();
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
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(ex.icon, color: c.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: AppTheme.display(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ex.muscle,
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showDemo(context, ex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              ],
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
          Text('Reps ', style: TextStyle(color: c.textMuted, fontSize: 12)),
          GestureDetector(
            onTap: () => _editReps(i),
            child: Container(
              constraints: const BoxConstraints(minWidth: 30),
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
          const Spacer(),
          // Weight control.
          _roundBtn(context, '−', () => _changeWeight(i, -0.5), c.textSecondary),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _editWeight(i),
            child: Container(
              width: 54,
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
        'Press bar upward in a slight arc until arms lock out',
        'Repeat for reps, keep core tight throughout',
      ],
    ),
    _Exercise(
      id: 'chest-press',
      name: 'Chest Press Machine',
      muscle: 'Chest · Anterior Deltoid',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Sit with back flat against pad, grip handles at chest height',
        'Press handles forward until arms are almost fully extended',
        'Slowly bring handles back, feel the chest stretch',
        'Keep shoulders down and avoid shrugging',
      ],
    ),
    _Exercise(
      id: 'incline-db',
      name: 'Incline Dumbbell Press',
      muscle: 'Upper Chest · Shoulders',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.fitness_center,
      steps: [
        'Set bench to 30–45° incline, hold dumbbells at chest level',
        'Press dumbbells upward and slightly inward',
        'Lower with control back to starting position',
        'Keep wrists stacked over elbows throughout',
      ],
    ),
    _Exercise(
      id: 'cable-fly',
      name: 'Cable Fly',
      muscle: 'Chest · Inner Pec',
      sets: [_SetSpec(15), _SetSpec(12), _SetSpec(12)],
      icon: Icons.cable,
      steps: [
        'Stand centered between cable towers, cables at chest height',
        'Step forward slightly, bend elbows softly',
        'Bring handles together in a wide arc in front of chest',
        'Squeeze at the peak, slowly open back out',
      ],
    ),
    _Exercise(
      id: 'push-up',
      name: 'Push-Up',
      muscle: 'Chest · Triceps · Core',
      sets: [_SetSpec(20), _SetSpec(20), _SetSpec(15)],
      icon: Icons.accessibility_new,
      steps: [
        'Start in high plank — hands shoulder-width, body straight',
        'Bend elbows to lower chest to just above floor',
        'Press up explosively, fully extending arms',
        'Maintain rigid core and neutral spine throughout',
      ],
    ),
    _Exercise(
      id: 'decline-press',
      name: 'Decline Bench Press',
      muscle: 'Lower Chest · Triceps',
      sets: [_SetSpec(10), _SetSpec(8), _SetSpec(6)],
      icon: Icons.fitness_center,
      steps: [
        'Secure feet, lie on decline bench, grip bar wider than shoulders',
        'Unrack bar, lower it to lower chest',
        'Drive the bar back up in a controlled arc',
        "Lock out at the top but don't hyperextend elbows",
      ],
    ),
  ],
  'Bicep': [
    _Exercise(
      id: 'bb-curl',
      name: 'Barbell Curl',
      muscle: 'Biceps · Brachialis',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(8)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Stand upright, hold barbell with underhand grip shoulder-width',
        'Keep elbows tucked at sides, curl bar toward shoulders',
        "Squeeze biceps at the top, don't swing",
        'Lower slowly under control for full stretch',
      ],
    ),
    _Exercise(
      id: 'hammer-curl',
      name: 'Hammer Curl',
      muscle: 'Biceps · Brachioradialis',
      sets: [_SetSpec(12), _SetSpec(10), _SetSpec(10)],
      icon: Icons.sports_gymnastics,
      steps: [
        'Hold dumbbells with neutral (hammer) grip at sides',
        'Curl dumbbells toward shoulders, thumbs facing up',
        'Hold briefly at top, lower with control',
        'Alternate arms or do both simultaneously',
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
        'Stand at cable machine, grab bar with overhand grip',
        'Keep elbows pinned to sides, push bar down until arms extend',
        'Squeeze triceps at lockout',
        'Slowly let bar rise back to starting position',
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
        'Sit, rest forearms on thighs, palms facing up, hold dumbbells',
        'Let wrists drop down fully to stretch forearms',
        'Curl wrists upward as high as possible',
        'Lower slowly and repeat',
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
        'Stand with feet hip-width, bar over mid-foot',
        'Hinge at hips, grip bar just outside legs',
        'Drive through floor, keeping bar close to body',
        'Lock out hips at top, lower bar with control',
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
        'Lie on back, knees bent, hands behind head lightly',
        'Exhale and crunch up, lifting shoulder blades off floor',
        "Hold briefly at top, don't pull neck",
        'Inhale slowly back down',
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
        'Bar rests on upper traps, stance shoulder-width or wider',
        'Brace core, push knees out as you descend',
        'Lower until thighs are parallel (or below) to floor',
        'Drive through heels to stand, squeeze glutes at top',
      ],
    ),
  ],
};
