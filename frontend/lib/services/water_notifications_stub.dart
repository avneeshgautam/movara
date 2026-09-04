/// No-op implementation for non-web targets (and the test VM).
class WaterNotifications {
  const WaterNotifications();

  bool get isSupported => false;

  /// One of: granted, denied, default, unsupported.
  String get permission => 'unsupported';

  Future<String> requestPermission() async => 'unsupported';

  void show(String title, String body) {}
}
