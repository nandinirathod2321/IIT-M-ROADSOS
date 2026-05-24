import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Placeholder screen — will be built in a later prompt.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTypography.headlineLarge)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Settings', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Coming in a later prompt', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
