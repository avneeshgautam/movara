import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'water_notifications.dart';

/// What happened on a check-in, so the UI knows when to celebrate.
class CheckIn {
  const CheckIn({
    required this.habit,
    required this.completedToday,
    required this.weekGoalReached,
    required this.allDoneToday,
  });

  /// The habit after the check-in.
  final Habit habit;

  /// This tap took today's count from below the goal to the goal.
  final bool completedToday;

  /// For "× a week" habits: this tap reached the weekly target.
  final bool weekGoalReached;

  /// Every habit due today is now done (and this tap finished the last one).
  final bool allDoneToday;

  bool get celebrate => completedToday || weekGoalReached;
}

/// The user's habits, kept on the device, plus their reminders.
class HabitStore extends ChangeNotifier {
  HabitStore({
    WaterNotifications notifications = const WaterNotifications(),
    DateTime Function()? clock,
  })  : _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final WaterNotifications _notifications;
  final DateTime Function() _clock;

  static const _key = 'habits_v1';

  /// Habit reminder ids live in [idBase, idBase + 100000): above the water
  /// reminders' range so their reschedule never cancels these.
  static const idBase = 930000;

  /// iOS allows 64 pending notifications in total (see water_notifications).
  static const maxReminderSlots = 20;

  /// Ready-made habits offered as one-tap suggestions.
  static const templates = <({String emoji, String name, int target, String? unit})>[
    (emoji: '💧', name: 'Drink water', target: 8, unit: 'glasses'),
    (emoji: '🧘', name: 'Meditate', target: 1, unit: null),
    (emoji: '📖', name: 'Read', target: 10, unit: 'pages'),
    (emoji: '🚶', name: 'Walk outside', target: 1, unit: null),
    (emoji: '🤸', name: 'Stretch', target: 1, unit: null),
    (emoji: '😴', name: 'In bed by 11', target: 1, unit: null),
    (emoji: '✍️', name: 'Journal', target: 1, unit: null),
    (emoji: '🥗', name: 'Eat a vegetable', target: 2, unit: 'servings'),
  ];

  List<Habit> _habits = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Active habits in the user's order.
  List<Habit> get habits =>
      List.unmodifiable(_habits.where((h) => !h.archived));

  List<Habit> get archived =>
      List.unmodifiable(_habits.where((h) => h.archived));

  /// Today's list: active habits due today.
  List<Habit> dueToday() {
    final today = _clock();
    return habits.where((h) => h.dueOn(today)).toList();
  }

