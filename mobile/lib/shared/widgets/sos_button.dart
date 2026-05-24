import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// The primary SOS activation button — a large, pulsing red circle
/// placed at the centre of the home screen.
///
/// Supports two states:
///   • **idle** — steady glow, awaiting tap/long-press.
///   • **active** — rapid pulse, indicating an SOS is in progress.
///
/// Usage:
/// ```dart
/// SOSButton(
///   isActive: false,
///   onPressed: () => _triggerSOS(),
/// )
/// ```
class SOSButton extends StatefulWidget {
  /// Whether the SOS is currently active (rapid-pulse mode).
  final bool isActive;

  /// Callback when the button is tapped.
  final VoidCallback? onPressed;

  /// Callback when the button is long-pressed (force-trigger SOS).
  final VoidCallback? onLongPress;

  /// Diameter of the outer ring. Defaults to 200.
  final double size;

  const SOSButton({
    super.key,
    this.isActive = false,
    this.onPressed,
    this.onLongPress,
    this.size = 200,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isActive ? 600 : 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant SOSButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _pulseController.duration =
          Duration(milliseconds: widget.isActive ? 600 : 1500);
      _pulseController
        ..stop()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _pulseAnimation.value;
        return GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emergencyRed
                            .withValues(alpha: 0.3 * scale),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Middle glow ring
                Transform.scale(
                  scale: scale * 0.92,
                  child: Container(
                    width: widget.size * 0.85,
                    height: widget.size * 0.85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emergencyRed
                            .withValues(alpha: 0.15 * scale),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // Core button
                Container(
                  width: widget.size * 0.65,
                  height: widget.size * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emergencyRed,
                    border: Border.all(
                      color: AppColors.emergencyRed.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'SOS',
                      style: AppTypography.displayLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: widget.size * 0.16,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
