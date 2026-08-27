import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';
import 'glass_tokens.dart';

/// Builds the fully custom glass [ThemeData] for both modes.
class AppTheme {
  const AppTheme._();

  /// Monospace family used for code blocks, tool calls and agent logs.
  static TextStyle mono({
    double fontSize = 13,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: 1.45,
      );

  static TextTheme _textTheme(TextTheme base, Color primary, Color secondary) {
    return GoogleFonts.manropeTextTheme(base)
        .apply(bodyColor: primary, displayColor: primary)
        .copyWith(
          headlineSmall: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: primary,
          ),
          titleLarge: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: primary,
          ),
          titleMedium: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: primary,
          ),
          bodySmall: GoogleFonts.manrope(fontSize: 12.5, color: secondary),
        );
  }

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        base: AppPalette.darkBase,
        surface: AppPalette.darkBaseAlt,
        glass: AppPalette.darkGlass,
        accent: AppPalette.darkAccent,
        onAccent: const Color(0xFF000000),
        textPrimary: AppPalette.darkTextPrimary,
        textSecondary: AppPalette.darkTextSecondary,
        outline: const Color(0xFF27272A),
        divider: Colors.white.withValues(alpha: 0.12),
        tokens: GlassTokens.dark(),
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        base: AppPalette.lightBase,
        surface: Colors.white,
        glass: const Color(0xFFF1F2F6),
        accent: AppPalette.lightAccent,
        onAccent: Colors.white,
        textPrimary: AppPalette.lightTextPrimary,
        textSecondary: AppPalette.lightTextSecondary,
        outline: AppPalette.lightBorder,
        divider: AppPalette.lightBorder.withValues(alpha: 0.7),
        tokens: GlassTokens.light(),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color base,
    required Color surface,
    required Color glass,
    required Color accent,
    required Color onAccent,
    required Color textPrimary,
    required Color textSecondary,
    required Color outline,
    required Color divider,
    required GlassTokens tokens,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme(
      (isDark ? ThemeData.dark : ThemeData.light)(useMaterial3: true).textTheme,
      textPrimary,
      textSecondary,
    );
    final colorScheme = (isDark
        ? ColorScheme.dark(
            primary: accent,
            onPrimary: onAccent,
            secondary: accent,
            onSecondary: onAccent,
            surface: base, // Pure black surface
            onSurface: textPrimary,
            surfaceContainerHighest: glass,
            error: AppPalette.error,
            onError: Colors.white,
            outline: outline,
          )
        : ColorScheme.light(
            primary: accent,
            onPrimary: onAccent,
            secondary: accent,
            onSecondary: onAccent,
            surface: surface,
            onSurface: textPrimary,
            surfaceContainerHighest: glass,
            error: AppPalette.error,
            onError: Colors.white,
            outline: outline,
          ));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: base,
      canvasColor: base,
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? base : base,
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surface : Colors.white,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: isDark ? BorderSide.none : BorderSide(color: outline),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surface : Colors.white,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: isDark ? null : Border.all(color: outline),
        ),
        textStyle: textTheme.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      extensions: [tokens],
    );
  }
}
