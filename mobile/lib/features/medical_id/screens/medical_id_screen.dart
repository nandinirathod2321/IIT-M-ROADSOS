import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Placeholder screen — will be built in a later prompt.
class MedicalIdScreen extends StatelessWidget {
  const MedicalIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Medical ID', style: AppTypography.headlineLarge)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_information_rounded, size: 48, color: AppColors.infoBlue),
            const SizedBox(height: 16),
            Text('Medical ID', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Coming in a later prompt', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
