import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Thin 2px pulsing red bar at the very top of the screen indicating
/// that crash detection is actively monitoring sensors.
class CrashDetectionBar extends StatefulWidget {
  final bool isActive;

  const CrashDetectionBar({super.key, required this.isActive});

  @override
  State<CrashDetectionBar> createState() => _CrashDetectionBarState();
}

class _CrashDetectionBarState extends State<CrashDetectionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CrashDetectionBar old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Container(
          height: 2,
          width: double.infinity,
          color: AppColors.emergencyRed.withValues(alpha: _opacity.value),
        );
      },
    );
  }
}
