import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in on top of Firebase Authentication.
///
/// Phone/OTP is deliberately not here yet: it needs billing enabled on the
/// Firebase project and, in India, DLT registration for transactional SMS.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get userChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Current Firebase ID token, sent to the backend as a bearer token.
  /// Firebase refreshes this automatically as it nears expiry.
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // The web SDK drives the whole OAuth flow itself.
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }

    final account = await GoogleSignIn().signIn();
    if (account == null) return; // user dismissed the picker

    final google = await account.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: google.accessToken,
        idToken: google.idToken,
      ),
    );
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Signing out of Firebase below is what actually matters.
      }
    }
    await _auth.signOut();
  }
}
