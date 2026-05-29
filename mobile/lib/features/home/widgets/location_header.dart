import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../bloc/home_state.dart';

/// Location header showing address label, reverse-geocoded address,
/// and coordinates.
class LocationHeader extends StatelessWidget {
  final HomeLocationStatus locationStatus;
  final String address;
  final String coordinates;

  const LocationHeader({
    super.key,
    required this.locationStatus,
    required this.address,
    required this.coordinates,
  });

  Color _getStatusColor(HomeLocationStatus status) {
    switch (status) {
      case HomeLocationStatus.loading:
        return AppColors.warningAmber;
      case HomeLocationStatus.success:
        return AppColors.safeGreen;
      case HomeLocationStatus.timeout:
        return AppColors.warningAmber;
      case HomeLocationStatus.permissionDenied:
        return AppColors.emergencyRed;
      case HomeLocationStatus.gpsDisabled:
        return AppColors.emergencyRed;
    }
  }

  String _getStatusBadgeText(HomeLocationStatus status) {
    switch (status) {
      case HomeLocationStatus.loading:
        return 'FETCHING…';
      case HomeLocationStatus.success:
        return 'LOCKED';
      case HomeLocationStatus.timeout:
        return 'TIMEOUT';
      case HomeLocationStatus.permissionDenied:
        return 'BLOCKED';
      case HomeLocationStatus.gpsDisabled:
        return 'DISABLED';
    }
  }

  String _getAddressText() {
    switch (locationStatus) {
      case HomeLocationStatus.loading:
        return 'Fetching location...';
      case HomeLocationStatus.success:
        return address;
      case HomeLocationStatus.timeout:
        return 'Using Last Known Location';
      case HomeLocationStatus.permissionDenied:
        return 'Location permission unavailable';
      case HomeLocationStatus.gpsDisabled:
        return 'Location services disabled';
    }
  }

  String _getCoordinatesText() {
    if (locationStatus == HomeLocationStatus.loading && (coordinates == '-- --' || coordinates.isEmpty)) {
      return 'Resolving GPS lock...';
    }
    return coordinates;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(locationStatus);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'LIVE LOCATION',
                  style: AppTypography.labelCaps.copyWith(color: AppColors.textTertiary, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: const Color(0xFFF0F2F5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locationStatus == HomeLocationStatus.loading) ...[
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.warningAmber),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _getStatusBadgeText(locationStatus),
                        style: AppTypography.labelCaps.copyWith(
                          fontSize: 13, // Minimum 13px
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (locationStatus == HomeLocationStatus.loading && address == 'Locating...')
              Shimmer.fromColors(
                baseColor: const Color(0xFFF0F2F5),
                highlightColor: Colors.white,
                child: Container(
                  height: 28,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Text(
                _getAddressText(),
                style: AppTypography.headlineLarge.copyWith(fontSize: 22, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            if (locationStatus == HomeLocationStatus.loading && coordinates == '-- --')
              Shimmer.fromColors(
                baseColor: const Color(0xFFF0F2F5),
                highlightColor: Colors.white,
                child: Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Text(
                _getCoordinatesText(),
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 13, // Minimum 13px
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
