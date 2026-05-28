import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// The central SOS button with a 2-second long-press trigger,
/// pulsing outer ring, and haptic feedback.
class HomeSosButton extends StatefulWidget {
  final bool crashDetectorActive;
  final VoidCallback onTriggered;

  const HomeSosButton({
    super.key,
    this.crashDetectorActive = false,
    required this.onTriggered,
  });

  @override
  State<HomeSosButton> createState() => _HomeSosButtonState();
}

class _HomeSosButtonState extends State<HomeSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _holdTimer;
  bool _isHolding = false;
  double _holdProgress = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (!widget.crashDetectorActive) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HomeSosButton old) {
    super.didUpdateWidget(old);
    if (widget.crashDetectorActive && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    } else if (!widget.crashDetectorActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    setState(() {
      _isHolding = true;
      _holdProgress = 0;
    });
    // Update progress every 50ms for smooth animation
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _holdProgress += 50 / 2000; // 2 seconds total
      });
      if (_holdProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        setState(() {
          _isHolding = false;
          _holdProgress = 0;
        });
      }
    });
  }

  void _onPointerUp(PointerUpEvent _) {
    _cancelHold();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _cancelHold();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              final scale = _pulseCtrl.isAnimating ? _pulseAnim.value : 1.0;
              return SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hold progress ring
                    if (_isHolding)
                      const SizedBox(
                        width: 176,
                        height: 176,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 3,
                          color: Color(0xFFDC2626),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    if (_isHolding)
                      SizedBox(
                        width: 176,
                        height: 176,
                        child: CircularProgressIndicator(
                          value: _holdProgress,
                          strokeWidth: 3,
                          color: Color(0xFF1A56DB),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    // Core button (Step 5: circle, 160px, solid Color(0xFFDC2626), white icon + 'SOS' label w700 letterSpacing:2, red glow shadow)
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFDC2626),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x66DC2626),
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
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'HOLD 2 SECONDS',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
