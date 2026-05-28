import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';

/// The primary SOS activation button — a large, pulsing red circle
/// placed at the centre of the home screen.
class SOSButton extends StatefulWidget {
  /// Whether the SOS is currently active.
  final bool isActive;

  /// Callback when the button is tapped.
  final VoidCallback? onPressed;

  /// Callback when the button is long-pressed.
  final VoidCallback? onLongPress;

  const SOSButton({
    super.key,
    this.isActive = false,
    this.onPressed,
    this.onLongPress,
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

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
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
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDC2626), // Solid emergency red
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66DC2626), // Red glow shadow
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SOS',
                    style: AppTypography.displayLarge.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
