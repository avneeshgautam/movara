import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/reminder_scheduler.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReminderScheduler', () {
    test('starts off, defaulting to a 2 hour interval', () async {
      final s = ReminderScheduler();
      await s.load();

      expect(s.enabled, isFalse);
      expect(s.intervalHours, 2);
      expect(s.nextDue, isNull);
      s.dispose();
    });

    test('enabling schedules the next reminder one interval out', () async {
      final s = ReminderScheduler();
      await s.load();
      await s.setEnabled(true);

      expect(s.enabled, isTrue);
      final due = s.nextDue;
      expect(due, isNotNull);

      final expected = DateTime.now().add(Duration(hours: s.intervalHours));
      expect(due!.difference(expected).inMinutes.abs(), lessThan(2));
      s.dispose();
    });

    test('changing the interval re-bases the countdown', () async {
      final s = ReminderScheduler();
      await s.load();
      await s.setEnabled(true);
      await s.setIntervalHours(3);

      expect(s.intervalHours, 3);
      final expected = DateTime.now().add(const Duration(hours: 3));
      expect(s.nextDue!.difference(expected).inMinutes.abs(), lessThan(2));
      s.dispose();
    });

    test('disabling clears the pending reminder', () async {
      final s = ReminderScheduler();
      await s.load();
      await s.setEnabled(true);
      await s.setEnabled(false);

      expect(s.enabled, isFalse);
      expect(s.nextDue, isNull);
      s.dispose();
    });

    test('settings survive a restart', () async {
      final first = ReminderScheduler();
      await first.load();
      await first.setEnabled(true);
      await first.setIntervalHours(1);
      first.dispose();

      final second = ReminderScheduler();
      await second.load();

      expect(second.enabled, isTrue);
      expect(second.intervalHours, 1);
      expect(second.nextDue, isNotNull);
      second.dispose();
    });

    test('a reminder that came due while closed is caught up on load',
        () async {
      // Persisted state as if the app was closed past the due time.
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': true,
        'water_reminder_interval_hours': 2,
        'water_reminder_next_due_ms':
            DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      });

      final s = ReminderScheduler();
      await s.load();

      // It fired and re-armed for the next interval rather than staying stale.
      expect(s.nextDue!.isAfter(DateTime.now()), isTrue);
      s.dispose();
    });

    test('offers 1, 2 and 3 hour options', () {
      expect(ReminderScheduler.intervalOptions, [1, 2, 3]);
    });
  });
}
