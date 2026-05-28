import 'package:flutter/material.dart';

/// Centralized color palette for the Omni User app.
/// Brand color: Omni Green #1C683C
class AppColors {
  AppColors._();

  // ── Brand Colors ──────────────────────────────────────────────
  static const Color primary = Color(0xFF1C683C);        // Omni Green
  static const Color primaryLight = Color(0xFF2A8A52);   // Lighter Omni Green
  static const Color primaryDark = Color(0xFF0F4A28);    // Deeper Omni Green
  static const Color primaryGreen = Color(0xFF1C683C);   // alias
  static const Color primaryGreenLight = Color(0xFF2A8A52); // alias
  static const Color primaryGreenDark = Color(0xFF0F4A28);  // alias

  // ── Accent ───────────────────────────────────────────────────
  static const Color accent = Color(0xFFF5C518);         // Omni Yellow
  static const Color accentDark = Color(0xFFD4A800);     // Deeper Yellow

  // ── Surface / Backgrounds ────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF6FAF7);     // Green-tinted off-white
  static const Color backgroundGrey = Color(0xFFEFF4F0); // Warm grey-green
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFE8F0EA);
  static const Color cardBg = Color(0xFFF9FAFB);

  // ── Text ─────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF111C16);       // Near-black green cast
  static const Color textMedium = Color(0xFF4F6657);     // Muted green-grey
  static const Color textLight = Color(0xFF94A89D);      // Subtle grey-green
  static const Color textWhite = Color(0xFFFFFFFF);

  // ── Semantic ─────────────────────────────────────────────────
  static const Color success = Color(0xFF1C683C);
  static const Color warning = Color(0xFFF5C518);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF1565C0);

  // ── Rating ───────────────────────────────────────────────────
  static const Color starFilled = Color(0xFFF5C518);
  static const Color starEmpty = Color(0xFFDDE6E0);

  // ── Divider / Border ─────────────────────────────────────────
  static const Color divider = Color(0xFFE4EDE7);
  static const Color border = Color(0xFFE4EDE7);

  // ── Shadows ──────────────────────────────────────────────────
  static const Color cardShadow = Color(0x06000000);
  static const Color shadowMedium = Color(0x0C000000);
}
