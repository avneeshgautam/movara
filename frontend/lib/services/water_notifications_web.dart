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

  void show(String title, String body) {
    if (permission != 'granted') return;
    try {
      web.Notification(title, web.NotificationOptions(body: body));
    } catch (_) {
      // Some browsers require a service worker for notifications; ignore.
    }
  }
}
