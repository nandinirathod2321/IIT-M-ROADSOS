import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/constants/app_constants.dart';

/// Full-screen overlay shown after a crash is detected, giving the user
/// [AppConstants.countdownSeconds] to cancel before the SOS is sent.
///
/// The overlay displays a large countdown timer with a circular progress
/// indicator and two action buttons: **Cancel** and **Send Now**.
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => CountdownOverlay(
///     onComplete: () => _dispatchSOS(),
///     onCancel: () => Navigator.of(context).pop(),
///   ),
/// );
/// ```
class CountdownOverlay extends StatefulWidget {
  /// Called when the countdown reaches zero without being cancelled.
  final VoidCallback onComplete;

  /// Called when the user taps "Cancel".
  final VoidCallback onCancel;

  /// Called when the user taps "Send Now" to skip the countdown.
  final VoidCallback? onSendNow;

  /// Total seconds to count down from. Defaults to
  /// [AppConstants.countdownSeconds].
  final int totalSeconds;

  /// The mechanism that triggered this emergency event (e.g. 'manual', 'voice', 'crash').
  final String triggerType;

  const CountdownOverlay({
    super.key,
    required this.onComplete,
    required this.onCancel,
    this.onSendNow,
    this.totalSeconds = AppConstants.countdownSeconds,
    this.triggerType = 'manual',
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  Timer? _timer;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;

    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        widget.onComplete();
      } else {
        setState(() => _remaining--);
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Text(
              widget.triggerType == 'voice'
                  ? 'VOICE TRIGGER DETECTED'
                  : widget.triggerType == 'manual'
                      ? 'MANUAL SOS TRIGGERED'
                      : 'CRASH DETECTED',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.emergencyRed,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sending SOS in',
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Countdown ring
            SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background ring
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 4,
                          color: AppColors.surfaceAlt,
                        ),
                      ),
                      // Countdown ring
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: 1.0 - _ringController.value,
                          strokeWidth: 4,
                          color: AppColors.emergencyRed,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      // Number
                      Text(
                        '$_remaining',
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 64,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'seconds',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),

            const SizedBox(height: 48),

            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _timer?.cancel();
                    _ringController.stop();
                    widget.onCancel();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.textSecondary, width: 1),
                  ),
                  child: const Text('I\'M OK — CANCEL'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Send Now button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    _ringController.stop();
                    (widget.onSendNow ?? widget.onComplete)();
                  },
                  child: const Text('SEND SOS NOW'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
