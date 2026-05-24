import 'package:flutter/material.dart';

/// RoadSOS design-system color palette.
///
/// Dark-first palette optimised for outdoor / night-time readability.
/// All values are exact hex matches to the design spec.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────
  /// Near-black navy — main scaffold / background.
  static const Color primary = Color(0xFF0A0F1E);

  /// Card / sheet background.
  static const Color surface = Color(0xFF111827);

  /// Alternate card / input fill background.
  static const Color surfaceAlt = Color(0xFF1F2937);

  // ── Semantic / Emergency ─────────────────────────────────────────────
  /// SOS button, danger states, critical alerts.
  static const Color emergencyRed = Color(0xFFDC2626);

  /// Warnings, secondary alerts, countdowns.
  static const Color emergencyAmber = Color(0xFFD97706);

  /// Confirmed safe / connected state.
  static const Color safeGreen = Color(0xFF059669);

  // ── Service type accents ─────────────────────────────────────────────
  /// Hospitals, informational highlights.
  static const Color infoBlue = Color(0xFF1D4ED8);

  /// Police stations.
  static const Color policeBlue = Color(0xFF1E40AF);

  /// Towing services.
  static const Color towingOrange = Color(0xFFC2410C);

  // ── Text ─────────────────────────────────────────────────────────────
  /// Main body / headline text.
  static const Color textPrimary = Color(0xFFF9FAFB);

  /// Subtitles, labels, secondary copy.
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Disabled text, hints, placeholders.
  static const Color textMuted = Color(0xFF4B5563);

  // ── Borders ──────────────────────────────────────────────────────────
  /// Subtle card / divider border.
  static const Color borderSubtle = Color(0xFF1F2937);

  // ── Status ───────────────────────────────────────────────────────────
  /// Pulsing status dot — protection ON.
  static const Color statusActive = Color(0xFF10B981);
}
