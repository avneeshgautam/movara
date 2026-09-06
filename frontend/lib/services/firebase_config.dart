import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client configuration.
///
/// On the web these come from --dart-define at build time. The values are
/// public by design — they identify the project, they do not authorise
/// anything — so they are passed as defines rather than committing a
/// generated options file or placeholder values that look real.
///
/// On iOS the native SDK reads ios/Runner/GoogleService-Info.plist instead.
/// That file describes a *different* Firebase app (its own appId and key), so
/// handing it the web app's options would point the phone at the wrong app.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  /// True once the build was given a real Firebase project. Off the web this
  /// is decided by the bundled config file, which we cannot inspect here, so
  /// initialisation is attempted and failure falls through to the setup
  /// screen.
  static bool get isConfigured =>
      !kIsWeb || (apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty);

  /// Options to initialise with, or null to let the platform read its own
  /// bundled config.
  static FirebaseOptions? get platformOptions => kIsWeb ? options : null;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
      );
}
