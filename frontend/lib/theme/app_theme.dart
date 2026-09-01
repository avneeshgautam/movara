import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'movara_colors.dart';

/// Builds the app themes from the Figma design tokens in [MovaraColors].
///
/// Typography follows the design: Syne for display/headings, Inter for body.
class AppTheme {
  static ThemeData dark() => _build(MovaraColors.dark, Brightness.dark);

  static ThemeData light() => _build(MovaraColors.light, Brightness.light);

  /// Syne — used for headings, numbers and anything that should feel like a
  /// display face. Exposed so widgets can opt in per-text-span.
  static TextStyle display({
    required Color color,
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.syne(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData _build(MovaraColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      surface: c.surface,
      error: const Color(0xFFEF4444),
    );

    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      extensions: [c],
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(color: c.textPrimary, fontSize: 20),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: TextStyle(color: c.textMuted),
        labelStyle: TextStyle(color: c.textSecondary),
        prefixIconColor: c.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: c.border,
      iconTheme: IconThemeData(color: c.textSecondary),
    );
  }
}