  Habit? byId(String id) {
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _habits = Habit.decode(raw);
      } catch (_) {
        _habits = [];
      }
    }
    _loaded = true;
    notifyListeners();
    await _syncReminders();
  }

  // ── Editing ──────────────────────────────────────────────────────────

  /// Adds a habit built from [draft]'s fields (id, slot and date are set here).
  Future<Habit> add(Habit draft) async {
    final slot = _habits.fold<int>(0, (m, h) => h.notifSlot > m ? h.notifSlot : m) + 1;
    final habit = Habit(
      // The slot is unique per habit, so two habits added in the same
      // instant (e.g. quick-adding templates) can never share an id.
      id: '${_clock().microsecondsSinceEpoch}-$slot',
      name: draft.name.trim().isEmpty ? 'New habit' : draft.name.trim(),
      // Respect a start date in the past (never the future).
      createdAt: draft.createdAt.isAfter(_clock()) ? _clock() : draft.createdAt,
      emoji: draft.emoji,
      color: draft.color,
      tinyVersion: draft.tinyVersion,
      targetPerDay: draft.targetPerDay.clamp(1, 99).toInt(),
      unit: draft.unit,
      frequency: draft.frequency,
      days: draft.days.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : draft.days,
      timesPerWeek: draft.timesPerWeek.clamp(1, 7).toInt(),
      reminderMinute: draft.reminderMinute,
      notifSlot: slot,
    );
    _habits = [..._habits, habit];
    await _changed();
    return habit;
  }

  Future<void> update(Habit habit) async {
    _habits = [for (final h in _habits) h.id == habit.id ? habit : h];
    await _changed();
  }

  Future<void> remove(String id) async {
    _habits = _habits.where((h) => h.id != id).toList();
    await _changed();
  }

  Future<void> setArchived(String id, bool archived) async {
    final h = byId(id);
    if (h != null) await update(h.copyWith(archived: archived));
  }

  /// Moves the active habit at [oldIndex] so it ends up at [newIndex]
  /// (final position, as ReorderableList's onReorderItem reports it).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final active = [...habits];
    active.insert(newIndex, active.removeAt(oldIndex));
    _habits = [...active, ...archived];
    await _changed();
  }

  // ── Check-ins ────────────────────────────────────────────────────────

  /// +1 for today. Past the goal it keeps counting (8 → 9 glasses is fine).
  Future<CheckIn> checkIn(String id) => _setCount(id, _clock(), (c) => c + 1);

  /// −1 for today (never below zero).
  Future<CheckIn> undo(String id) =>
      _setCount(id, _clock(), (c) => c > 0 ? c - 1 : 0);

  /// Marks a past day done/not done — for fixing a forgotten day.
  Future<CheckIn> toggleDay(String id, DateTime day) {
    final h = byId(id)!;
    return _setCount(id, day, (c) => h.doneOn(day) ? 0 : h.targetPerDay);
  }

  Future<CheckIn> _setCount(
      String id, DateTime day, int Function(int current) next) async {
    final before = byId(id)!;
    final today = _clock();
    final wasDone = before.doneOn(day);
    final weekWasMet = before.weekGoalMet(day);
    final allWereDone = _allDone(today);

    final log = Map<String, int>.from(before.log);
    final count = next(before.countOn(day));
    if (count <= 0) {
      log.remove(Habit.keyOf(day));
    } else {
      log[Habit.keyOf(day)] = count;
    }
    final after = before.copyWith(log: log);
    await update(after);

    final isToday = Habit.dayOf(day) == Habit.dayOf(today);
    return CheckIn(
      habit: after,
      completedToday: isToday && !wasDone && after.doneOn(day),
      weekGoalReached: after.frequency == HabitFrequency.timesPerWeek &&
          !weekWasMet &&
          after.weekGoalMet(day),
      allDoneToday: isToday && !allWereDone && _allDone(today),
    );
  }

  bool _allDone(DateTime today) {
    final due = habits.where((h) => h.dueOn(today)).toList();
    return due.isNotEmpty && due.every((h) => h.doneOn(today));
  }

  /// Done / total of today's list, for the Home header.
  ({int done, int total}) todayProgress() {
    final today = _clock();
    final due = dueToday();
    return (done: due.where((h) => h.doneOn(today)).length, total: due.length);
  }

  // ── Persistence + reminders ──────────────────────────────────────────

  Future<void> _changed() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, Habit.encode(_habits));
    await _syncReminders();
  }

  /// Rebuilds every habit reminder from scratch (cheap, and never drifts).
  Future<void> _syncReminders() async {
    if (!_notifications.schedulesInBackground) return;
    try {
      await _notifications.cancelRange(idBase, idBase + 100000);
      var used = 0;
      for (final h in habits) {
        final minute = h.reminderMinute;
        if (minute == null) continue;
        final title = '${h.emoji} ${h.name}';
        final body = h.tinyVersion?.isNotEmpty == true
            ? 'Even just ${h.tinyVersion} counts. Keep your streak going!'
            : 'Time for your habit — keep your streak going!';
        if (h.frequency == HabitFrequency.specificDays && h.days.length < 7) {
          for (final day in [...h.days]..sort()) {
            if (used >= maxReminderSlots) return;
            await _notifications.scheduleWeeklyAt(
              id: idBase + h.notifSlot * 10 + day,
              weekday: day,
              hour: minute ~/ 60,
              minute: minute % 60,
              title: title,
              body: body,
            );
            used++;
          }
        } else {
          if (used >= maxReminderSlots) return;
          await _notifications.scheduleDailyAt(
            id: idBase + h.notifSlot * 10,
            hour: minute ~/ 60,
            minute: minute % 60,
            title: title,
            body: body,
          );
          used++;
        }
      }
    } catch (_) {
      // Reminders are best-effort; the habit itself is saved regardless.
    }
  }
}
