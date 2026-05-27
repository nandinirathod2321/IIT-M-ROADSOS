import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';
import 'tokens.dart';

/// Builds the two completely distinct premium themes for RoadSOS.
abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.emergencyRed,
        secondary: AppColors.infoBlue,
        surface: LightColors.surface,
        error: AppColors.emergencyRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: LightColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: LightColors.bgPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: LightColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge.copyWith(color: LightColors.textPrimary),
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: LightColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r16,
          side: AppTokens.lightBorder,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: LightColors.surface,
        selectedItemColor: AppColors.emergencyRed,
        unselectedItemColor: LightColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LightColors.surface,
        elevation: 0,
        indicatorColor: const Color(0x1AE8334A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.bodySmall.copyWith(color: AppColors.emergencyRed);
          }
          return AppTypography.bodySmall.copyWith(color: LightColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.emergencyRed, size: 24);
          }
          return const IconThemeData(color: LightColors.textMuted, size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emergencyRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LightColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: AppTokens.lightBorder,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emergencyRed,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LightColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.lightBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.lightBorder,
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
        labelStyle: AppTypography.bodyMedium.copyWith(color: LightColors.textMuted),
        hintStyle: AppTypography.bodyMedium.copyWith(color: LightColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: LightColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: LightColors.textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: LightColors.textPrimary),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: LightColors.textPrimary),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: LightColors.textPrimary),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: LightColors.textPrimary),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: LightColors.textPrimary),
        bodySmall: AppTypography.bodySmall.copyWith(color: LightColors.textSecondary),
        labelSmall: AppTypography.labelCaps.copyWith(color: LightColors.textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LightColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r20,
          side: AppTokens.lightBorder,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emergencyRed,
        secondary: AppColors.infoBlue,
        surface: DarkColors.surface,
        error: AppColors.emergencyRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DarkColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: DarkColors.bgPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: DarkColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge.copyWith(color: DarkColors.textPrimary),
        iconTheme: const IconThemeData(color: DarkColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: DarkColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r16,
          side: AppTokens.darkBorder,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: DarkColors.surface,
        selectedItemColor: AppColors.emergencyRed,
        unselectedItemColor: DarkColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DarkColors.surface,
        elevation: 0,
        indicatorColor: const Color(0x1AE8334A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.bodySmall.copyWith(color: AppColors.emergencyRed);
          }
          return AppTypography.bodySmall.copyWith(color: DarkColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.emergencyRed, size: 24);
          }
          return const IconThemeData(color: DarkColors.textMuted, size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emergencyRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarkColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: AppTokens.darkBorder,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emergencyRed,
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.r16),
          textStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.darkBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.r16,
          borderSide: AppTokens.darkBorder,
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
        labelStyle: AppTypography.bodyMedium.copyWith(color: DarkColors.textMuted),
        hintStyle: AppTypography.bodyMedium.copyWith(color: DarkColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: DarkColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: DarkColors.textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: DarkColors.textPrimary),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: DarkColors.textPrimary),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: DarkColors.textPrimary),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: DarkColors.textPrimary),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: DarkColors.textPrimary),
        bodySmall: AppTypography.bodySmall.copyWith(color: DarkColors.textSecondary),
        labelSmall: AppTypography.labelCaps.copyWith(color: DarkColors.textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.bgPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r20,
          side: AppTokens.darkBorder,
        ),
      ),
    );
  }
}
