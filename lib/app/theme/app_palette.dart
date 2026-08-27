import 'package:flutter/material.dart';

/// Brand palette for PocketStrike.
///
/// Dark mode uses a green accent on pure OLED black (#000000); light mode swaps
/// to a blue accent on soft white while keeping identical layout/spacing rules.
class AppPalette {
  const AppPalette._();

  // ---- Dark mode (Pure OLED Black & White Glass) ----
  static const Color darkBase = Color(0xFF000000);
  static const Color darkBaseAlt = Color(0xFF09090B);
  static const Color darkGlass = Color(0xFF141417);
  static const Color darkAccent = Color(0xFFFFFFFF);
  static const Color darkAccentPressed = Color(0xFFD4D4D8);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);

  // ---- Light mode ----
  static const Color lightBase = Color(0xFFFAFAFC);
  static const Color lightGlass = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFF2979FF);
  static const Color lightAccentPressed = Color(0xFF1565C0);
  static const Color lightTextPrimary = Color(0xFF16181D);
  static const Color lightTextSecondary = Color(0xFF5F6368);
  static const Color lightBorder = Color(0xFFE2E4E9);

  // ---- Shared states ----
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);

  /// Terminal-style surface used by the agent run timeline.
  static const Color terminalDark = Color(0xFF09090B);
  static const Color terminalLight = Color(0xFFF2F4F7);
}
