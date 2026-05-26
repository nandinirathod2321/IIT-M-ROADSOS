import 'package:flutter/material.dart';
import 'colors.dart';

/// Design tokens (spacing, radii, shadows) used across the premium UI.
abstract final class AppTokens {
  // Spacing scale
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;

  // Radii
  static const BorderRadius r8 = BorderRadius.all(Radius.circular(8));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(20));

  // Shadows (subtle, premium)
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> glowEmergency = [
    BoxShadow(
      color: Color(0x44FF3B4C),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const BorderSide border = BorderSide(color: AppColors.borderSubtle, width: 1);
}

