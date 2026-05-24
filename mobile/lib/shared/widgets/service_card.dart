import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// A card representing a nearby emergency service (hospital, police,
/// or towing). Follows the RoadSOS design spec:
///   • Surface background with 1 px subtle border
///   • No elevation / shadow
///   • 4 px border radius
///   • Colour-coded leading accent strip per service type
///
/// Usage:
/// ```dart
/// ServiceCard(
///   icon: Icons.local_hospital_rounded,
///   accentColor: AppColors.infoBlue,
///   title: 'City General Hospital',
///   subtitle: 'Trauma Centre · 24/7 Emergency',
///   distanceLabel: '3.2 km',
///   etaLabel: '~5 min',
///   onTap: () => _openDetails(hospital),
/// )
/// ```
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
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
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
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
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
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
                              Icon(Icons.straighten_rounded,
                                  size: 12,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                distanceLabel,
                                style: AppTypography.monoMedium
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                            if (distanceLabel.isNotEmpty &&
                                etaLabel.isNotEmpty)
                              const SizedBox(width: 12),
                            if (etaLabel.isNotEmpty) ...[
                              Icon(Icons.schedule_rounded,
                                  size: 12,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                etaLabel,
                                style: AppTypography.monoMedium
                                    .copyWith(fontSize: 12),
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
