import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// A card representing a nearby emergency service (hospital, police,
/// or towing). Follows the RoadSOS design spec:
///   • White fill, border, shadow, and 14px radius.
class ServiceCard extends StatelessWidget {
  /// Leading icon (e.g. hospital, police, tow-truck).
  final IconData icon;

  /// Accent colour for the icon circle and left strip.
  final Color accentColor;

  /// Service name / title.
  final String title;

  /// Secondary line — type, capabilities, hours, etc.
  final String subtitle;

  /// Human-readable distance (e.g. "3.2 km").
  final String distanceLabel;

  /// Estimated travel time (e.g. "~5 min").
  final String etaLabel;

  /// Tap handler — usually opens detail view or initiates a call.
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g. call button).
  final Widget? trailing;

  const ServiceCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    this.subtitle = '',
    this.distanceLabel = '',
    this.etaLabel = '',
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Always white
          borderRadius: BorderRadius.circular(14), // Step 4: 14px radius
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0), // Step 4: border
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),

              // Icon
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (distanceLabel.isNotEmpty ||
                          etaLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (distanceLabel.isNotEmpty) ...[
                              const Icon(Icons.straighten_rounded,
                                  size: 13,
                                  color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                distanceLabel,
                                style: AppTypography.monoMedium
                                    .copyWith(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                            if (distanceLabel.isNotEmpty &&
                                etaLabel.isNotEmpty)
                              const SizedBox(width: 12),
                            if (etaLabel.isNotEmpty) ...[
                              const Icon(Icons.schedule_rounded,
                                  size: 13,
                                  color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                etaLabel,
                                style: AppTypography.monoMedium
                                    .copyWith(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Trailing
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
