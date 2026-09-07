import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/run_record.dart';

/// Where the tracker currently stands.
enum TrackerState { idle, acquiring, running, paused, denied, unavailable }

/// Records a run: ticks the clock, follows GPS, accumulates the route.
///
/// The position stream is injectable so tests can drive it without a device.
class RunTracker extends ChangeNotifier {
  RunTracker({Stream<Position> Function()? positionStream, Future<bool> Function()? ensurePermission})
      : _positionStreamFactory = positionStream ?? _defaultPositionStream,
        _ensurePermission = ensurePermission ?? _defaultEnsurePermission;

  final Stream<Position> Function() _positionStreamFactory;
  final Future<bool> Function() _ensurePermission;

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;

  /// Beyond this a "position" is really a guess at which neighbourhood you
  /// are in. Browsers fall back to Wi-Fi positioning, which reports 30-150 m
  /// indoors, so this has to be generous or a laptop records nothing at all.
  static const _maxAccuracyMetres = 100.0;

  /// Movement below this is treated as jitter. Real chips wobble a few metres
  /// while completely stationary, so a 1 m gate still lets a phone on a table
  /// "run" a few hundred metres over an hour.
  static const _minStepMetres = 3.0;

  /// How much of a fix's stated uncertainty a step must exceed to count as
  /// real movement rather than the position estimate drifting.
  static const _accuracyStepFactor = 0.5;

  /// Below this speed the runner is treated as stopped, so the time isn't
  /// counted toward moving time (Strava-style auto-pause). ~1.4 km/h.
  static const _minMovingSpeed = 0.4; // m/s

  /// A single moving interval is capped, so a long no-signal gap between two
  /// fixes doesn't get counted in full as "moving".
  static const _maxStepGapMs = 12000;

  TrackerState _state = TrackerState.idle;

  /// When recording began, and time banked from earlier running segments.
  /// Elapsed time is derived from the wall clock rather than counted with the
  /// ticker: browsers throttle timers in a hidden tab and stop them when the
  /// screen locks, so a counted clock loses most of a pocketed run.
  DateTime? _startedAt;
  DateTime? _segmentStart;
  Duration _banked = Duration.zero;
  double _distanceMeters = 0;
  final List<RunPoint> _route = [];
  RunPoint? _current;
  String? _error;
  double? _accuracyMetres;
  int _movingMillis = 0;
  DateTime? _lastStepAt;

  TrackerState get state => _state;
  Duration get elapsed {
    final segment = _segmentStart;
    if (segment == null) return _banked;
    return _banked + DateTime.now().difference(segment);
  }

  /// When this run began, or null if nothing is being recorded.
  DateTime? get startedAt => _startedAt;
  double get distanceMeters => _distanceMeters;
  double get distanceKm => _distanceMeters / 1000;
  List<RunPoint> get route => List.unmodifiable(_route);
  RunPoint? get current => _current;
  String? get error => _error;

  /// Uncertainty of the most recent fix, in metres. Null before the first one.
  double? get accuracyMetres => _accuracyMetres;

  /// True while fixes are arriving but are too vague to plot.
  bool get hasWeakSignal =>
      _accuracyMetres != null && _accuracyMetres! > _maxAccuracyMetres;

  bool get isRunning => _state == TrackerState.running;
  bool get isPaused => _state == TrackerState.paused;
  bool get isActive => isRunning || isPaused || _state == TrackerState.acquiring;

  /// Time spent actually moving so far.
  int get movingSeconds => _movingMillis ~/ 1000;

  /// Seconds per km so far, based on moving time so stops don't drag it down.
  double get paceSecondsPerKm {
    if (distanceKm <= 0.05) return 0;
    final base = _movingMillis > 0 ? _movingMillis / 1000 : elapsed.inSeconds;
    return base / distanceKm;
  }

  int get estimatedCalories => (distanceKm * 65).round();

