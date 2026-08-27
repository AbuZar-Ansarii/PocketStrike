import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Glassmorphism design tokens exposed as a [ThemeExtension] so every widget
/// can read the current theme's blur / border / radius / accent values.
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.glassColor,
    required this.glassBorder,
    required this.blurSigma,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.textSecondary,
    required this.terminalSurface,
    required this.softShadow,
  });

  /// Frosted panel fill (opacity already baked in).
  final Color glassColor;

  /// Subtle glass outline.
  final Color glassBorder;

  /// Sigma used with ImageFilter.blur / BackdropFilter.
  final double blurSigma;

  final double radiusSm; // 10 - sleek
  final double radiusMd; // 14 - medium
  final double radiusLg; // 20 - sheet/dialogs

  final Color accent;
  final Color accentPressed;
  final Color onAccent;
  final Color textSecondary;
  final Color terminalSurface;
  final List<BoxShadow> softShadow;

  static GlassTokens dark() => GlassTokens(
        glassColor: Colors.white.withValues(alpha: 0.07),
        glassBorder: Colors.white.withValues(alpha: 0.15),
        blurSigma: 20,
        radiusSm: 10,
        radiusMd: 14,
        radiusLg: 20,
        accent: AppPalette.darkAccent,
        accentPressed: AppPalette.darkAccentPressed,
        onAccent: const Color(0xFF000000),
        textSecondary: AppPalette.darkTextSecondary,
        terminalSurface: AppPalette.terminalDark,
        softShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static GlassTokens light() => GlassTokens(
        glassColor: AppPalette.lightGlass.withValues(alpha: 0.65),
        glassBorder: AppPalette.lightBorder.withValues(alpha: 0.8),
        blurSigma: 18,
        radiusSm: 10,
        radiusMd: 14,
        radiusLg: 20,
        accent: AppPalette.lightAccent,
        accentPressed: AppPalette.lightAccentPressed,
        onAccent: Colors.white,
        textSecondary: AppPalette.lightTextSecondary,
        terminalSurface: AppPalette.terminalLight,
        softShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  GlassTokens copyWith({
    Color? glassColor,
    Color? glassBorder,
    double? blurSigma,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    Color? accent,
    Color? accentPressed,
    Color? onAccent,
    Color? textSecondary,
    Color? terminalSurface,
    List<BoxShadow>? softShadow,
  }) {
    return GlassTokens(
      glassColor: glassColor ?? this.glassColor,
      glassBorder: glassBorder ?? this.glassBorder,
      blurSigma: blurSigma ?? this.blurSigma,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      onAccent: onAccent ?? this.onAccent,
      textSecondary: textSecondary ?? this.textSecondary,
      terminalSurface: terminalSurface ?? this.terminalSurface,
      softShadow: softShadow ?? this.softShadow,
    );
  }

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    return GlassTokens(
      glassColor: Color.lerp(glassColor, other.glassColor, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      radiusSm: radiusSm + (other.radiusSm - radiusSm) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      terminalSurface:
          Color.lerp(terminalSurface, other.terminalSurface, t)!,
      softShadow: t < 0.5 ? softShadow : other.softShadow,
    );
  }
}

extension GlassTokensX on BuildContext {
  /// Shortcut for the current [GlassTokens].
  GlassTokens get glass => Theme.of(this).extension<GlassTokens>()!;
}
