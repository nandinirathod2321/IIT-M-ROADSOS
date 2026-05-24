import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Placeholder screen — will be built in a later prompt.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('First Aid', style: AppTypography.headlineLarge)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.health_and_safety_rounded, size: 48, color: AppColors.safeGreen),
            const SizedBox(height: 16),
            Text('First Aid Guide', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Coming in a later prompt', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
