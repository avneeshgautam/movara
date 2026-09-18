import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Thin wrapper over Apple Health / Health Connect for the metrics an Apple
/// Watch (or the phone) records: heart rate and steps. Read-only.
///
/// Everything is guarded so the app still runs where HealthKit doesn't exist
/// (the web build, or a simulator without Health) — those calls just return
/// null and the UI falls back to its own estimates.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final HealthFactory _health = HealthFactory();

  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  /// HealthKit / Health Connect only exist on a real mobile device.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Asks the OS for read access. Returns true if granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _health.requestAuthorization(_types);
    } catch (_) {
      return false;
    }
  }

  /// The most recent heart-rate sample within [within], or null. Apple Watch
  /// readings reach the phone with a short sync delay, so this is near-live,
  /// not instantaneous.
  Future<int?> latestHeartRate(
      {Duration within = const Duration(minutes: 3)}) async {
    if (!isSupported) return null;
    final now = DateTime.now();
    try {
      final points = await _health.getHealthDataFromTypes(
          now.subtract(within), now, [HealthDataType.HEART_RATE]);
      if (points.isEmpty) return null;
      points.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      return points.last.value.round();
    } catch (_) {
      return null;
    }
  }

  /// Average heart rate over a finished activity, or null if none recorded.
  Future<int?> averageHeartRate(DateTime start, DateTime end) async {
    if (!isSupported) return null;
    try {
      final points = await _health
          .getHealthDataFromTypes(start, end, [HealthDataType.HEART_RATE]);
      if (points.isEmpty) return null;
      final total = points.fold<double>(0, (sum, p) => sum + p.value.toDouble());
      return (total / points.length).round();
    } catch (_) {
      return null;
    }
  }

  /// Total real steps between two times (deduplicated by the plugin), or null.
  Future<int?> steps(DateTime start, DateTime end) async {
    if (!isSupported) return null;
    try {
      final points =
          await _health.getHealthDataFromTypes(start, end, [HealthDataType.STEPS]);
      if (points.isEmpty) return null;
      final total = points.fold<double>(0, (sum, p) => sum + p.value.toDouble());
      return total.round();
    } catch (_) {
      return null;
    }
  }
}
