import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Placeholder screen — will be built in a later prompt.
class EmergencyScreen extends StatelessWidget {
  final int initialSection;
  const EmergencyScreen({super.key, this.initialSection = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emergency Services', style: AppTypography.headlineLarge)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emergency_rounded, size: 48, color: AppColors.emergencyRed),
            const SizedBox(height: 16),
            Text('Emergency Services', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Section $initialSection', style: AppTypography.monoMedium.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('Coming in Prompt 3', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
