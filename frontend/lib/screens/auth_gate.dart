import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/movara_colors.dart';
import 'home_shell.dart';
import 'sign_in_screen.dart';

/// Shows the app when signed in, the sign-in screen otherwise.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.isDark,
    required this.onToggleTheme,
  });

  final AuthService auth;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return StreamBuilder<User?>(
      stream: auth.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: c.bg,
            body: Center(child: CircularProgressIndicator(color: c.accent)),
          );
        }

        if (snapshot.data == null) {
          return SignInScreen(auth: auth);
        }

        return HomeShell(
          key: ValueKey(snapshot.data!.uid),
          auth: auth,
          isDark: isDark,
          onToggleTheme: onToggleTheme,
        );
      },
    );
  }
}
