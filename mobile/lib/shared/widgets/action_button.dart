import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Reusable premium action button for the RoadSOS design system.
/// Uses accent blue for normal actions (not emergency).
class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const ActionButton(
    this.text, {
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? AppColors.surfaceAlt : AppColors.primary,
          disabledBackgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.labelCaps.copyWith(
            color: isDisabled ? AppColors.textMuted : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
