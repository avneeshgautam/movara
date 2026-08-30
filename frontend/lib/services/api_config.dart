import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Base URL of the Spring Boot backend.
///
/// - Web / desktop / iOS simulator: the backend on the same machine is
///   reachable at `localhost`.
/// - Android emulator: `localhost` refers to the emulator itself, so the
///   host machine is reached via the special alias `10.0.2.2` instead.
///
/// Override with `--dart-define=API_BASE_URL=http://192.168.x.x:8080/api`
/// when running against a backend on another machine (e.g. a physical
/// device on the same network).
String get apiBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8080/api';
  }
  return 'http://localhost:8080/api';
}
