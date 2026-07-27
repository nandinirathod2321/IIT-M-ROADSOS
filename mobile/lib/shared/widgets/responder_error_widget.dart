import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

enum ResponderErrorType { noInternet, gpsDenied, apiUnavailable, empty }

/// Professional error state widget used by EmergencyScreen and HomeScreen
/// to present contextual, actionable error messaging.
class ResponderErrorWidget extends StatelessWidget {
  final ResponderErrorType type;
  final String? customMessage;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ResponderErrorWidget({
    super.key,
    required this.type,
    this.customMessage,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final config = _configFor(type);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.color, size: 36),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            // Message
            Text(
              customMessage ?? config.message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 16),
                label: Text(
                  retryLabel ?? 'RETRY',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ErrorConfig _configFor(ResponderErrorType t) {
    switch (t) {
      case ResponderErrorType.noInternet:
        return _ErrorConfig(
          icon: Icons.wifi_off_rounded,
          color: AppColors.infoBlue,
          title: 'NO INTERNET CONNECTION',
          message:
              'RoadSOS is offline. Showing cached emergency services. Connect to the internet for live results.',
        );
      case ResponderErrorType.gpsDenied:
        return _ErrorConfig(
          icon: Icons.location_off_rounded,
          color: AppColors.emergencyRed,
          title: 'GPS LOCATION REQUIRED',
          message:
              'Emergency services cannot be located without GPS coordinates. Please grant location permission.',
        );
      case ResponderErrorType.apiUnavailable:
        return _ErrorConfig(
          icon: Icons.cloud_off_rounded,
          color: AppColors.emergencyAmber,
          title: 'SERVICE TEMPORARILY UNAVAILABLE',
          message:
              'Could not reach the emergency services database. This may be a temporary outage. Try again shortly.',
        );
      case ResponderErrorType.empty:
        return _ErrorConfig(
          icon: Icons.search_off_rounded,
          color: AppColors.textMuted,
          title: 'NO SERVICES FOUND NEARBY',
          message:
              'No emergency services were found within the search radius. This may be a data coverage gap in your area.',
        );
    }
  }
}

class _ErrorConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _ErrorConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });
}
