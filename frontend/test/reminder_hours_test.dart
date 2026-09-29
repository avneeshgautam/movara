import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/models/reminder.dart';
import 'package:movara_app/screens/reminders_tab.dart';
import 'package:movara_app/services/reminder_scheduler.dart';
import 'package:movara_app/theme/app_theme.dart';

import 'test_setup.dart';

Reminder _r({int interval = 45, int start = 7 * 60, int end = 23 * 60}) =>
    Reminder(
      id: 'r',
      notifId: 1,
      label: 'Drink water',
      intervalMinutes: interval,
      startMinute: start,
      endMinute: end,
    );

void main() {
  setUpAll(disableGoogleFontsNetwork);

  testWidgets('add dialog shows active hours and fits a phone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final scheduler = ReminderScheduler(seedDefaults: false);
    await scheduler.load();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: RemindersTab(scheduler: scheduler)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE HOURS'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(find.text('11:00 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'Stretch');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('7:00 AM – 11:00 PM'), findsOneWidget);
    scheduler.dispose();
  });

  group('active hours', () {
    test('defaults to 7:00 AM - 11:00 PM', () {
      final r = Reminder(id: 'r', notifId: 1, label: 'x', intervalMinutes: 30);
      expect(r.startMinute, 7 * 60);
      expect(r.endMinute, 23 * 60);
      expect(r.isActiveAt(DateTime(2026, 9, 29, 6, 59)), isFalse);
      expect(r.isActiveAt(DateTime(2026, 9, 29, 7, 0)), isTrue);
      expect(r.isActiveAt(DateTime(2026, 9, 29, 23, 0)), isTrue);
      expect(r.isActiveAt(DateTime(2026, 9, 29, 23, 1)), isFalse);
    });

    test('never schedules outside the window; resumes as it opens', () {
      final times = _r().upcomingTimes(DateTime(2026, 9, 29, 22, 0), 4);
      expect(times, [
        DateTime(2026, 9, 29, 22, 45),
        DateTime(2026, 9, 30, 7, 0), // 23:30 skipped; next day's window opens
        DateTime(2026, 9, 30, 7, 45),
        DateTime(2026, 9, 30, 8, 30),
      ]);
    });

    test('a long batch stays inside the window across several days', () {
      final r = _r(interval: 60);
      final times = r.upcomingTimes(DateTime(2026, 9, 29, 12, 0), 48);
      expect(times, hasLength(48));
      expect(times.every(r.isActiveAt), isTrue);
      expect(times.every((t) => t.hour >= 7 && t.hour <= 23), isTrue);
    });

    test('windows can wrap past midnight', () {
      final night = _r(interval: 60, start: 22 * 60, end: 2 * 60);
      expect(night.isActiveAt(DateTime(2026, 9, 29, 23, 30)), isTrue);
      expect(night.isActiveAt(DateTime(2026, 9, 30, 1, 0)), isTrue);
      expect(night.isActiveAt(DateTime(2026, 9, 30, 12, 0)), isFalse);
      final times = night.upcomingTimes(DateTime(2026, 9, 29, 12, 0), 3);
      expect(times.first, DateTime(2026, 9, 29, 22, 0));
    });

    test('start == end means all day', () {
      final all = _r(interval: 60, start: 0, end: 0);
      expect(all.isAllDay, isTrue);
      final times = all.upcomingTimes(DateTime(2026, 9, 29, 23, 30), 3);
      expect(times.first, DateTime(2026, 9, 30, 0, 30));
    });

    test('reminders saved before this feature get the default window', () {
      final old = Reminder.fromJson({
        'id': 'a',
        'notifId': 1,
        'label': 'Drink water',
        'intervalMinutes': 45,
        'enabled': true,
      });
      expect(old.startMinute, Reminder.defaultStartMinute);
      expect(old.endMinute, Reminder.defaultEndMinute);

      final round = Reminder.fromJson(_r(start: 480, end: 1260).toJson());
      expect(round.startMinute, 480);
      expect(round.endMinute, 1260);
    });
  });
}
