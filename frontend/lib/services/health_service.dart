import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Thin wrapper over Apple Health / Health Connect for the metrics an Apple
/// Watch (or the phone, or a synced app like NoiseFit) records: heart rate
/// and steps. Read-only.
///
/// Everything is guarded so the app still runs where HealthKit doesn't exist
/// (the web build) — those calls return null and the UI falls back to its own
/// estimates. Uses the health plugin's dedicated step-total query, which reads
/// steps correctly on modern iOS (a raw sample sum does not).
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  Health? _health;
  bool _configured = false;

  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  /// HealthKit / Health Connect only exist on a real mobile device.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Lazily builds and configures the plugin (never on the web).
  Future<Health?> _ready() async {
    if (!isSupported) return null;
    final health = _health ??= Health();
    if (!_configured) {
      await health.configure();
      _configured = true;
    }
    return health;
  }

  /// Asks the OS for read access to heart rate and steps. Returns true if the
  /// request completed (on iOS this is true whenever the sheet was shown —
  /// HealthKit never discloses whether READ was actually granted).
  Future<bool> requestPermission() async {
    try {
      final health = await _ready();
      if (health == null) return false;
      return await health.requestAuthorization(
        _types,
        permissions: const [HealthDataAccess.READ, HealthDataAccess.READ],
      );
    } catch (_) {
      return false;
    }
  }

  /// The most recent heart-rate reading within [within], or null.
  Future<int?> latestHeartRate(
      {Duration within = const Duration(minutes: 3)}) async {
    try {
      final health = await _ready();
      if (health == null) return null;
      final now = DateTime.now();
      final points = await health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: now.subtract(within),
        endTime: now,
      );
      final valid = points
          .map(_numeric)
          .whereType<double>()
          .where((v) => v.isFinite && v > 0)
          .toList();
      if (valid.isEmpty) return null;
      return valid.last.round();
    } catch (_) {
      return null;
    }
  }

  /// Average heart rate over a finished activity, or null if none recorded.
  Future<int?> averageHeartRate(DateTime start, DateTime end) async {
    try {
      final health = await _ready();
      if (health == null) return null;
      final points = await health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );
      final values = points
          .map(_numeric)
          .whereType<double>()
          .where((v) => v.isFinite && v > 0)
          .toList();
      if (values.isEmpty) return null;
      final avg = values.reduce((a, b) => a + b) / values.length;
      return avg.round();
    } catch (_) {
      return null;
    }
  }

  /// Total steps between two times, using HealthKit's own aggregation, or null.
  Future<int?> steps(DateTime start, DateTime end) async {
    try {
      final health = await _ready();
      if (health == null) return null;
      final total = await health.getTotalStepsInInterval(start, end);
      return (total != null && total > 0) ? total : null;
    } catch (_) {
      return null;
    }
  }

  /// Pulls the numeric value out of a data point, or null for non-numeric.
  double? _numeric(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : null;
  }
}
