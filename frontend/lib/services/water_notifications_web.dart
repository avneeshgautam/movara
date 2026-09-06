import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Thin wrapper over the browser Notification API.
///
/// Notifications only fire while the page is running — a browser cannot wake
/// a closed tab without a push service. See ReminderScheduler for how missed
/// reminders are caught up on reopening.
class WaterNotifications {
  const WaterNotifications();

  bool get isSupported => permission != 'unsupported';

  String get permission {
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'unsupported';
    }
  }

  Future<String> requestPermission() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  Future<void> show(String title, String body) async {
    if (permission != 'granted') return;
    try {
      web.Notification(title, web.NotificationOptions(body: body));
    } catch (_) {
      // Some browsers require a service worker for notifications; ignore.
    }
  }

  /// A browser cannot wake a closed tab, so reminders are fired by the app's
  /// own timer and only catch up when it is reopened.
  bool get schedulesInBackground => false;

  static const maxSeries = 0;

  Future<void> scheduleReminder({
    required int baseId,
    required String title,
    required String body,
    required int everyMinutes,
    required int count,
  }) async {}

  Future<void> cancelAll() async {}
}
