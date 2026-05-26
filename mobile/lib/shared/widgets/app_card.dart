import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/tokens.dart';

/// Premium surface card with optional glass blur.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final bool glass;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s4),
    this.margin,
    this.borderRadius = AppTokens.r16,
    this.glass = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.borderSubtle),
        gradient: AppColors.surfaceSheen,
        color: glass ? AppColors.surfaceOverlay : AppColors.surface,
        boxShadow: AppTokens.shadowSm,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: glass
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: card,
            )
          : card,
    );

    if (onTap == null) return clipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: 1.0,
        child: clipped,
      ),
    );
  }
}

