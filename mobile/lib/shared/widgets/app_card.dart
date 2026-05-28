import 'package:flutter/material.dart';

/// Premium surface card with standard light-theme styling.
/// Aligned with Step 4 guidelines: white fill, border, shadow, and 14px radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white, // Always white
        borderRadius: BorderRadius.circular(14), // Consistent 14px
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0), // Consistent border
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}
