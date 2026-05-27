import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Reusable premium action button for the RoadSOS design system.
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
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? cs.surface : cs.primary,
          disabledBackgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.labelCaps.copyWith(
            color: isDisabled ? (Theme.of(context).brightness == Brightness.dark ? DarkColors.textMuted : LightColors.textMuted) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
