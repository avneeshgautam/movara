import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the Figma export's CSS custom properties
/// (`src/index.css`). Material's [ColorScheme] has no slot for things like
/// `--surface-3` or `--text-muted`, so they ride along as a theme extension
/// and stay theme-aware in both light and dark.
@immutable
class MovaraColors extends ThemeExtension<MovaraColors> {
  const MovaraColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.accentGlow,
    required this.green,
    required this.greenSoft,
    required this.blue,
    required this.blueSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color accentGlow;
  final Color green;
  final Color greenSoft;
  final Color blue;
  final Color blueSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// `:root` in index.css — the design's default.
  static const dark = MovaraColors(
    bg: Color(0xFF0C0C10),
    surface: Color(0xFF16161E),
    surface2: Color(0xFF1E1E2A),
    surface3: Color(0xFF252534),
    border: Color(0xFF2A2A3A),
    accent: Color(0xFFF97316),
    accentSoft: Color(0x26F97316), // rgba(249,115,22,0.15)
    accentGlow: Color(0x59F97316), // rgba(249,115,22,0.35)
    green: Color(0xFF22C55E),
    greenSoft: Color(0x2622C55E),
    blue: Color(0xFF60A5FA),
    blueSoft: Color(0x2660A5FA),
    textPrimary: Color(0xFFF0F0F8),
    textSecondary: Color(0xFF8888AA),
    textMuted: Color(0xFF55556A),
  );

  /// `:root.light` in index.css.
  static const light = MovaraColors(
    bg: Color(0xFFF5F5F0),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEFEA),
    surface3: Color(0xFFE5E5DF),
    border: Color(0xFFD8D8D0),
    accent: Color(0xFFEA6C0A),
    accentSoft: Color(0x1FEA6C0A), // rgba(234,108,10,0.12)
    accentGlow: Color(0x4DEA6C0A), // rgba(234,108,10,0.30)
    green: Color(0xFF16A34A),
    greenSoft: Color(0x1F16A34A),
    blue: Color(0xFF2563EB),
    blueSoft: Color(0x1F2563EB),
    textPrimary: Color(0xFF111118),
    textSecondary: Color(0xFF55556A),
    textMuted: Color(0xFF9999AA),
  );

  /// Convenience accessor: `context.movara.accent`.
  static MovaraColors of(BuildContext context) =>
      Theme.of(context).extension<MovaraColors>() ?? dark;

  @override
  MovaraColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? accentGlow,
    Color? green,
    Color? greenSoft,
    Color? blue,
    Color? blueSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return MovaraColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentGlow: accentGlow ?? this.accentGlow,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      blue: blue ?? this.blue,
      blueSoft: blueSoft ?? this.blueSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  MovaraColors lerp(ThemeExtension<MovaraColors>? other, double t) {
    if (other is! MovaraColors) return this;
    return MovaraColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueSoft: Color.lerp(blueSoft, other.blueSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Lets widgets read tokens as `context.movara.accent`.
extension MovaraColorsX on BuildContext {
  MovaraColors get movara => MovaraColors.of(this);
}
