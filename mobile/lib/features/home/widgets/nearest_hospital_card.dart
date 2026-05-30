import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/hospital.dart';
import '../../../shared/widgets/app_card.dart';

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
      child: AppCard(
        onTap: () => _makeCall(h.phone),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.surfaceSecondary,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.emergency_rounded, color: AppColors.emergency),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEAREST HOSPITAL',
                    style: AppTypography.labelCaps.copyWith(color: AppColors.emergency),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    h.name,
                    style: AppTypography.headlineLarge.copyWith(fontSize: 20, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _metricChip('${h.distanceKm.toStringAsFixed(1)} km'),
                      const SizedBox(width: 8),
                      _metricChip('~${h.estimatedMinutes.toInt()} min'),
                      const Spacer(),
                      if (h.phone.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.emergency,
                          ),
                          child: Text(
                            'CALL',
                            style: AppTypography.labelCaps.copyWith(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (h.hasEmergency) _pill('24H'),
                      if (h.hasICU) _pill('ICU'),
                      if (h.hasBloodBank) _pill('Blood'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceSecondary,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTypography.monoMedium.copyWith(
          fontSize: 13,
          color: AppColors.safeGreen,
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFF0F2F5),
        highlightColor: Colors.white,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(14),
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
