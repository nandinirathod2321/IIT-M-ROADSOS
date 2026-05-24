import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// RoadSOS typographic scale.
///
/// • Headings / display   → **Barlow Condensed** (condensed, authoritative)
/// • Body / labels        → **Inter** (highly legible on small screens)
/// • Mono (coords, data)  → **Roboto Mono**
abstract final class AppTypography {
  // ── Display ──────────────────────────────────────────────────────────

  /// 48 sp · Bold · Barlow Condensed · –0.5 letter-spacing
  static TextStyle displayLarge = GoogleFonts.barlowCondensed(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// 36 sp · Bold · Barlow Condensed
  static TextStyle displayMedium = GoogleFonts.barlowCondensed(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Headlines ────────────────────────────────────────────────────────

  /// 28 sp · SemiBold · Barlow Condensed
  static TextStyle headlineLarge = GoogleFonts.barlowCondensed(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 20 sp · SemiBold · Inter
  static TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ── Labels ───────────────────────────────────────────────────────────

  /// 11 sp · Bold · Inter · +2.0 letter-spacing · ALL CAPS
  ///
  /// Use [Text.toUpperCase()] when applying this style — the style itself
  /// does not transform casing.
  static TextStyle labelCaps = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    color: AppColors.textSecondary,
  );

  // ── Body ─────────────────────────────────────────────────────────────

  /// 16 sp · Regular · Inter
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// 14 sp · Regular · Inter
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// 12 sp · Regular · Inter
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Monospace ────────────────────────────────────────────────────────

  /// 14 sp · Medium · Roboto Mono — coordinates, distances, IDs.
  static TextStyle monoMedium = GoogleFonts.robotoMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
