import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_card.dart';

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
      padding: const EdgeInsets.fromLTRB(AppTokens.s4, AppTokens.s4, AppTokens.s4, 0),
      child: AppCard(
        glass: true,
        padding: const EdgeInsets.all(AppTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.infoBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'LIVE LOCATION',
                  style: AppTypography.labelCaps.copyWith(color: AppColors.textMuted),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: AppTokens.r12,
                    border: Border.all(color: AppColors.borderSubtle),
                    color: AppColors.surfaceAlt,
                  ),
                  child: Text(
                    isLoading ? 'LOCKING…' : 'LOCKED',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 9,
                      color: isLoading ? AppColors.emergencyAmber : AppColors.safeGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s3),
            if (isLoading)
              Shimmer.fromColors(
                baseColor: AppColors.surfaceAlt,
                highlightColor: AppColors.surface,
                child: Container(
                  height: 28,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppTokens.r12,
                  ),
                ),
              )
            else
              Text(
                address,
                style: AppTypography.headlineLarge.copyWith(fontSize: 22),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppTokens.s2),
            if (isLoading)
              Shimmer.fromColors(
                baseColor: AppColors.surfaceAlt,
                highlightColor: AppColors.surface,
                child: Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppTokens.r12,
                  ),
                ),
              )
            else
              Text(
                coordinates,
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
