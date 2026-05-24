import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/hospital.dart';

/// Full-width card highlighting the nearest trauma centre with
/// capability pills and tap-to-call.
class NearestHospitalCard extends StatelessWidget {
  final Hospital? hospital;
  final bool isLoading;

  const NearestHospitalCard({
    super.key,
    this.hospital,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildShimmer();
    if (hospital == null) return const SizedBox.shrink();

    final h = hospital!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _makeCall(h.phone),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left red accent
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.emergencyRed,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEAREST TRAUMA CENTRE',
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.emergencyRed,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(h.name, style: AppTypography.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${h.distanceKm} km — ~${h.estimatedMinutes.toInt()} min',
                          style: AppTypography.monoMedium.copyWith(
                            color: AppColors.safeGreen,
                          ),
                        ),
                        if (h.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            h.phone,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Capability pills
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (h.hasICU) _pill('ICU'),
                      if (h.hasBloodBank) _pill('Blood Bank'),
                      if (h.hasEmergency) _pill('24H'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.infoBlue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceAlt,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
