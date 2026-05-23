import 'package:flutter/material.dart';

/// A curated, high-fidelity pastel color palette designed for a premium,
/// soothing, and visually balanced user experience.
///
/// Replaces harsh primary colors and pure blacks with harmonized slate,
/// soft emerald sage, peach amber, and light sky blues.
class AppColors {
  AppColors._();

  // Primary — Soft Emerald Sage Mint Pastel (Refreshing and high-fidelity)
  static const Color primary = Color(0xFF7FCD91);
  static const Color primaryLight = Color(0xFFAAE3BA);
  static const Color primaryDark = Color(0xFF5B9E6D);
  static const Color primaryGreen = Color(0xFF7FCD91); // alias
  static const Color primaryGreenLight = Color(0xFFAAE3BA); // alias
  static const Color primaryGreenDark = Color(0xFF5B9E6D); // alias

  // Accent — Soft Peach Apricot Pastel (Warm and inviting)
  static const Color accent = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFFFA726);

  // Surface / Backgrounds
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF9FBFC); // soft clean sky background
  static const Color backgroundGrey = Color(0xFFF3F6F8); // warm grey-blue tint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFECF0F3);
  static const Color cardBg = Color(0xFFF9FAFB);

  // Text — Soft Slate Blue-Greys (Much more premium than harsh pure black)
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textMedium = Color(0xFF78909C);
  static const Color textLight = Color(0xFFCFD8DC);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Semantic (Soft Pastel Tones)
  static const Color success = Color(0xFF81C784); // Soft Sage Green
  static const Color warning = Color(0xFFFFD54F); // Soft Apricot Yellow
  static const Color error = Color(0xFFE57373);   // Soft Coral Red
  static const Color info = Color(0xFF64B5F6);    // Soft Sky Blue

  // Rating
  static const Color starFilled = Color(0xFFFFD54F);
  static const Color starEmpty = Color(0xFFECEFF1);

  // Divider / Border
  static const Color divider = Color(0xFFECEFF1);
  static const Color border = Color(0xFFECEFF1);

  // Shadows
  static const Color cardShadow = Color(0x06000000);
  static const Color shadowMedium = Color(0x0C000000);
}