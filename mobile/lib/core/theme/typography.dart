import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// RoadSOS premium typographic scale using Google Fonts:
/// - Primary: DM Sans
/// - Numbers / Data: DM Mono
abstract final class AppTypography {
  // ── Display ────────────────────────────────────────────────────

  static TextStyle get displayLarge => GoogleFonts.dmSans(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.05,
    color: AppColors.textPrimary,
  );

  static TextStyle get displayMedium => GoogleFonts.dmSans(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.10,
    color: AppColors.textPrimary,
  );

  // ── Headlines ────────────────────────────────────────────────────

  static TextStyle get headline => GoogleFonts.dmSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineLarge => headline;

  static TextStyle get headlineMedium => GoogleFonts.dmSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  // ── Labels / Buttons ─────────────────────────────────────────────

  static TextStyle get labelCaps => GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AppColors.textSecondary,
  );

  // ── Body ─────────────────────────────────────────────────────────

  static TextStyle get bodyLarge => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.dmSans(
    fontSize: 14, // Minimum 14px for body text
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  // ── Monospace ────────────────────────────────────────────────────

  static TextStyle get monoMedium => GoogleFonts.dmMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
