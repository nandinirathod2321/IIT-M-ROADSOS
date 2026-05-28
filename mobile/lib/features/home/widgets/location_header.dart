import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
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
                  child: Text(
                    isLoading ? 'LOCKING…' : 'LOCKED',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 13, // Minimum 13px
                      color: isLoading ? AppColors.warningAmber : AppColors.safeGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
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
                address,
                style: AppTypography.headlineLarge.copyWith(fontSize: 22, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            if (isLoading)
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
                coordinates,
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
