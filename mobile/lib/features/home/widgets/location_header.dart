import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Location header showing address label, reverse-geocoded address,
/// and coordinates.
class LocationHeader extends StatelessWidget {
  final bool isLoading;
  final String address;
  final String coordinates;

  const LocationHeader({
    super.key,
    required this.isLoading,
    required this.address,
    required this.coordinates,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR LOCATION',
            style: AppTypography.labelCaps.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceAlt,
              child: Container(
                height: 36,
                width: 250,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            Text(address, style: AppTypography.displayMedium),
          const SizedBox(height: 4),
          if (isLoading)
            Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceAlt,
              child: Container(
                height: 16,
                width: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            Text(
              coordinates,
              style: AppTypography.monoMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
