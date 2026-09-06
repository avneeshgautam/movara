import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Water reminders delivered by the operating system.
///
/// This is stronger than the web version: iOS schedules these itself, so they
/// arrive with the app closed. The browser can only catch up when the tab is
/// reopened.
class WaterNotifications {
  const WaterNotifications();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String _permission = 'default';

  /// iOS refuses more than 64 pending notifications, so a repeating reminder
  /// is a rolling batch that is topped up whenever the settings change or the
  /// app is opened.
  static const _maxScheduled = 48;

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Only iOS is set up here. Android needs its own channel and icon
  /// settings, and the desktop VM (which the tests run on) has no plugin at
  /// all — claiming support there makes initialize() throw.
  bool get isSupported => Platform.isIOS;

  /// iOS holds the schedule itself, so the app need not be running.
  bool get schedulesInBackground => Platform.isIOS;

  String get permission => isSupported ? _permission : 'unsupported';

  Future<void> _ensureInit() async {
    if (_ready || !isSupported) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Asked for explicitly when the user turns reminders on, so the
          // prompt has context rather than appearing at first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<String> requestPermission() async {
    if (!isSupported) return 'unsupported';
    await _ensureInit();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
    _permission = granted ? 'granted' : 'denied';
    return _permission;
  }

  /// Immediate notification, used for the "test" button.
  Future<void> show(String title, String body) async {
    if (!isSupported) return;
    await _ensureInit();
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  /// The most notifications one reminder may queue. iOS caps an app at 64
  /// pending, so the scheduler shares this budget across reminders.
  static const maxSeries = _maxScheduled;

  /// Queues a rolling series for one reminder: [count] notifications
  /// [everyMinutes] apart, with ids namespaced by [baseId] so they can be
  /// cancelled without touching other reminders.
  Future<void> scheduleReminder({
    required int baseId,
    required String title,
    required String body,
    required int everyMinutes,
    required int count,
  }) async {
    if (!isSupported) return;
    await _ensureInit();

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 1; i <= count; i++) {
      await _plugin.zonedSchedule(
        id: baseId * 1000 + i,
        title: title,
        body: body,
        scheduledDate: now.add(Duration(minutes: everyMinutes * i)),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _ensureInit();
    await _plugin.cancelAll();
  }
}
