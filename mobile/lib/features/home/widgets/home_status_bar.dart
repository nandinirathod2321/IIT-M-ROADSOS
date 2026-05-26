import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/tokens.dart';
import '../bloc/home_event.dart';
import '../../../shared/widgets/app_card.dart';

/// Custom 48px status bar with pulsing green dot, GPS coordinates, and
/// connectivity indicator.
class HomeStatusBar extends StatefulWidget {
  final bool isProtected;
  final String coordinates;
  final ConnectivityType connectivity;

  const HomeStatusBar({
    super.key,
    required this.isProtected,
    required this.coordinates,
    required this.connectivity,
  });

  @override
  State<HomeStatusBar> createState() => _HomeStatusBarState();
}

class _HomeStatusBarState extends State<HomeStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotCtrl;
  late Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _dotScale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
    if (widget.isProtected) _dotCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HomeStatusBar old) {
    super.didUpdateWidget(old);
    if (widget.isProtected && !_dotCtrl.isAnimating) {
      _dotCtrl.repeat(reverse: true);
    } else if (!widget.isProtected) {
      _dotCtrl.stop();
    }
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.s4, AppTokens.s3, AppTokens.s4, 0),
      child: AppCard(
        glass: true,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4, vertical: AppTokens.s3),
        child: Row(
          children: [
            // Pulsing dot + status
            AnimatedBuilder(
              animation: _dotScale,
              builder: (context, _) {
                return Transform.scale(
                  scale: widget.isProtected ? _dotScale.value : 1.0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isProtected ? AppColors.statusActive : AppColors.textMuted,
                      boxShadow: widget.isProtected ? AppTokens.shadowSm : const [],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              widget.isProtected ? 'PROTECTED' : 'UNPROTECTED',
              style: AppTypography.labelCaps.copyWith(
                fontSize: 10,
                color: widget.isProtected ? AppColors.statusActive : AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: AppTokens.r12,
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                widget.coordinates,
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(_connectivityIcon, size: 16, color: _connectivityColor),
          ],
        ),
      ),
    );
  }

  IconData get _connectivityIcon {
    switch (widget.connectivity) {
      case ConnectivityType.wifi:
        return Icons.wifi_rounded;
      case ConnectivityType.mobile:
        return Icons.signal_cellular_alt_rounded;
      case ConnectivityType.offline:
        return Icons.wifi_off_rounded;
    }
  }

  Color get _connectivityColor {
    switch (widget.connectivity) {
      case ConnectivityType.wifi:
        return AppColors.safeGreen;
      case ConnectivityType.mobile:
        return AppColors.safeGreen;
      case ConnectivityType.offline:
        return AppColors.emergencyAmber;
    }
  }
}
