import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/habit.dart';
import 'package:movara_app/services/habit_store.dart';

// Wed 30 Sep 2026 (weekday 3).
final today = DateTime(2026, 9, 30, 9);
DateTime daysAgo(int n) => today.subtract(Duration(days: n));

Habit habit({
  HabitFrequency frequency = HabitFrequency.daily,
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  int timesPerWeek = 3,
  int target = 1,
  Map<String, int> log = const {},
  int createdDaysAgo = 60,
}) =>
    Habit(
      id: 'h',
      name: 'Test',
      createdAt: daysAgo(createdDaysAgo),
      frequency: frequency,
      days: days,
      timesPerWeek: timesPerWeek,
      targetPerDay: target,
      log: log,
    );

Map<String, int> doneOn(Iterable<int> ago, [int count = 1]) =>
    {for (final n in ago) Habit.keyOf(daysAgo(n)): count};

void main() {
  group('Habit rules', () {
    test('a day counts as done only once the daily target is reached', () {
      final h = habit(target: 8, log: {Habit.keyOf(today): 5});
      expect(h.doneOn(today), isFalse);
      expect(h.progressOn(today), closeTo(5 / 8, 1e-9));
      expect(h.copyWith(log: {Habit.keyOf(today): 8}).doneOn(today), isTrue);
    });

    test('streak counts back from yesterday while today is still open', () {
      final h = habit(log: doneOn([1, 2, 3]));
      expect(h.currentStreak(today), 3); // today not done yet: not broken
      final done = h.copyWith(log: {...h.log, ...doneOn([0])});
      expect(done.currentStreak(today), 4);
    });

    test('a missed day ends the streak', () {
      expect(habit(log: doneOn([1, 2, 4, 5])).currentStreak(today), 2);
    });

    test('unscheduled days are skipped, not counted as misses', () {
      // Mon/Wed/Fri habit. Today is Wed; done Mon 28, Fri 25, Wed 23.
      final h = habit(
        frequency: HabitFrequency.specificDays,
        days: {1, 3, 5},
        log: doneOn([2, 5, 7]),
      );
      expect(h.scheduledOn(today), isTrue);
      expect(h.scheduledOn(daysAgo(1)), isFalse); // Tuesday
      expect(h.currentStreak(today), 3);
    });

    test('weekly habits streak in weeks that met the target', () {
      // 3× a week. This week (Mon 28–Wed 30): 2 so far. Last week: 3. Week
      // before: 3. Before that: 1.
      final h = habit(
        frequency: HabitFrequency.timesPerWeek,
        timesPerWeek: 3,
        log: doneOn([0, 1, 3, 4, 5, 10, 11, 12, 17]),
      );
      expect(h.doneDaysInWeek(today), 2);
      expect(h.weekGoalMet(today), isFalse);
      expect(h.currentStreak(today), 2); // this week still in progress
      expect(h.streakUnit, 'week');
    });

    test('best streak remembers the longest run', () {
      final h = habit(log: doneOn([1, 2, 10, 11, 12, 13, 14]));
      expect(h.currentStreak(today), 2);
      expect(h.bestStreak(today), 5);
    });

    test('completion rate ignores today until it is done', () {
      final h = habit(createdDaysAgo: 3, log: doneOn([1, 2]));
      // Days: -3 missed, -2 done, -1 done, today open → 2/3.
      expect(h.completionRate(today), closeTo(2 / 3, 1e-9));
    });

    test('weekly habit leaves today\'s list once the week is complete', () {
      final open = habit(
          frequency: HabitFrequency.timesPerWeek,
          timesPerWeek: 2,
          log: doneOn([2]));
      expect(open.dueOn(today), isTrue);
      final met = open.copyWith(log: doneOn([1, 2]));
      expect(met.dueOn(today), isFalse);
    });

    test('schedule labels stay short', () {
      Habit on(Set<int> d) =>
          habit(frequency: HabitFrequency.specificDays, days: d);
      expect(on({1, 2, 3, 4, 5}).scheduleLabel, 'Weekdays');
      expect(on({6, 7}).scheduleLabel, 'Weekends');
      expect(on({1, 3, 5}).scheduleLabel, 'Mon, Wed, Fri');
      expect(on({1, 2, 3, 4, 5, 7}).scheduleLabel, '6 days a week');
      expect(habit(frequency: HabitFrequency.timesPerWeek, timesPerWeek: 3)
          .scheduleLabel, '3× a week');
    });

    test('JSON round-trip keeps everything', () {
      final h = habit(
        frequency: HabitFrequency.specificDays,
        days: {2, 4},
        target: 3,
        log: doneOn([1], 3),
      ).copyWith(unit: 'sets', tinyVersion: '1 set', reminderMinute: 450);
      final back = Habit.decode(Habit.encode([h])).single;
      expect(back.days, {2, 4});
      expect(back.targetPerDay, 3);
      expect(back.unit, 'sets');
      expect(back.tinyVersion, '1 set');
      expect(back.reminderMinute, 450);
      expect(back.log, h.log);
      expect(back.frequency, HabitFrequency.specificDays);
    });
  });

  group('HabitStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<HabitStore> store() async {
      final s = HabitStore(clock: () => today);
      await s.load();
      return s;
    }

    test('celebrates exactly once, when the goal is reached', () async {
      final s = await store();
      final water = await s.add(Habit(
          id: '', name: 'Water', createdAt: today, targetPerDay: 3));

      expect((await s.checkIn(water.id)).celebrate, isFalse); // 1/3
      expect((await s.checkIn(water.id)).celebrate, isFalse); // 2/3
      final third = await s.checkIn(water.id); // 3/3
      expect(third.completedToday, isTrue);
      expect(third.allDoneToday, isTrue);
      final fourth = await s.checkIn(water.id); // 4/3: no repeat party
      expect(fourth.celebrate, isFalse);
      expect(fourth.habit.countOn(today), 4);
    });

    test('all-done fires only when the last habit is finished', () async {
      final s = await store();
      final a = await s.add(Habit(id: '', name: 'A', createdAt: today));
      final b = await s.add(Habit(id: '', name: 'B', createdAt: today));
      expect((await s.checkIn(a.id)).allDoneToday, isFalse);
      expect((await s.checkIn(b.id)).allDoneToday, isTrue);
      expect(s.todayProgress(), (done: 2, total: 2));
    });

    test('weekly goal reached is reported for × a week habits', () async {
      final s = await store();
      final gym = await s.add(Habit(
          id: '',
          name: 'Gym',
          createdAt: daysAgo(3),
          frequency: HabitFrequency.timesPerWeek,
          timesPerWeek: 2));
      await s.toggleDay(gym.id, daysAgo(1)); // Tuesday
      final r = await s.checkIn(gym.id); // Wednesday → 2 this week
      expect(r.weekGoalReached, isTrue);
    });

    test('undo, fix a past day, archive, reorder and persist', () async {
      final s = await store();
      final a = await s.add(Habit(id: '', name: 'A', createdAt: daysAgo(5)));
      final b = await s.add(Habit(id: '', name: 'B', createdAt: daysAgo(5)));

      await s.checkIn(a.id);
      await s.undo(a.id);
      expect(s.byId(a.id)!.countOn(today), 0);

      await s.toggleDay(a.id, daysAgo(2));
      expect(s.byId(a.id)!.doneOn(daysAgo(2)), isTrue);

      await s.reorder(0, 1); // move A after B
      expect(s.habits.map((h) => h.name), ['B', 'A']);

      await s.setArchived(b.id, true);
      expect(s.habits.map((h) => h.name), ['A']);
      expect(s.archived.map((h) => h.name), ['B']);

      final reopened = HabitStore(clock: () => today);
      await reopened.load();
      expect(reopened.habits.single.doneOn(daysAgo(2)), isTrue);
      expect(reopened.archived.single.name, 'B');
    });
  });
}
