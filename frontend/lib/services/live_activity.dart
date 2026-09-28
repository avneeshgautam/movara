import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Starts/updates/ends the iOS Live Activity (Lock Screen + Dynamic Island)
/// that shows a live timer and distance while an activity is recording.
///
/// iOS-only; every call is a no-op elsewhere and swallows platform errors, so
/// the app behaves normally on the web and on iPhones before iOS 16.1.
class LiveActivity {
  static const _channel = MethodChannel('movara/live_activity');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// [elapsed] backdates the Lock Screen timer (a resumed gym workout keeps
  /// its total); [showsDistance] hides the km readout for gym workouts.
  static Future<void> start(
    String label,
    String emoji, {
    bool showsDistance = true,
    Duration elapsed = Duration.zero,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('start', {
        'label': label,
        'emoji': emoji,
        'showsDistance': showsDistance,
        'elapsedSeconds': elapsed.inMilliseconds / 1000,
      });
    } catch (_) {}
  }

  static Future<void> update(double distanceKm) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('update', {'distanceKm': distanceKm});
    } catch (_) {}
  }

  static Future<void> end() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('end');
    } catch (_) {}
  }
}
