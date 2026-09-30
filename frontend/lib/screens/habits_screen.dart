import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import '../widgets/celebration.dart';
import '../widgets/habit_widgets.dart';

/// Celebrates a check-in that reached a goal. Shared by Home and Habits.
void celebrateCheckIn(BuildContext context, CheckIn r, HabitStore store) {
  final h = r.habit;
  final now = DateTime.now();
  if (r.allDoneToday) {
    final p = store.todayProgress();
    showCelebration(context,
        emoji: '🏆',
        big: true,
        title: 'All habits done!',
        subtitle: 'Perfect day — ${p.done}/${p.total} complete. See you tomorrow!');
  } else if (r.weekGoalReached) {
    showCelebration(context,
        emoji: h.emoji,
        title: 'Weekly goal hit!',
        subtitle: '${h.name} · ${h.timesPerWeek}× this week 🔥');
  } else if (r.completedToday) {
    final s = h.currentStreak(now);
    showCelebration(context,
        emoji: h.emoji,
        title: '${h.name} done!',
        subtitle: s > 1
            ? '🔥 $s-${h.streakUnit} streak — keep it going!'
            : 'Great start — come back tomorrow to build a streak.');
  }
}

/// What the editor returns: the edited habit, or a request to delete it.
typedef HabitEdit = ({Habit habit, bool delete});

Future<void> openHabitEditor(BuildContext context, HabitStore store,
    {Habit? existing, Habit? template}) async {
  final result = await Navigator.of(context).push<HabitEdit>(MaterialPageRoute(
    builder: (_) => HabitEditorScreen(existing: existing, template: template),
  ));
  if (result == null) return;
  if (result.delete) {
    await store.remove(result.habit.id);
  } else if (existing == null) {
    await store.add(result.habit);
  } else {
    await store.update(result.habit);
  }
}

void openHabitDetail(BuildContext context, HabitStore store, Habit habit) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => HabitDetailScreen(store: store, habitId: habit.id),
  ));
}

/// All habits: today's check-ins, the week at a glance, reordering,
/// templates and archive.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key, required this.store, this.embedded = false});

  final HabitStore store;

  /// True when shown as a bottom tab: the shell already draws the Movara
  /// header, so this screen drops its own app bar.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: c.textPrimary),
              title: Text('Habits',
                  style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('habit-new'),
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        onPressed: () => openHabitEditor(context, store),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final today = DateTime.now();
          final habits = store.habits;
          final p = store.todayProgress();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: habits.isEmpty
                      ? _EmptyHabits(store: store)
                      : Text(
                          p.total == 0
                              ? 'Nothing due today — enjoy the rest day.'
                              : '${p.done} of ${p.total} done today · hold a habit to see its stats, drag to reorder',
                          style: TextStyle(color: c.textMuted, fontSize: 12)),
                ),
              ),
              if (habits.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverReorderableList(
                    itemCount: habits.length,
                    onReorderItem: store.reorder,
                    itemBuilder: (context, i) {
                      final h = habits[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey('habit-card-${h.id}'),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HabitCard(store: store, habit: h, today: today),
                        ),
                      );
                    },
                  ),
                ),
              if (habits.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Templates(store: store, compact: true),
                  ),
                ),
              if (store.archived.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(child: _Archived(store: store)),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.store, required this.habit, required this.today});

  final HabitStore store;
  final Habit habit;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          HabitRow(
            habit: habit,
            day: today,
            onCheckIn: () async {
              final r = await store.checkIn(habit.id);
              if (context.mounted) celebrateCheckIn(context, r, store);
            },
            onUndo: () => store.undo(habit.id),
            onOpen: () => openHabitDetail(context, store, habit),
          ),
          InkWell(
            onTap: () => openHabitDetail(context, store, habit),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
              child: Row(
                children: [
                  WeekStrip(habit: habit, today: today),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(habit.scheduleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 11)),
                        Text('Best ${habit.bestStreak(today)}',
                            maxLines: 1,
                            style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits({required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('🌱', style: TextStyle(fontSize: 34)),
        const SizedBox(height: 8),
        Text('Build habits that stick',
            style: AppTheme.display(color: c.textPrimary, fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          'Start small. Pick one below or create your own — then tap it each '
          'time you do it and watch your streak grow.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        _Templates(store: store, compact: false),
      ],
    );
  }
}

/// One-tap starter habits the user hasn't added yet.
class _Templates extends StatelessWidget {
  const _Templates({required this.store, required this.compact});

  final HabitStore store;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final have = {
      for (final h in [...store.habits, ...store.archived]) h.name.toLowerCase()
    };
    final left =
        HabitStore.templates.where((t) => !have.contains(t.name.toLowerCase()));
    if (left.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(compact ? 'QUICK ADD' : 'POPULAR HABITS',
            style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, t) in left.indexed)
              ActionChip(
                key: ValueKey('habit-template-${t.name}'),
                backgroundColor: c.surface,
                side: BorderSide(color: c.border),
                avatar: Text(t.emoji),
                label: Text(
                    t.unit == null ? t.name : '${t.name} · ${t.target} ${t.unit}',
                    style: TextStyle(color: c.textPrimary, fontSize: 12)),
                onPressed: () => store.add(Habit(
                  id: '',
                  name: t.name,
                  createdAt: DateTime.now(),
                  emoji: t.emoji,
                  color: (store.habits.length + i) % habitPalette.length,
                  targetPerDay: t.target,
                  unit: t.unit,
                )),
              ),
          ],
        ),
      ],
    );
  }
}

