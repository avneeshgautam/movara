import 'dart:convert';

/// The kind of activity a recording is. Each carries its own label, emoji and
/// a rough kcal-per-km factor for the calorie estimate.
enum ActivityType {
  run('Run', '🏃', 65),
  walk('Walk', '🚶', 50),
  hike('Hike', '🥾', 55);

  const ActivityType(this.label, this.emoji, this.kcalPerKm);

  final String label;
  final String emoji;
  final double kcalPerKm;

  static ActivityType fromName(String? name) => ActivityType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => ActivityType.run,
      );
}

/// One GPS sample along a route. Kept free of any map-library types so the
/// model stays testable and the mapping package remains swappable.
class RunPoint {
  const RunPoint(this.lat, this.lng, [this.altitude]);

  final double lat;
  final double lng;

  /// Metres above sea level, when the device reports it (null on the web,
  /// where browsers don't expose altitude).
  final double? altitude;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (altitude != null) 'alt': altitude,
      };

  factory RunPoint.fromJson(Map<String, dynamic> json) => RunPoint(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
        (json['alt'] as num?)?.toDouble(),
      );
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
    this.activityType = ActivityType.run,
    this.elevationGainMeters = 0,
  });

  final String id;
  final DateTime startedAt;
  final int elapsedSeconds;
  final double distanceMeters;
  final List<RunPoint> route;

  /// Time spent actually moving (Strava-style), used for pace. Older runs
  /// saved before this existed have 0 and fall back to elapsed time.
  final int movingSeconds;

  /// Run / Walk / Hike. Old records saved before this existed default to run.
  final ActivityType activityType;

  /// Total metres climbed over the activity (sum of positive, smoothed
  /// altitude changes). Zero when altitude was never available.
  final double elevationGainMeters;

  double get distanceKm => distanceMeters / 1000;

  /// Highest altitude reached along the route, or null if none was recorded.
  double? get maxAltitude {
    double? best;
    for (final p in route) {
      final a = p.altitude;
      if (a != null && (best == null || a > best)) best = a;
    }
    return best;
  }

  Duration get elapsed => Duration(seconds: elapsedSeconds);

  /// Seconds counted toward pace: moving time when we have it, else elapsed.
  int get paceBaseSeconds => movingSeconds > 0 ? movingSeconds : elapsedSeconds;

  /// Seconds per kilometre, based on moving time so that standing still does
  /// not drag the pace down. Zero until enough distance exists to be
  /// meaningful — a few GPS jitters shouldn't produce a wild pace.
  double get paceSecondsPerKm =>
      distanceKm > 0.05 ? paceBaseSeconds / distanceKm : 0;

  /// Rough estimate only: a per-activity kcal-per-km factor plus roughly
  /// 0.5 kcal for every metre climbed. Deliberately simple and deterministic
  /// — there is no heart-rate sensor behind it, so it is labelled as an
  /// estimate in the UI.
  int get estimatedCalories =>
      (distanceKm * activityType.kcalPerKm + elevationGainMeters * 0.5).round();

  /// Rough step estimate from distance, using an average walking stride of
  /// ~0.75 m (about 1,300 steps per km). Deterministic and labelled as an
  /// estimate in the UI — there is no pedometer sensor behind it.
  int get estimatedSteps =>
      distanceMeters <= 0 ? 0 : (distanceMeters / 0.75).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'movingSeconds': movingSeconds,
        'distanceMeters': distanceMeters,
        'activityType': activityType.name,
        'elevationGain': elevationGainMeters,
        'route': route.map((p) => p.toJson()).toList(),
      };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        elapsedSeconds: json['elapsedSeconds'] as int,
        movingSeconds: json['movingSeconds'] as int? ?? 0,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        activityType: ActivityType.fromName(json['activityType'] as String?),
        elevationGainMeters:
            (json['elevationGain'] as num?)?.toDouble() ?? 0,
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

/// A step count with thousands separators, e.g. 1,342. Never negative.
String formatSteps(int steps) {
  final s = (steps < 0 ? 0 : steps).toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Pace as m:ss, or -- when there is not enough distance to judge.
String formatPace(double secondsPerKm) {
  if (secondsPerKm <= 0 || !secondsPerKm.isFinite) return '--:--';
  final m = secondsPerKm ~/ 60;
  final s = (secondsPerKm % 60).floor().toString().padLeft(2, '0');
  return '$m:$s';
}
