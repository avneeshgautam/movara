import 'dart:convert';

/// How often a habit is meant to happen.
enum HabitFrequency {
  /// Every day.
  daily,

  /// Only on chosen weekdays (Mon–Sun).
  specificDays,

  /// Any days, a number of times per week (e.g. "gym 3× a week").
  timesPerWeek,
}

/// One habit and its full completion log.
///
/// All rules (due today, done, streaks, rates) are pure functions of the log
/// and a supplied "today", so they're easy to test and never depend on the
/// wall clock implicitly.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.createdAt,
    this.emoji = '✅',
    this.color = 0,
    this.tinyVersion,
    this.targetPerDay = 1,
    this.unit,
    this.frequency = HabitFrequency.daily,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.timesPerWeek = 3,
    this.reminderMinute,
    this.notifSlot = 0,
    this.archived = false,
    this.log = const {},
  });

  final String id;
  final String name;
  final String emoji;

  /// Index into the habit colour palette.
  final int color;

  /// The smallest version that still counts on a bad day ("1 push-up").
  final String? tinyVersion;

  /// How many times per day counts as done (e.g. 8 glasses of water).
  final int targetPerDay;

  /// Label for the count ("glasses", "pages"); null for simple habits.
  final String? unit;

  final HabitFrequency frequency;

  /// Weekdays for [HabitFrequency.specificDays] (1 = Monday … 7 = Sunday).
  final Set<int> days;

  /// Target days per week for [HabitFrequency.timesPerWeek].
  final int timesPerWeek;

  /// Daily reminder time as minutes after midnight, or null for none.
  final int? reminderMinute;

  /// Stable small number that namespaces this habit's notification ids.
  final int notifSlot;

  final DateTime createdAt;
  final bool archived;

  /// Completions per day: 'yyyy-mm-dd' → count.
  final Map<String, int> log;

  // ── Dates ────────────────────────────────────────────────────────────

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime mondayOf(DateTime d) =>
      dayOf(d).subtract(Duration(days: d.weekday - 1));

  DateTime get _start => dayOf(createdAt);

  // ── Per-day state ────────────────────────────────────────────────────

  int countOn(DateTime d) => log[keyOf(d)] ?? 0;

  bool doneOn(DateTime d) => countOn(d) >= targetPerDay;

  /// Fraction of today's target reached, 0..1.
  double progressOn(DateTime d) =>
      (countOn(d) / targetPerDay).clamp(0.0, 1.0).toDouble();

  /// Whether the habit is planned for this day. Weekly-count habits can be
  /// done on any day.
  bool scheduledOn(DateTime d) => switch (frequency) {
        HabitFrequency.specificDays => days.contains(d.weekday),
        _ => true,
      };

  /// Days completed in the Monday-to-Sunday week containing [d].
  int doneDaysInWeek(DateTime d) {
    final monday = mondayOf(d);
    var n = 0;
    for (var i = 0; i < 7; i++) {
      if (doneOn(monday.add(Duration(days: i)))) n++;
    }
    return n;
  }

  bool weekGoalMet(DateTime d) => doneDaysInWeek(d) >= timesPerWeek;

  /// Whether it belongs on today's list. A weekly habit drops off once its
  /// week is complete — unless it was ticked today, so it doesn't vanish
  /// right after you tap it.
  bool dueOn(DateTime today) {
    if (archived) return false;
    if (frequency == HabitFrequency.timesPerWeek) {
      return !weekGoalMet(today) || countOn(today) > 0;
    }
    return scheduledOn(today);
  }

  // ── Streaks ──────────────────────────────────────────────────────────

  bool get _weekly => frequency == HabitFrequency.timesPerWeek;

  /// "day" or "week" — what one step of the streak means.
  String get streakUnit => _weekly ? 'week' : 'day';

  /// Consecutive completed scheduled days (or weeks that met the goal),
  /// counting back from today. Today (or this week) not being done *yet*
  /// doesn't break the streak — it's still in progress.
  int currentStreak(DateTime today) {
    today = dayOf(today);
    if (_weekly) {
      var week = mondayOf(today);
      if (!weekGoalMet(week)) week = week.subtract(const Duration(days: 7));
      var n = 0;
      while (!week.isBefore(mondayOf(_start)) && weekGoalMet(week)) {
        n++;
        week = week.subtract(const Duration(days: 7));
      }
      return n;
    }
    var day = today;
    if (scheduledOn(day) && !doneOn(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    for (var guard = 0; guard < 3660 && !day.isBefore(_start); guard++) {
      if (scheduledOn(day)) {
        if (!doneOn(day)) break;
        n++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Longest run ever, in the same unit as [currentStreak].
  int bestStreak(DateTime today) {
    today = dayOf(today);
    var best = 0, run = 0;
    if (_weekly) {
      for (var w = mondayOf(_start);
          !w.isAfter(today);
          w = w.add(const Duration(days: 7))) {
        if (weekGoalMet(w)) {
          run++;
          if (run > best) best = run;
        } else if (!w.isAfter(mondayOf(today).subtract(const Duration(days: 1)))) {
          run = 0; // a finished week that missed the goal
        }
      }
      return best;
    }
    for (var d = _start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      if (!scheduledOn(d)) continue;
      if (doneOn(d)) {
        run++;
        if (run > best) best = run;
      } else if (d.isBefore(today)) {
        run = 0; // today still in progress doesn't reset
      }
    }
    return best;
  }

  /// Share of scheduled days (or weeks) completed over the last [window] days
  /// since the habit was created, 0..1.
  double completionRate(DateTime today, {int window = 30}) {
    today = dayOf(today);
    var from = today.subtract(Duration(days: window - 1));
    if (from.isBefore(_start)) from = _start;
    if (_weekly) {
      var weeks = 0, met = 0;
      for (var w = mondayOf(from);
          !w.isAfter(today);
          w = w.add(const Duration(days: 7))) {
        weeks++;
        if (weekGoalMet(w)) met++;
      }
      return weeks == 0 ? 0 : met / weeks;
    }
    var planned = 0, done = 0;
    for (var d = from; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      if (!scheduledOn(d)) continue;
      // Today only counts once it's done, so an unfinished morning
      // doesn't drag the rate down.
      if (d == today && !doneOn(d)) continue;
      planned++;
      if (doneOn(d)) done++;
    }
    return planned == 0 ? 0 : done / planned;
  }

  /// Days on which the goal was reached, all time.
  int get totalDaysDone => log.values.where((c) => c >= targetPerDay).length;

  /// Short human summary of the schedule: "Every day", "Weekdays",
  /// "Mon, Wed, Fri", "5 days a week", "3× a week". Kept short so it fits
  /// beside the week strip on small phones.
  String get scheduleLabel {
    switch (frequency) {
      case HabitFrequency.daily:
        return 'Every day';
      case HabitFrequency.timesPerWeek:
        return '$timesPerWeek× a week';
      case HabitFrequency.specificDays:
        final sorted = [...days]..sort();
        if (sorted.length == 7) return 'Every day';
        if (sorted.join() == '12345') return 'Weekdays';
        if (sorted.join() == '67') return 'Weekends';
        if (sorted.length <= 3) {
          return sorted.map((d) => _weekdayShort[d - 1]).join(', ');
        }
        return '${sorted.length} days a week';
    }
  }

  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Copy / JSON ──────────────────────────────────────────────────────

  Habit copyWith({
    String? name,
    String? emoji,
    int? color,
    String? tinyVersion,
    bool clearTinyVersion = false,
    int? targetPerDay,
    String? unit,
    bool clearUnit = false,
    HabitFrequency? frequency,
    Set<int>? days,
    int? timesPerWeek,
    int? reminderMinute,
    bool clearReminder = false,
    bool? archived,
    Map<String, int>? log,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      tinyVersion: clearTinyVersion ? null : (tinyVersion ?? this.tinyVersion),
      targetPerDay: targetPerDay ?? this.targetPerDay,
      unit: clearUnit ? null : (unit ?? this.unit),
      frequency: frequency ?? this.frequency,
      days: days ?? this.days,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      reminderMinute:
          clearReminder ? null : (reminderMinute ?? this.reminderMinute),
      notifSlot: notifSlot,
      archived: archived ?? this.archived,
      log: log ?? this.log,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'tiny': tinyVersion,
        'target': targetPerDay,
        'unit': unit,
        'freq': frequency.name,
        'days': [...days],
        'perWeek': timesPerWeek,
        'remind': reminderMinute,
        'slot': notifSlot,
        'created': createdAt.toIso8601String(),
        'archived': archived,
        'log': log,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '✅',
        color: j['color'] as int? ?? 0,
        tinyVersion: j['tiny'] as String?,
        targetPerDay: j['target'] as int? ?? 1,
        unit: j['unit'] as String?,
        frequency: HabitFrequency.values.firstWhere(
            (f) => f.name == j['freq'],
            orElse: () => HabitFrequency.daily),
        days: {...(j['days'] as List? ?? const [1, 2, 3, 4, 5, 6, 7]).cast<int>()},
        timesPerWeek: j['perWeek'] as int? ?? 3,
        reminderMinute: j['remind'] as int?,
        notifSlot: j['slot'] as int? ?? 0,
        createdAt: DateTime.parse(j['created'] as String),
        archived: j['archived'] as bool? ?? false,
        log: {...(j['log'] as Map? ?? const {}).cast<String, int>()},
      );

  static String encode(List<Habit> habits) =>
      jsonEncode(habits.map((h) => h.toJson()).toList());

  static List<Habit> decode(String raw) => (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Habit.fromJson)
      .toList();
}
