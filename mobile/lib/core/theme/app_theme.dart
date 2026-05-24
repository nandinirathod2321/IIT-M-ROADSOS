import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Builds the single, dark-only [ThemeData] for RoadSOS.
///
/// Design rules:
///   • No elevation shadows — cards use 1 px [AppColors.borderSubtle] borders.
///   • Buttons use 4 px radius (sharp, authoritative).
///   • ElevatedButton minimum height is 56 px (thumb-friendly).
///   • AppBar is transparent with no elevation.
///   • Bottom nav uses [AppColors.surface] with [AppColors.emergencyRed] indicator.
abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Colour scheme seed ──────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emergencyRed,
        secondary: AppColors.emergencyAmber,
        surface: AppColors.surface,
        error: AppColors.emergencyRed,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),

      scaffoldBackgroundColor: AppColors.primary,

      // ── AppBar ──────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Cards ───────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),

      // ── Bottom Navigation ───────────────────────────────────────────
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
        indicatorColor: AppColors.emergencyRed.withValues(alpha: 0.15),
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

      // ── Elevated Button ─────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emergencyRed,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emergencyRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.emergencyRed),
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

      // ── Divider ─────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      // ── Text theme (fallback) ───────────────────────────────────────
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
    );
  }
}
