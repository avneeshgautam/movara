import 'package:firebase_core/firebase_core.dart';

/// Firebase client configuration, supplied at build time via --dart-define.
///
/// These values are public by design — they identify the project, they do not
/// authorise anything — so they are passed as defines rather than committing a
/// generated options file or placeholder values that look real.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  /// True once the build was given a real Firebase project.
  static bool get isConfigured =>
      apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
      );
}
