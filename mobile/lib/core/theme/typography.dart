import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// RoadSOS premium typographic scale.
///
/// - Headings: Space Grotesk (modern, premium, high clarity)
/// - Body: Inter (high readability, neutral, system-like)
/// - Mono: Roboto Mono (coords, IDs)
abstract final class AppTypography {
  // ── Display ──────────────────────────────────────────────────────────

  static TextStyle displayLarge = GoogleFonts.spaceGrotesk(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.05,
  );

  static TextStyle displayMedium = GoogleFonts.spaceGrotesk(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.10,
  );

  // ── Headlines ────────────────────────────────────────────────────────

  static TextStyle headlineLarge = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.15,
  );

  static TextStyle headlineMedium = GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // ── Labels ───────────────────────────────────────────────────────────

  static TextStyle labelCaps = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    height: 1.1,
  );

  // ── Body ─────────────────────────────────────────────────────────────

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  // ── Monospace ────────────────────────────────────────────────────────

  static TextStyle monoMedium = GoogleFonts.robotoMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
