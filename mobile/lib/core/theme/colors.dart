import 'package:flutter/material.dart';

// RoadSOS palettes:
// - Light mode is the DEFAULT launch experience.
// - Dark mode is optional via Settings toggle.

/// Shared semantic colours (same in both themes).
abstract final class AppColors {
  static const Color emergencyRed = Color(0xFFE8334A);
  static const Color emergencyAmber = Color(0xFFFFB020);
  static const Color safeGreen = Color(0xFF22C55E);

  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color policeBlue = Color(0xFF2563EB);
  static const Color towingOrange = Color(0xFFF97316);
  static const Color trustNavy = Color(0xFF0B2A4A);

  static const Color statusActive = safeGreen;

  // ─────────────────────────────────────────────────────────────────────────
  // Legacy aliases (temporary compatibility)
  //
  // Existing screens still reference `AppColors.primary/surface/textSecondary/...`.
  // These map to the DARK palette to preserve existing behavior until each
  // screen is migrated to Theme.of(context)/ColorScheme usage.
  // ─────────────────────────────────────────────────────────────────────────
  static const Color primary = DarkColors.bgPrimary;
  static const Color surface = DarkColors.surface;
  static const Color surfaceAlt = DarkColors.surfaceAlt;
  static const Color surfaceOverlay = DarkColors.surfaceOverlay;

  static const Color bgPrimary = DarkColors.bgPrimary;
  static const Color bgSurface = DarkColors.surface;
  static const Color bgSurfaceAlt = DarkColors.surfaceAlt;

  static const Color textPrimary = DarkColors.textPrimary;
  static const Color textSecondary = DarkColors.textSecondary;
  static const Color textMuted = DarkColors.textMuted;

  static const Color borderSubtle = DarkColors.borderSubtle;
  static const Color borderStrong = DarkColors.borderStrong;

  static const LinearGradient emergencyGlow = DarkColors.emergencyGlow;
  static const LinearGradient surfaceSheen = DarkColors.surfaceSheen;
}

/// Premium Light palette (default).
abstract final class LightColors {
  // Off-white foundation (avoid harsh white)
  static const Color bgPrimary = Color(0xFFF5F3EF);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceAlt = Color(0xFFEDE9E3);
  static const Color surfaceOverlay = Color(0xCCFFFDF8);

  static const Color textPrimary = Color(0xFF14151A);
  static const Color textSecondary = Color(0xFF4A5168);
  static const Color textMuted = Color(0xFF6E7687);

  static const Color borderSubtle = Color(0x1A14151A);
  static const Color borderStrong = Color(0x2E14151A);

  static const LinearGradient emergencyGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1AE8334A), Color(0x00E8334A)],
  );

  static const LinearGradient surfaceSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F1EB)],
  );
}

/// Premium Dark palette (optional).
abstract final class DarkColors {
  static const Color bgPrimary = Color(0xFF05060A);
  static const Color surface = Color(0xFF0B0D14);
  static const Color surfaceAlt = Color(0xFF101428);
  static const Color surfaceOverlay = Color(0xCC0B0D14);

  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFB6C2D9);
  static const Color textMuted = Color(0xFF7E8AA3);

  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  static const LinearGradient emergencyGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33E8334A), Color(0x00E8334A)],
  );

  static const LinearGradient surfaceSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
  );
}
