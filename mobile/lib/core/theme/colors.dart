import 'package:flutter/material.dart';

/// Unified light theme color palette for RoadSOS.
/// All colors flow from these tokens — never hardcode hex values in screens.
abstract final class AppColors {
  // ── Core Color Tokens ─────────────────────────────────────────────
  static const Color scaffoldBg       = Color(0xFFF8FBFF); // primary background
  static const Color surfacePrimary   = Color(0xFFFFFFFF); // cards, sheets
  static const Color surfaceSecondary = Color(0xFFEEF6FF); // input fills, headers, inner sections
  static const Color primary          = Color(0xFFA9D3FF); // accent blue
  static const Color primaryLight     = Color(0xFFEEF6FF); // icon badges, tints
  static const Color emergency        = Color(0xFFE53935); // SOS, crash alert, blood badge, destructive ONLY
  static const Color emergencyLight   = Color(0xFFFFF3F3); // emergency card bg
  static const Color textPrimary      = Color(0xFF1E293B); // headings, primary text
  static const Color textSecondary    = Color(0xFF64748B); // body text — floor for real content
  static const Color textTertiary     = Color(0xFF94A3B8); // metadata only
  static const Color borderSubtle     = Color(0xFFDCE7F5); // card borders, dividers

  // ── Semantic Aliases ──────────────────────────────────────────────
  static const Color background = scaffoldBg;
  static const Color surface = surfacePrimary;
  static const Color surfaceLight = surfaceSecondary;
  static const Color surfaceAlt = surfaceSecondary;
  static const Color accentBlue = primary;

  static const Color emergencyRed = emergency;
  static const Color infoBlue = primary;
  static const Color policeBlue = primary;
  static const Color safeGreen = Color(0xFF10B981); // standard success green
  static const Color warningAmber = Color(0xFFF59E0B); // warning amber
  static const Color textOnDark = Colors.white;

  static const Color border = borderSubtle;
  static const Color borderStrong = borderSubtle; // unified border
  static const Color divider = borderSubtle;
  static const Color shadowColor = Color(0x0A000000);

  // Legacy compat aliases
  static const Color text = textPrimary;
  static const Color textOnPrimary = textPrimary; // dark text on light accent
  static const Color textMuted = textTertiary;
  static const Color cardBackground = surfacePrimary;
  static const Color bgPrimary = scaffoldBg;
  static const Color bgSurface = surfacePrimary;
  static const Color bgSurfaceAlt = surfaceSecondary;
  static const Color emergencyAmber = warningAmber;
  static const Color trustNavy = textPrimary; // legacy alias — no dark navy
  static const Color towingOrange = Color(0xFFF97316);
  static const Color statusActive = safeGreen;

  // ── Gradients ────────────────────────────────────────────────────
  static const LinearGradient emergencyGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33E53935),
      Color(0x00E53935),
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
