/// No-op implementation for platforms with no notification support (and the
/// test VM).
class WaterNotifications {
  const WaterNotifications();

  bool get isSupported => false;

  /// One of: granted, denied, default, unsupported.
  String get permission => 'unsupported';

  Future<String> requestPermission() async => 'unsupported';

  Future<void> show(String title, String body) async {}

  /// True when the platform delivers reminders itself, so the app does not
  /// have to be open for one to arrive.
  bool get schedulesInBackground => false;

  static const maxSeries = 0;

  Future<void> scheduleReminder({
    required int baseId,
    required String title,
    required String body,
    required List<DateTime> at,
  }) async {}

  Future<void> scheduleWeeklyAt({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  Future<void> cancelRange(int from, int to) async {}

  Future<bool> isScheduled(int id) async => false;

  Future<void> cancelAll() async {}

  Future<void> scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  Future<void> cancel(int id) async {}
}
