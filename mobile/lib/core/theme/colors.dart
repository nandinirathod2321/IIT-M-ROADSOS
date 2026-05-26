import 'package:flutter/material.dart';

/// RoadSOS premium emergency palette — Dark / high-contrast.
///
/// Design intent:
/// - Deep charcoal foundation (trustworthy, calm under stress)
/// - Rich emergency red accents (critical actions)
/// - Subtle blue highlights (authority / navigation)
/// - Premium grayscale for hierarchy
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────
  /// Deep charcoal — main scaffold / background.
  static const Color primary = Color(0xFF05060A);

  /// Primary surface — cards / sheets.
  static const Color surface = Color(0xFF0B0D14);

  /// Alternate surface — elevated cards, inputs.
  static const Color surfaceAlt = Color(0xFF101428);

  /// Soft overlay surface — used for glass / subtle panels.
  static const Color surfaceOverlay = Color(0xCC0B0D14);

  // Aliases for USWDS / gov.nl naming convention
  static const Color bgPrimary = primary;
  static const Color bgSurface = surface;
  static const Color bgSurfaceAlt = surfaceAlt;

  // ── Semantic / Emergency ─────────────────────────────────────────────
  /// SOS button, danger states, critical alerts.
  static const Color emergencyRed = Color(0xFFFF3B4C);

  /// Warnings, secondary alerts, countdown state.
  static const Color emergencyAmber = Color(0xFFFFB020);

  /// Confirmed safe / connected / resolved state.
  static const Color safeGreen = Color(0xFF22C55E);

  // ── Authority / Trust (USWDS) ─────────────────────────────────────────
  /// Navy — authority headers, trust sections.
  static const Color trustNavy = Color(0xFF0B2A4A);

  // ── Service type accents ─────────────────────────────────────────────
  /// Hospitals, informational highlights.
  static const Color infoBlue = Color(0xFF3B82F6);

  /// Police stations.
  static const Color policeBlue = Color(0xFF2563EB);

  /// Towing services.
  static const Color towingOrange = Color(0xFFF97316);

  // ── Text ─────────────────────────────────────────────────────────────
  /// Near-white — main body / headline text.
  static const Color textPrimary = Color(0xFFF4F7FF);

  /// Dark grey — subtitles, labels, secondary copy.
  static const Color textSecondary = Color(0xFFB6C2D9);

  /// Mid grey — disabled text, hints, placeholders (WCAG AA accessible).
  static const Color textMuted = Color(0xFF7E8AA3);

  // ── Borders ──────────────────────────────────────────────────────────
  /// Neutral border — card edges, section dividers.
  static const Color borderSubtle = Color(0x1FFFFFFF);

  /// Stronger border for focused/active surfaces.
  static const Color borderStrong = Color(0x33FFFFFF);

  // ── Status ───────────────────────────────────────────────────────────
  /// Pulsing status dot — crash detection ON.
  static const Color statusActive = safeGreen;

  // ── Gradients ────────────────────────────────────────────────────────
  static const LinearGradient emergencyGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FF3B4C),
      Color(0x00FF3B4C),
    ],
  );

  static const LinearGradient surfaceSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x14FFFFFF),
      Color(0x00FFFFFF),
    ],
  );
}
