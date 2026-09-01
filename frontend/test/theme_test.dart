import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movara_app/theme/app_theme.dart';
import 'package:movara_app/theme/movara_colors.dart';
import 'package:movara_app/widgets/movara_header.dart';

import 'test_setup.dart';

void main() {
  setUpAll(disableGoogleFontsNetwork);

  // These use testWidgets rather than test: building a theme touches
  // google_fonts, which needs an initialised Flutter binding.
  group('AppTheme', () {
    testWidgets('dark and light both carry the MovaraColors extension',
        (tester) async {
      expect(AppTheme.dark().extension<MovaraColors>(), MovaraColors.dark);
      expect(AppTheme.light().extension<MovaraColors>(), MovaraColors.light);
    });

    testWidgets('scaffold background follows the design token', (tester) async {
      expect(AppTheme.dark().scaffoldBackgroundColor, MovaraColors.dark.bg);
      expect(AppTheme.light().scaffoldBackgroundColor, MovaraColors.light.bg);
    });

    testWidgets('the two themes are actually different', (tester) async {
      expect(
        AppTheme.dark().scaffoldBackgroundColor,
        isNot(AppTheme.light().scaffoldBackgroundColor),
      );
    });
  });

  group('MovaraColors.of', () {
    testWidgets('resolves the light palette under the light theme', (tester) async {
      late MovaraColors resolved;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(builder: (context) {
          resolved = MovaraColors.of(context);
          return const SizedBox();
        }),
      ));

      expect(resolved, MovaraColors.light);
      expect(resolved.accent, const Color(0xFFEA6C0A));
    });

    testWidgets('falls back to dark when no extension is registered', (tester) async {
      late MovaraColors resolved;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          resolved = MovaraColors.of(context);
          return const SizedBox();
        }),
      ));

      expect(resolved, MovaraColors.dark);
    });
  });

  group('MovaraHeader', () {
    test('greeting switches on the hour', () {
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 9)), 'Good Morning');
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 13)), 'Good Afternoon');
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 20)), 'Good Evening');
      // Boundaries.
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 11, 59)), 'Good Morning');
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 12)), 'Good Afternoon');
      expect(MovaraHeader.greetingFor(DateTime(2026, 8, 31, 17)), 'Good Evening');
    });

    testWidgets('renders the wordmark and the toggle label for each mode',
        (tester) async {
      for (final isDark in [true, false]) {
        await tester.pumpWidget(MaterialApp(
          theme: isDark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: MovaraHeader(
              username: 'Alex',
              isDark: isDark,
              onToggleTheme: () {},
            ),
          ),
        ));

        expect(find.text('MOVARA'), findsOneWidget);
        expect(find.text(isDark ? 'Dark' : 'Light'), findsOneWidget);
        // Avatar initial.
        expect(find.text('A'), findsOneWidget);
      }
    });

    testWidgets('tapping the toggle fires the callback', (tester) async {
      var toggled = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: MovaraHeader(
            username: 'Alex',
            isDark: true,
            onToggleTheme: () => toggled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(toggled, isTrue);
    });
  });
}
