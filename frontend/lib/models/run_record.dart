import 'dart:convert';

/// One GPS sample along a route. Kept free of any map-library types so the
/// model stays testable and the mapping package remains swappable.
class RunPoint {
  const RunPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory RunPoint.fromJson(Map<String, dynamic> json) =>
      RunPoint((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());
}

/// A completed run: how far, how long, and the path taken.
class RunRecord {
  const RunRecord({
    required this.id,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.route,
    this.movingSeconds = 0,
  });

  final String id;
  final DateTime startedAt;
  final int elapsedSeconds;
  final double distanceMeters;
  final List<RunPoint> route;

  /// Time spent actually moving (Strava-style), used for pace. Older runs
  /// saved before this existed have 0 and fall back to elapsed time.
  final int movingSeconds;

  double get distanceKm => distanceMeters / 1000;

  Duration get elapsed => Duration(seconds: elapsedSeconds);

  /// Seconds counted toward pace: moving time when we have it, else elapsed.
  int get paceBaseSeconds => movingSeconds > 0 ? movingSeconds : elapsedSeconds;

  /// Seconds per kilometre, based on moving time so that standing still does
  /// not drag the pace down. Zero until enough distance exists to be
  /// meaningful — a few GPS jitters shouldn't produce a wild pace.
  double get paceSecondsPerKm =>
      distanceKm > 0.05 ? paceBaseSeconds / distanceKm : 0;

  /// Rough estimate only: running burns very roughly 65 kcal per km for an
  /// average adult. Deliberately simple and deterministic — there is no
  /// heart-rate sensor behind it, so it is labelled as an estimate in the UI.
  int get estimatedCalories => (distanceKm * 65).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'movingSeconds': movingSeconds,
        'distanceMeters': distanceMeters,
        'route': route.map((p) => p.toJson()).toList(),
      };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        elapsedSeconds: json['elapsedSeconds'] as int,
        movingSeconds: json['movingSeconds'] as int? ?? 0,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        route: (json['route'] as List<dynamic>)
            .map((p) => RunPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  static String encodeList(List<RunRecord> runs) =>
      jsonEncode(runs.map((r) => r.toJson()).toList());

  static List<RunRecord> decodeList(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((r) => RunRecord.fromJson(r as Map<String, dynamic>))
          .toList();
}

/// mm:ss, or h:mm:ss once past an hour.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Pace as m:ss, or -- when there is not enough distance to judge.
String formatPace(double secondsPerKm) {
  if (secondsPerKm <= 0 || !secondsPerKm.isFinite) return '--:--';
  final m = secondsPerKm ~/ 60;
  final s = (secondsPerKm % 60).floor().toString().padLeft(2, '0');
  return '$m:$s';
}
