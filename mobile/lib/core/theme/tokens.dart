import 'package:flutter/material.dart';
import 'colors.dart';

/// Design tokens (spacing, radii, shadows) used across the premium UI.
abstract final class AppTokens {
  // Spacing scale (Step 6: 4px grid only)
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;

  // Radii (Step 4: Radius 14px everywhere)
  static const BorderRadius r14 = BorderRadius.all(Radius.circular(14));
  
  // Keep legacy for compilation safety, but we'll map them all to 14px where cards/decorations are used
  static const BorderRadius r8 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(14));

  // Standard Card Decoration (Step 4)
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  // Shadows
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  // Emergency glow (Step 5: NO gradient, circle SOS button with red glow shadow)
  static const List<BoxShadow> glowEmergency = [
    BoxShadow(
      color: Color(0x44DC2626),
      blurRadius: 24,
      spreadRadius: 4,
      offset: Offset(0, 8),
    ),
  ];

  // Border
  static const BorderSide border = BorderSide(color: AppColors.borderSubtle, width: 1);
}
