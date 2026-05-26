import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// RoadSOS typographic scale — Government / USWDS style.
///
/// • Display / headings  → Barlow Condensed (authoritative, condensed)
/// • Body / labels       → Noto Sans (humanist, gov.nl — readable under stress)
/// • Mono (data / coords) → Roboto Mono
///
/// Design rules:
///   • Minimum 16 sp body text (112.nl emergency app standard).
///   • Generous line height (1.8) — readable in panic.
///   • ALL-CAPS section headers use [labelCaps].
///   • Zero decorative text effects — weight and size carry hierarchy.
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

  /// 20 sp · SemiBold · Noto Sans
  static TextStyle headlineMedium = GoogleFonts.notoSans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ── Labels ───────────────────────────────────────────────────────────

  /// 11 sp · Bold · Noto Sans · +2.0 letter-spacing · ALL CAPS
  ///
  /// Use [Text.toUpperCase()] when applying this style — the style itself
  /// does not transform casing.
  static TextStyle labelCaps = GoogleFonts.notoSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    color: AppColors.textSecondary,
  );

  // ── Body ─────────────────────────────────────────────────────────────

  /// 16 sp · Regular · Noto Sans · 1.8 line-height
  static TextStyle bodyLarge = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.8,
    color: AppColors.textPrimary,
  );

  /// 14 sp · Regular · Noto Sans · 1.8 line-height
  static TextStyle bodyMedium = GoogleFonts.notoSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.8,
    color: AppColors.textPrimary,
  );

  /// 12 sp · Regular · Noto Sans · 1.6 line-height
  static TextStyle bodySmall = GoogleFonts.notoSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  // ── Monospace ────────────────────────────────────────────────────────

  /// 14 sp · Medium · Roboto Mono — coordinates, distances, event IDs.
  static TextStyle monoMedium = GoogleFonts.robotoMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
