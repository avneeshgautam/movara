import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/firebase_config.dart';
import 'theme/app_theme.dart';
import 'theme/movara_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      firebaseReady = true;
    } catch (_) {
      // Fall through to the setup screen rather than a blank page.
    }
  }

  runApp(MovaraApp(firebaseReady: firebaseReady));
}

class MovaraApp extends StatefulWidget {
  const MovaraApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<MovaraApp> createState() => _MovaraAppState();
}

class _MovaraAppState extends State<MovaraApp> {
  /// Follow the device's light/dark setting until the user picks one, after
  /// which their choice sticks for the session.
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      // Builder so MediaQuery is in scope: with ThemeMode.system the app has
      // to read the platform brightness to know which way the toggle points.
      home: Builder(
        builder: (context) {
          if (!widget.firebaseReady) return const _FirebaseNotConfigured();

          final isDark = switch (_mode) {
            ThemeMode.system =>
              MediaQuery.platformBrightnessOf(context) == Brightness.dark,
            ThemeMode.dark => true,
            ThemeMode.light => false,
          };

          return AuthGate(
            auth: AuthService(),
            isDark: isDark,
            onToggleTheme: () => setState(
              () => _mode = isDark ? ThemeMode.light : ThemeMode.dark,
            ),
          );
        },
      ),
    );
  }
}

/// Shown when the build was not given Firebase config, so the failure is
/// legible instead of a blank screen or a crash.
class _FirebaseNotConfigured extends StatelessWidget {
  const _FirebaseNotConfigured();

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined, size: 44, color: c.textMuted),
              const SizedBox(height: 18),
              Text(
                'Firebase is not configured',
                style: AppTheme.display(color: c.textPrimary, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'Rebuild with the Firebase web config, for example:\n\n'
                'flutter build web \\\n'
                '  --dart-define=FIREBASE_API_KEY=... \\\n'
                '  --dart-define=FIREBASE_PROJECT_ID=... \\\n'
                '  --dart-define=FIREBASE_APP_ID=...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
