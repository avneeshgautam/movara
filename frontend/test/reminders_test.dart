import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/reminder_scheduler.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReminderScheduler', () {
    test('starts off, defaulting to a 30 minute interval', () async {
      final s = ReminderScheduler();
      await s.load();

      expect(s.enabled, isFalse);
      expect(s.intervalMinutes, 30);
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

      final expected = DateTime.now().add(Duration(minutes: s.intervalMinutes));
      expect(due!.difference(expected).inMinutes.abs(), lessThan(2));
      s.dispose();
    });

    test('changing the interval re-bases the countdown', () async {
      final s = ReminderScheduler();
      await s.load();
      await s.setEnabled(true);
      await s.setIntervalMinutes(45);

      expect(s.intervalMinutes, 45);
      final expected = DateTime.now().add(const Duration(minutes: 45));
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
      await first.setIntervalMinutes(90);
      first.dispose();

      final second = ReminderScheduler();
      await second.load();

      expect(second.enabled, isTrue);
      expect(second.intervalMinutes, 90);
      expect(second.nextDue, isNotNull);
      second.dispose();
    });

    test('a reminder that came due while closed is caught up on load',
        () async {
      // Persisted state as if the app was closed past the due time.
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': true,
        'water_reminder_interval_minutes': 30,
        'water_reminder_next_due_ms':
            DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      });

      final s = ReminderScheduler();
      await s.load();

      // It fired and re-armed for the next interval rather than staying stale.
      expect(s.nextDue!.isAfter(DateTime.now()), isTrue);
      s.dispose();
    });

    test('offers preset intervals in minutes', () {
      expect(ReminderScheduler.intervalOptions, [15, 30, 45, 60, 90, 120, 180]);
      expect(ReminderScheduler.defaultIntervalMinutes, 30);
    });

    test('accepts a typed custom interval', () async {
      final s = ReminderScheduler();
      await s.load();
      await s.setIntervalMinutes(7);

      expect(s.intervalMinutes, 7);
      expect(s.intervalLabel, '7 min');
      s.dispose();
    });

    test('clamps out-of-range custom values instead of rejecting them',
        () async {
      final s = ReminderScheduler();
      await s.load();

      await s.setIntervalMinutes(0);
      expect(s.intervalMinutes, ReminderScheduler.minIntervalMinutes);

      await s.setIntervalMinutes(99999);
      expect(s.intervalMinutes, ReminderScheduler.maxIntervalMinutes);
      s.dispose();
    });

    test('carries over an interval saved by an older build (hours)', () async {
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': false,
        'water_reminder_interval_hours': 2,
      });

      final s = ReminderScheduler();
      await s.load();

      expect(s.intervalMinutes, 120);
      s.dispose();
    });

    test('formats intervals for display', () {
      expect(formatInterval(30), '30 min');
      expect(formatInterval(60), '1 hour');
      expect(formatInterval(120), '2 hours');
      expect(formatInterval(90), '1h 30m');
    });
  });
}
