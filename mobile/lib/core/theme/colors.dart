import 'package:flutter/material.dart';

/// RoadSOS design-system color palette — Light / Government style.
///
/// Inspired by government.nl (Netherlands) and the US Web Design System (USWDS).
/// Emergency Red (#CC0000) is the ONLY accent color.
/// Everything else is black, white, and neutral grey — zero decoration.
///
/// Design rules:
///   • Pure white (#FFFFFF) or near-black (#111111) — no grey soup.
///   • Emergency Red is used ONLY for actionable, critical elements.
///   • Navy blue (#112E51) is reserved for authority / trust sections.
///   • NO gradients, NO shadows, NO decorative backgrounds.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────
  /// Pure white — main scaffold / background.
  static const Color primary = Color(0xFFFFFFFF);

  /// Light grey — card / surface background.
  static const Color surface = Color(0xFFF5F5F5);

  /// Alternate surface — input fill, secondary cards.
  static const Color surfaceAlt = Color(0xFFEBEBEB);

  // Aliases for USWDS / gov.nl naming convention
  static const Color bgPrimary = primary;
  static const Color bgSurface = surface;
  static const Color bgSurfaceAlt = surfaceAlt;

  // ── Semantic / Emergency ─────────────────────────────────────────────
  /// SOS button, danger states, critical alerts — the ONLY accent color.
  static const Color emergencyRed = Color(0xFFCC0000);

  /// Warnings, secondary alerts, countdown state.
  static const Color emergencyAmber = Color(0xFFB45309);

  /// Confirmed safe / connected / resolved state.
  static const Color safeGreen = Color(0xFF2E7D32);

  // ── Authority / Trust (USWDS) ─────────────────────────────────────────
  /// Navy blue — authority headers, trust sections (USWDS #112E51).
  static const Color trustNavy = Color(0xFF112E51);

  // ── Service type accents ─────────────────────────────────────────────
  /// Hospitals, informational highlights.
  static const Color infoBlue = Color(0xFF0D47A1);

  /// Police stations.
  static const Color policeBlue = Color(0xFF1565C0);

  /// Towing services.
  static const Color towingOrange = Color(0xFFC2410C);

  // ── Text ─────────────────────────────────────────────────────────────
  /// Near-black — main body / headline text (#111111).
  static const Color textPrimary = Color(0xFF111111);

  /// Dark grey — subtitles, labels, secondary copy.
  static const Color textSecondary = Color(0xFF444444);

  /// Mid grey — disabled text, hints, placeholders (WCAG AA accessible).
  static const Color textMuted = Color(0xFF767676);

  // ── Borders ──────────────────────────────────────────────────────────
  /// Neutral border — card edges, section dividers.
  static const Color borderSubtle = Color(0xFFCCCCCC);

  // ── Status ───────────────────────────────────────────────────────────
  /// Pulsing status dot — crash detection ON.
  static const Color statusActive = Color(0xFF2E7D32);
}