  Future<void> start() async {
    _reset();
    _state = TrackerState.acquiring;
    notifyListeners();

    final granted = await _ensurePermission();
    if (!granted) {
      _state = TrackerState.denied;
      _error = 'Location permission denied. Allow location access to record a route.';
      notifyListeners();
      return;
    }

    try {
      _positionSub = _positionStreamFactory().listen(
        _onPosition,
        onError: (Object e) {
          _error = 'Lost GPS signal. Move somewhere with a clearer view of the sky.';
          notifyListeners();
        },
      );
    } catch (e) {
      _state = TrackerState.unavailable;
      _error = 'Location is not available on this device.';
      notifyListeners();
      return;
    }

    _state = TrackerState.running;
    _startedAt = DateTime.now();
    _segmentStart = _startedAt;
    // The ticker only drives the display. Losing ticks to a throttled tab
    // makes the readout update less often, never makes it wrong.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackerState.running) notifyListeners();
    });
    notifyListeners();
  }

  void _onPosition(Position position) {
    _accuracyMetres = position.accuracy;

    // Drop fixes the device itself says it isn't sure about, rather than
    // drawing a route through them. Tell the user this is happening: silently
    // discarding every fix looks identical to the GPS never responding.
    if (position.accuracy > _maxAccuracyMetres) {
      notifyListeners();
      return;
    }

    final point = RunPoint(position.latitude, position.longitude);
    _current = point;
    _error = null;

    // Still counting down the first fix, or paused: track where we are but
    // don't add to the route or the distance.
    if (_state != TrackerState.running) {
      notifyListeners();
      return;
    }

    if (_route.isNotEmpty) {
      final previous = _route.last;
      final metres = Geolocator.distanceBetween(
        previous.lat,
        previous.lng,
        point.lat,
        point.lng,
      );
      // A fix that is only accurate to 60 m cannot prove you moved 10 m, so
      // the step has to clear the fix's own uncertainty as well as the
      // fixed jitter floor.
      final threshold =
          math.max(_minStepMetres, position.accuracy * _accuracyStepFactor);
      if (metres < threshold) {
        notifyListeners();
        return;
      }
      _distanceMeters += metres;

      // Count the interval toward moving time only if it was covered at a
      // real pace; a slow crawl between far-apart fixes reads as a stop.
      final now = DateTime.now();
      if (_lastStepAt != null) {
        final gapMs = now.difference(_lastStepAt!).inMilliseconds;
        if (gapMs > 0) {
          final speed = metres / (gapMs / 1000); // m/s
          if (speed >= _minMovingSpeed) {
            _movingMillis += gapMs.clamp(0, _maxStepGapMs);
          }
        }
      }
      _lastStepAt = now;
    }

    if (_route.isEmpty) {
      // First recorded point: start the moving-time reference here.
      _lastStepAt = DateTime.now();
    }
    _route.add(point);
    notifyListeners();
  }

  void pause() {
    if (_state != TrackerState.running) return;
    final segment = _segmentStart;
    if (segment != null) {
      _banked += DateTime.now().difference(segment);
      _segmentStart = null;
    }
    _state = TrackerState.paused;
    notifyListeners();
  }

  void resume() {
    if (_state != TrackerState.paused) return;
    _segmentStart = DateTime.now();
    _state = TrackerState.running;
    notifyListeners();
  }

  /// Stops recording and returns the finished run, or null if nothing useful
  /// was captured.
  RunRecord? finish() {
    _stopStreams();

    final total = elapsed;
    final began = _startedAt ?? DateTime.now().subtract(total);
    _banked = total;
    _segmentStart = null;
    _state = TrackerState.idle;

    if (_route.isEmpty && total.inSeconds < 1) {
      notifyListeners();
      return null;
    }

    final run = RunRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: began,
      elapsedSeconds: total.inSeconds,
      movingSeconds: movingSeconds,
      distanceMeters: _distanceMeters,
      route: List.of(_route),
    );
    notifyListeners();
    return run;
  }

  void discard() {
    _stopStreams();
    _reset();
    notifyListeners();
  }

  void _reset() {
    _state = TrackerState.idle;
    _startedAt = null;
    _segmentStart = null;
    _banked = Duration.zero;
    _movingMillis = 0;
    _lastStepAt = null;
    _distanceMeters = 0;
    _route.clear();
    _current = null;
    _error = null;
    _accuracyMetres = null;
  }

  void _stopStreams() {
    _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }

  // ── Real device implementations ───────────────────────────────────

  static Stream<Position> _defaultPositionStream() =>
      Geolocator.getPositionStream(locationSettings: _locationSettings());

  /// iOS needs its own settings to keep recording once the screen locks. The
  /// web has no equivalent: browsers suspend the page, so a run there is only
  /// tracked while the app is open and in front.
  static LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        // Requires the location background mode in Info.plist; without it
        // iOS terminates the app instead of delivering updates.
        allowBackgroundLocationUpdates: true,
        // iOS otherwise pauses updates when it thinks you have stopped, which
        // silently truncates a run at a long traffic light.
        pauseLocationUpdatesAutomatically: false,
        // Shows the blue "in use" indicator, so background tracking is never
        // invisible to the user.
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }

  static Future<bool> _defaultEnsurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
