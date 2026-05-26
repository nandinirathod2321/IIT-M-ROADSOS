import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';
import 'tokens.dart';

/// Builds the premium dark [ThemeData] for RoadSOS.
abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Colour scheme ────────────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emergencyRed,
        secondary: AppColors.infoBlue,
        surface: AppColors.surface,
        error: AppColors.emergencyRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: AppColors.bgPrimary,

      // ── AppBar ───────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),

      // ── Cards ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r16,
          side: AppTokens.border,
        ),
      ),

      // ── Bottom Navigation ────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.emergencyRed,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        indicatorColor: const Color(0x1AFF3B4C),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.bodySmall
                .copyWith(color: AppColors.emergencyRed);
          }
          return AppTypography.bodySmall
              .copyWith(color: AppColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.emergencyRed, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
      ),

      // ── Elevated Button ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emergencyRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button ──────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: AppTokens.border,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ──────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emergencyRed,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurfaceAlt,
        border: const OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.border,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.border,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: BorderSide(color: AppColors.emergencyRed, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: BorderSide(color: AppColors.emergencyRed, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: BorderSide(color: AppColors.emergencyRed, width: 2),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Divider ──────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      // ── Text theme (fallback) ─────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelSmall: AppTypography.labelCaps,
      ),

      // ── Dialog ───────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r20,
          side: AppTokens.border,
        ),
      ),
    );
  }

  /// Kept for compatibility. Returns the same light theme.
  static ThemeData get dark => light;
}
