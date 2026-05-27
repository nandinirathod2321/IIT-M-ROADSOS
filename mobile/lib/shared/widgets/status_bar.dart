import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// A compact status bar displayed at the top of the home screen
/// showing the current protection state, connectivity, and location
/// accuracy.
///
/// The bar features a pulsing green dot when protection is active.
///
/// Usage:
/// ```dart
/// StatusBar(
///   isProtectionActive: true,
///   connectivityLabel: 'LTE',
///   locationAccuracy: '±5 m',
/// )
/// ```
class StatusBar extends StatefulWidget {
  /// Whether crash-detection protection is currently running.
  final bool isProtectionActive;

  /// Human-readable connectivity label (e.g. "LTE", "Wi-Fi", "Offline").
  final String connectivityLabel;

  /// Human-readable location accuracy string (e.g. "±5 m").
  final String locationAccuracy;

  const StatusBar({
    super.key,
    this.isProtectionActive = false,
    this.connectivityLabel = 'Offline',
    this.locationAccuracy = '--',
  });

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _dotOpacity;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _dotOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );

    if (widget.isProtectionActive) {
      _dotController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProtectionActive && !_dotController.isAnimating) {
      _dotController.repeat(reverse: true);
    } else if (!widget.isProtectionActive && _dotController.isAnimating) {
      _dotController.stop();
      _dotController.value = 0;
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border = isDark ? DarkColors.borderSubtle : LightColors.borderSubtle;
    final muted = isDark ? DarkColors.textMuted : LightColors.textMuted;
    final secondary = isDark ? DarkColors.textSecondary : LightColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          // Pulsing status dot
          AnimatedBuilder(
            animation: _dotOpacity,
            builder: (context, _) {
              final color = widget.isProtectionActive
                  ? AppColors.statusActive
                  : muted;
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(
                    alpha: widget.isProtectionActive
                        ? _dotOpacity.value
                        : 0.5,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Protection label
          Text(
            widget.isProtectionActive ? 'PROTECTION ON' : 'PROTECTION OFF',
            style: AppTypography.labelCaps.copyWith(
              color: widget.isProtectionActive
                  ? AppColors.statusActive
                : muted,
            ),
          ),

          const Spacer(),

          // Connectivity
          Icon(
            _connectivityIcon,
            size: 14,
            color: secondary,
          ),
          const SizedBox(width: 4),
          Text(
            widget.connectivityLabel,
            style: AppTypography.bodySmall,
          ),

          const SizedBox(width: 16),

          // Location accuracy
          Icon(
            Icons.my_location_rounded,
            size: 14,
            color: secondary,
          ),
          const SizedBox(width: 4),
          Text(
            widget.locationAccuracy,
            style: AppTypography.monoMedium.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData get _connectivityIcon {
    final label = widget.connectivityLabel.toLowerCase();
    if (label.contains('wi-fi') || label.contains('wifi')) {
      return Icons.wifi_rounded;
    }
    if (label.contains('offline') || label.contains('none')) {
      return Icons.wifi_off_rounded;
    }
    return Icons.signal_cellular_alt_rounded;
  }
}
