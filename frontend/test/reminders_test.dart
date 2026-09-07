import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/reminder_scheduler.dart';
import 'package:movara_app/services/water_notifications.dart';

/// Stands in for the platform, recording what it was asked to do.
class _FakeNotifications implements WaterNotifications {
  _FakeNotifications({this.supported = true, this.grants = true});

  final bool supported;
  final bool grants;

  String _permission = 'default';
  final List<String> shown = [];
  final List<int> scheduledBaseIds = [];
  int permissionRequests = 0;
  int cancelAllCount = 0;

  @override
  bool get isSupported => supported;

  @override
  bool get schedulesInBackground => false;

  @override
  String get permission => _permission;

  @override
  Future<String> requestPermission() async {
    permissionRequests++;
    _permission = grants ? 'granted' : 'denied';
    return _permission;
  }

  @override
  Future<void> show(String title, String body) async => shown.add(title);

  @override
  Future<void> scheduleReminder({
    required int baseId,
    required String title,
    required String body,
    required int everyMinutes,
    required int count,
  }) async =>
      scheduledBaseIds.add(baseId);

  @override
  Future<void> cancelAll() async => cancelAllCount++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Existing behaviour tests start from an empty list; seeding is covered
  // separately below.
  ReminderScheduler make([_FakeNotifications? fake]) => ReminderScheduler(
        notifications: fake ?? _FakeNotifications(),
        seedDefaults: false,
      );

  group('formatInterval', () {
    test('formats minutes, hours and mixed', () {
      expect(formatInterval(30), '30 min');
      expect(formatInterval(60), '1 hour');
      expect(formatInterval(120), '2 hours');
      expect(formatInterval(90), '1h 30m');
    });
  });

  group('ReminderScheduler list', () {
    test('starts empty on a fresh install', () async {
      final s = make();
      await s.load();
      expect(s.reminders, isEmpty);
      expect(s.hasAnyEnabled, isFalse);
      s.dispose();
    });

    test('adds a reminder and asks for permission', () async {
      final fake = _FakeNotifications();
      final s = make(fake);
      await s.load();

      await s.addReminder(label: 'Stretch', intervalMinutes: 45);

      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.label, 'Stretch');
      expect(s.reminders.single.intervalMinutes, 45);
      expect(s.reminders.single.enabled, isTrue);
      expect(fake.permissionRequests, 1);
      s.dispose();
    });

    test('a blank label falls back rather than saving empty', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: '   ', intervalMinutes: 30);
      expect(s.reminders.single.label, 'Reminder');
      s.dispose();
    });

    test('clamps an out-of-range interval', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: 'X', intervalMinutes: 5000);
      expect(s.reminders.single.intervalMinutes,
          ReminderScheduler.maxIntervalMinutes);
      s.dispose();
    });

    test('editing changes the label and interval', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: 'Walk', intervalMinutes: 60);
      final id = s.reminders.single.id;

      await s.updateReminder(id, label: 'Long walk', intervalMinutes: 90);
      expect(s.reminders.single.label, 'Long walk');
      expect(s.reminders.single.intervalMinutes, 90);
      s.dispose();
    });

    test('toggling off clears the due time', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: 'Water', intervalMinutes: 30);
      final id = s.reminders.single.id;
      expect(s.reminders.single.nextDue, isNotNull);

      await s.setReminderEnabled(id, false);
      expect(s.reminders.single.enabled, isFalse);
      expect(s.reminders.single.nextDue, isNull);
      expect(s.hasAnyEnabled, isFalse);
      s.dispose();
    });

    test('removing takes it out of the list', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: 'A', intervalMinutes: 30);
      await s.addReminder(label: 'B', intervalMinutes: 60);
      final firstId = s.reminders.first.id;

      await s.removeReminder(firstId);
      expect(s.reminders.map((r) => r.label), ['B']);
      s.dispose();
    });

    test('each reminder gets its own notification namespace', () async {
      final s = make();
      await s.load();
      await s.addReminder(label: 'A', intervalMinutes: 30);
      await s.addReminder(label: 'B', intervalMinutes: 60);
      expect(s.reminders[0].notifId, isNot(s.reminders[1].notifId));
      s.dispose();
    });

    test('reminders survive a reload', () async {
      final first = make();
      await first.load();
      await first.addReminder(label: 'Water', intervalMinutes: 30);
      await first.addReminder(label: 'Stand up', intervalMinutes: 45);
      first.dispose();

      final second = make();
      await second.load();
      expect(second.reminders.map((r) => r.label), ['Water', 'Stand up']);
      second.dispose();
    });
  });

  group('migration from the old single water reminder', () {
    test('carries the legacy reminder in as the first item', () async {
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': true,
        'water_reminder_interval_minutes': 45,
      });
      final s = make();
      await s.load();

      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.label, 'Drink water');
      expect(s.reminders.single.intervalMinutes, 45);
      expect(s.reminders.single.enabled, isTrue);
      s.dispose();
    });

    test('migrates a disabled legacy reminder without a due time', () async {
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': false,
        'water_reminder_interval_minutes': 30,
      });
      final s = make();
      await s.load();
      expect(s.reminders.single.enabled, isFalse);
      expect(s.reminders.single.nextDue, isNull);
      s.dispose();
    });
  });

  group('the test reminder button', () {
    test('asks for permission first, then sends', () async {
      final fake = _FakeNotifications();
      final s = make(fake);
      await s.load();

      expect(await s.sendTest(), isTrue);
      expect(fake.permissionRequests, 1);
      expect(fake.shown, hasLength(1));
      s.dispose();
    });

    test('reports failure when permission is refused', () async {
      final fake = _FakeNotifications(grants: false);
      final s = make(fake);
      await s.load();

      expect(await s.sendTest(), isFalse);
      expect(fake.shown, isEmpty);
      s.dispose();
    });

    test('reports failure where notifications are unsupported', () async {
      final fake = _FakeNotifications(supported: false);
      final s = make(fake);
      await s.load();

      expect(await s.sendTest(), isFalse);
      expect(fake.permissionRequests, 0);
      s.dispose();
    });
  });

  group('default water reminder seeding', () {
    test('a fresh install gets a Drink water reminder, off', () async {
      final s = ReminderScheduler(
          notifications: _FakeNotifications(), seedDefaults: true);
      await s.load();

      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.label, 'Drink water');
      expect(s.reminders.single.enabled, isFalse);
      s.dispose();
    });

    test('an install that already saved an empty list still gets it once',
        () async {
      SharedPreferences.setMockInitialValues({'reminders_v2': '[]'});
      final s = ReminderScheduler(
          notifications: _FakeNotifications(), seedDefaults: true);
      await s.load();
      expect(s.reminders.map((r) => r.label), ['Drink water']);
      s.dispose();
    });

    test('deleting the default keeps it gone across reloads', () async {
      final first = ReminderScheduler(
          notifications: _FakeNotifications(), seedDefaults: true);
      await first.load();
      await first.removeReminder(first.reminders.single.id);
      first.dispose();

      final second = ReminderScheduler(
          notifications: _FakeNotifications(), seedDefaults: true);
      await second.load();
      expect(second.reminders, isEmpty,
          reason: 'the seed is one-shot; a deleted default must not return');
      second.dispose();
    });

    test('does not duplicate when a legacy reminder was migrated', () async {
      SharedPreferences.setMockInitialValues({
        'water_reminder_enabled': true,
        'water_reminder_interval_minutes': 30,
      });
      final s = ReminderScheduler(
          notifications: _FakeNotifications(), seedDefaults: true);
      await s.load();
      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.intervalMinutes, 30);
      s.dispose();
    });
  });
}
