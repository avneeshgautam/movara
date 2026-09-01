import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MovaraApp());
}

class MovaraApp extends StatefulWidget {
  const MovaraApp({super.key});

  @override
  State<MovaraApp> createState() => _MovaraAppState();
}

class _MovaraAppState extends State<MovaraApp> {
  // The design ships dark-first; the header toggle flips this.
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomeShell(
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}
