import 'package:flutter/material.dart';

/// Premium light theme color palette for RoadSOS.
/// Meticulously aligned with the specified visual design system.
abstract final class AppColors {
  // ── Color Tokens (Step 2) ───────────────────────────────────────────
  static const Color scaffoldBg       = Color(0xFFF5F6F8); // warm off-white, NOT pure white
  static const Color surfacePrimary   = Color(0xFFFFFFFF); // cards, sheets
  static const Color surfaceSecondary = Color(0xFFF0F2F5); // input fills, inner sections
  static const Color primary          = Color(0xFF1A56DB); // brand blue
  static const Color primaryLight     = Color(0xFFEEF3FF); // icon badges, tints
  static const Color emergency        = Color(0xFFDC2626); // SOS, alerts
  static const Color emergencyLight   = Color(0xFFFEF2F2); // emergency card bg
  static const Color textPrimary      = Color(0xFF0F172A); // headings
  static const Color textSecondary    = Color(0xFF475569); // body — never go lighter for real content
  static const Color textTertiary     = Color(0xFF94A3B8); // metadata only
  static const Color borderSubtle     = Color(0xFFE2E8F0); // card borders, dividers

  // ── Semantic Aliases (Ensuring full compatibility) ──────────────────
  static const Color background = scaffoldBg;
  static const Color surface = surfacePrimary;
  static const Color surfaceLight = surfaceSecondary;
  static const Color surfaceAlt = surfaceSecondary;
  
  static const Color emergencyRed = emergency;
  static const Color infoBlue = primary;
  static const Color policeBlue = primary;
  static const Color safeGreen = Color(0xFF10B981); // standard success green
  static const Color warningAmber = Color(0xFFF59E0B); // warning amber
  static const Color textOnDark = Colors.white;

  static const Color border = borderSubtle;
  static const Color borderStrong = Color(0xFFCBD5E1); // intermediate border
  static const Color divider = borderSubtle;
  static const Color shadowColor = Color(0x0A000000); // Step 4 shadow color

  // Legacy compat aliases
  static const Color text = textPrimary;
  static const Color textOnPrimary = textOnDark;
  static const Color textMuted = textTertiary;
  static const Color cardBackground = surfacePrimary;
  static const Color bgPrimary = scaffoldBg;
  static const Color bgSurface = surfacePrimary;
  static const Color bgSurfaceAlt = surfaceSecondary;
  static const Color emergencyAmber = warningAmber;
  static const Color trustNavy = Color(0xFF0B2A4A);
  static const Color towingOrange = Color(0xFFF97316);
  static const Color statusActive = safeGreen;

  // ── Gradients ────────────────────────────────────────────────────────
  static const LinearGradient emergencyGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33DC2626),
      Color(0x00DC2626),
    ],
  );

  static const LinearGradient surfaceSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x14000000),
      Color(0x00000000),
    ],
  );
}
