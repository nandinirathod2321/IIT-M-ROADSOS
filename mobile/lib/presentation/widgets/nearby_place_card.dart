import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/models/nearby_place.dart';
import '../../core/utils/logger.dart';

class NearbyPlaceCard extends StatelessWidget {
  final NearbyPlace place;

  const NearbyPlaceCard({super.key, required this.place});

  Color _getTypeColor() {
    switch (place.type) {
      case NearbyPlaceType.hospital:
        return AppColors.emergency;
      case NearbyPlaceType.police:
        return AppColors.primary;
      case NearbyPlaceType.towing:
        return AppColors.warningAmber;
    }
  }

  String _getTypeLabel() {
    switch (place.type) {
      case NearbyPlaceType.hospital:
        return 'HOSPITAL';
      case NearbyPlaceType.police:
        return 'POLICE';
      case NearbyPlaceType.towing:
        return 'TOWING';
    }
  }

  Future<void> _makeCall() async {
    if (place.phone == null || place.phone!.isEmpty) return;
    
    final cleanPhone = place.phone!.replaceAll(RegExp(r'\s+'), '');
    final Uri url = Uri.parse('tel:$cleanPhone');
    
    AppLogger.info('Triggering emergency phone call to ${place.name} at $cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        AppLogger.warning('Could not launch dialer for url: $url');
      }
    } catch (e) {
      AppLogger.error('Failed to trigger phone call dialer', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color-coded strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            
            // Core Card Contents
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Info Panel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type Tag & Distance Badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getTypeLabel(),
                                  style: AppTypography.labelCaps.copyWith(
                                    fontSize: 13, // Minimum 13px
                                    color: typeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${place.distanceKm.toStringAsFixed(1)} KM AWAY',
                                style: AppTypography.monoMedium.copyWith(
                                  fontSize: 13, // Minimum 13px
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Place Name
                          Text(
                            place.name.toUpperCase(),
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Place Address
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  place.address,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 14, // Minimum 14px for body text
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Right Call Action Panel
                    if (place.phone != null && place.phone!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: _makeCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emergency,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            minimumSize: const Size(60, 44), // Ensure 44px minimum touch target
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'CALL',
                                style: AppTypography.labelCaps.copyWith(
                                  color: Colors.white,
                                  fontSize: 13, // Minimum 13px
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
