import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Builds the premium [ThemeData] for RoadSOS.
/// Single professional light theme with Apple-level polish.
abstract final class AppTheme {
  /// Premium light theme - the only theme for the app.
  /// Clean white backgrounds, strong contrast, professional design.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ── Colour scheme ────────────────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.infoBlue,
        surface: AppColors.surfacePrimary,
        error: AppColors.emergency,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: AppColors.scaffoldBg,

      // ── AppBar (Step 7: white bg, 0 elevation, 1px E2E8F0 bottom border, left-aligned title, textPrimary color) ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        titleTextStyle: AppTypography.headline.copyWith(color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),

      // ── Cards (Step 4: white + border + shadow + 14px radius) ────────
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0, // Shadows handled explicitly by decoration/shadow or custom card
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),

      // ── Bottom Navigation (Step 7: white bg, 1px E2E8F0 top border, elevation 8, selected indicator E8EFFE, selected 1A56DB) ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1A56DB),
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFFE8EFFE),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelCaps.copyWith(
              color: const Color(0xFF1A56DB),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelCaps.copyWith(
            color: AppColors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF1A56DB), size: 24);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 24);
        }),
      ),

      // ── Elevated Button (Step 5: 52px height, 12px radius, 1A56DB fill, white w600 label) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A56DB),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTypography.labelCaps.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),

      // ── Outlined Button (Step 5: same size, white fill, 1.5px blue border) ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A56DB),
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTypography.labelCaps.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: const Color(0xFF1A56DB),
          ),
        ),
      ),

      // ── Text Button ──────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1A56DB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTypography.labelCaps.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),

      // ── Input Decoration (Step 8: F0F2F5 fill, 1px CBD5E1 border, 2px blue border focus) ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emergency, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emergency, width: 2.0),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
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
        headlineLarge: AppTypography.headline,
        headlineMedium: AppTypography.headlineMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelSmall: AppTypography.labelCaps,
      ),

      // ── Dialog ───────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
    );
  }

  // Keep theme alias for compilation safety
  static ThemeData get theme => lightTheme;
}