class _Archived extends StatelessWidget {
  const _Archived({required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Archived (${store.archived.length})',
          style: TextStyle(color: c.textSecondary, fontSize: 13)),
      children: [
        for (final h in store.archived)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(h.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(h.name, style: TextStyle(color: c.textPrimary)),
            subtitle: Text('Best streak ${h.bestStreak(DateTime.now())}',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
            trailing: TextButton(
              onPressed: () => store.setArchived(h.id, false),
              child: Text('Restore', style: TextStyle(color: c.accent)),
            ),
          ),
      ],
    );
  }
}

// ── Editor ─────────────────────────────────────────────────────────────

class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({super.key, this.existing, this.template});

  final Habit? existing;
  final Habit? template;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  static const emojis = [
    '✅', '💧', '🧘', '📖', '🚶', '🏃', '🏋️', '🤸', '😴', '✍️', '🥗', '🍎',
    '💊', '🦷', '🧠', '🎯', '📵', '☀️', '🌙', '🙏', '🎸', '💻', '🧹', '💰',
  ];

  late final Habit _seed = widget.existing ??
      widget.template ??
      Habit(id: '', name: '', createdAt: DateTime.now());
  late final _name = TextEditingController(text: _seed.name);
  late final _tiny = TextEditingController(text: _seed.tinyVersion ?? '');
  late final _unit = TextEditingController(text: _seed.unit ?? '');
  late String _emoji = _seed.emoji;
  late int _color = _seed.color;
  late int _target = _seed.targetPerDay;
  late HabitFrequency _frequency = _seed.frequency;
  late Set<int> _days = {..._seed.days};
  late int _perWeek = _seed.timesPerWeek;
  late int? _reminder = _seed.reminderMinute;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _tiny.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give your habit a name.');
      return;
    }
    if (_frequency == HabitFrequency.specificDays && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one day.')));
      return;
    }
    final unit = _unit.text.trim();
    final tiny = _tiny.text.trim();
    Navigator.pop<HabitEdit>(
      context,
      (delete: false, habit: _seed.copyWith(
        name: name,
        emoji: _emoji,
        color: _color,
        targetPerDay: _target,
        unit: _target > 1 && unit.isNotEmpty ? unit : null,
        clearUnit: _target <= 1 || unit.isEmpty,
        tinyVersion: tiny.isEmpty ? null : tiny,
        clearTinyVersion: tiny.isEmpty,
        frequency: _frequency,
        days: _days,
        timesPerWeek: _perWeek,
        reminderMinute: _reminder,
        clearReminder: _reminder == null,
      )),
    );
  }

  Future<void> _pickReminder() async {
    final m = _reminder ?? 8 * 60;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t != null) setState(() => _reminder = t.hour * 60 + t.minute);
  }

  Future<void> _confirmDelete() async {
    final c = context.movara;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Delete habit?'),
        content: const Text(
            'This removes the habit and its whole history. Archive instead to keep the history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop<HabitEdit>(context, (delete: true, habit: _seed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final color = habitPalette[_color % habitPalette.length];

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        );

    Widget stepper(int value, int min, int max, ValueChanged<int> onChanged, String label) =>
        Row(
          children: [
            IconButton.outlined(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 44,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: AppTheme.display(
                      color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            IconButton.outlined(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13))),
          ],
        );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(_isEdit ? 'Edit habit' : 'New habit',
            style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
        actions: [
          TextButton(
            key: const ValueKey('habit-save'),
            onPressed: _save,
            child: Text('Save',
                style: AppTheme.display(
                    color: c.accent, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Text(_emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  key: const ValueKey('habit-name'),
                  controller: _name,
                  autofocus: !_isEdit && widget.template == null,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 40,
                  style: TextStyle(color: c.textPrimary, fontSize: 17),
                  onChanged: (_) => setState(() => _nameError = null),
                  decoration: InputDecoration(
                    hintText: 'e.g. Meditate',
                    errorText: _nameError,
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          section(
            'ICON',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in emojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? color.withValues(alpha: 0.2) : c.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: e == _emoji ? color : c.border),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
          section(
            'COLOUR',
            Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < habitPalette.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: habitPalette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: i == _color ? c.textPrimary : Colors.transparent,
                            width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          section(
            'DAILY GOAL',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stepper(_target, 1, 50, (v) => setState(() => _target = v),
                    _target == 1 ? 'time a day' : 'times a day'),
                if (_target > 1)
                  TextField(
                    controller: _unit,
                    maxLength: 16,
                    style: TextStyle(color: c.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Unit (optional)',
                        hintText: 'glasses, pages, minutes…',
                        counterText: ''),
                  ),
              ],
            ),
          ),
          section(
            'HOW OFTEN',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chips wrap onto a second line on narrow phones; a
                // segmented button can't shrink and overflowed.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (f, label) in const [
                      (HabitFrequency.daily, 'Every day'),
                      (HabitFrequency.specificDays, 'Some days'),
                      (HabitFrequency.timesPerWeek, '× a week'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _frequency == f,
                        showCheckmark: false,
                        selectedColor: color.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _frequency = f),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_frequency == HabitFrequency.specificDays)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1]),
                          selected: _days.contains(d),
                          selectedColor: color.withValues(alpha: 0.25),
                          onSelected: (on) => setState(() {
                            _days = {..._days};
                            on ? _days.add(d) : _days.remove(d);
                          }),
                        ),
                    ],
                  ),
                if (_frequency == HabitFrequency.timesPerWeek)
                  stepper(_perWeek, 1, 7, (v) => setState(() => _perWeek = v),
                      'days a week, any days — streaks count in weeks'),
              ],
            ),
          ),
          section(
            'TINY VERSION (OPTIONAL)',
            TextField(
              controller: _tiny,
              maxLength: 40,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                hintText: 'The smallest step that still counts — e.g. 1 push-up',
                counterText: '',
              ),
            ),
          ),
          section(
            'REMINDER',
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: c.accent,
              title: Text(
                  _reminder == null
                      ? 'Off'
                      : MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay(hour: _reminder! ~/ 60, minute: _reminder! % 60)),
                  style: TextStyle(color: c.textPrimary)),
              subtitle: Text(
                  kIsWeb
                      ? 'Reminders arrive in the phone app.'
                      : _frequency == HabitFrequency.specificDays
                          ? 'On the days you picked'
                          : 'Every day',
                  style: TextStyle(color: c.textMuted, fontSize: 12)),
              value: _reminder != null,
              onChanged: (on) async {
                if (on) {
                  await _pickReminder();
                } else {
                  setState(() => _reminder = null);
                }
              },
            ),
          ),
          if (_reminder != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _pickReminder, child: const Text('Change time')),
            ),
          if (_isEdit) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop<HabitEdit>(
                  context, (delete: false, habit: _seed.copyWith(archived: true))),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive (keep history)'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              label: const Text('Delete habit', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Detail ─────────────────────────────────────────────────────────────

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({super.key, required this.store, required this.habitId});

  final HabitStore store;
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final h = store.byId(habitId);
        if (h == null) return const SizedBox.shrink();
        final today = DateTime.now();
        final color = habitColor(h);

        Widget stat(String label, String value) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: AppTheme.display(
                              color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );

        final unit = h.streakUnit == 'week' ? 'wk' : 'd';
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: Text(h.name, style: AppTheme.display(color: c.textPrimary, fontSize: 18)),
            actions: [
              IconButton(
                key: const ValueKey('habit-edit'),
                icon: Icon(Icons.edit_outlined, color: c.textPrimary),
                onPressed: () async {
                  await openHabitEditor(context, store, existing: h);
                  // Deleted or archived: nothing left to show here.
                  final now = store.byId(h.id);
                  if ((now == null || now.archived) && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(
                children: [
                  HabitRing(habit: h, day: today, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.scheduleLabel,
                            style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        if (h.targetPerDay > 1)
                          Text(
                              'Goal: ${h.targetPerDay}${h.unit != null ? ' ${h.unit}' : '×'} a day',
                              style: TextStyle(color: c.textMuted, fontSize: 12)),
                        if (h.tinyVersion?.isNotEmpty == true)
                          Text('Tiny version: ${h.tinyVersion}',
                              style: TextStyle(color: color, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(children: [
                stat('CURRENT', '🔥 ${h.currentStreak(today)}$unit'),
                const SizedBox(width: 8),
                stat('BEST', '${h.bestStreak(today)}$unit'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                stat('LAST 30 DAYS', '${(h.completionRate(today) * 100).round()}%'),
                const SizedBox(width: 8),
                stat('DAYS DONE', '${h.totalDaysDone}'),
              ]),
              const SizedBox(height: 22),
              Text('LAST 12 WEEKS',
                  style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.6)),
              const SizedBox(height: 4),
              Text('Tap a day to fix it if you forgot to log.',
                  style: TextStyle(color: c.textMuted, fontSize: 11)),
              const SizedBox(height: 12),
              HabitHeatmap(
                habit: h,
                today: today,
                onToggleDay: (day) => store.toggleDay(h.id, day),
              ),
            ],
          ),
        );
      },
    );
  }
}
