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
      final valid = points.where((p) {
        final v = p.value.toDouble();
        return v.isFinite && v > 0;
      }).toList();
      if (valid.isEmpty) return null;
      valid.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      return valid.last.value.round();
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
      // Keep only sane readings — some sources emit 0 or garbage samples.
      final values = points
          .map((p) => p.value.toDouble())
          .where((v) => v.isFinite && v > 0)
          .toList();
      if (values.isEmpty) return null;
      final avg = values.reduce((a, b) => a + b) / values.length;
      return avg.round();
    } catch (_) {
      return null;
    }
  }

  /// Total real steps between two times, or null. Overlapping samples from
  /// several sources (iPhone + Watch) can carry corrections, so only positive,
  /// finite counts are summed and the total is never returned negative.
  Future<int?> steps(DateTime start, DateTime end) async {
    if (!isSupported) return null;
    try {
      final points =
          await _health.getHealthDataFromTypes(start, end, [HealthDataType.STEPS]);
      final total = points.fold<double>(0, (sum, p) {
        final v = p.value.toDouble();
        return (v.isFinite && v > 0) ? sum + v : sum;
      });
      final rounded = total.round();
      return rounded > 0 ? rounded : null;
    } catch (_) {
      return null;
    }
  }
}
