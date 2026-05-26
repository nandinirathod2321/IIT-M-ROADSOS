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
        return AppColors.emergencyRed;
      case NearbyPlaceType.police:
        return AppColors.infoBlue;
      case NearbyPlaceType.towing:
        return AppColors.towingOrange;
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
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: typeColor, width: 4),
          top: const BorderSide(color: AppColors.borderSubtle, width: 1),
          right: const BorderSide(color: AppColors.borderSubtle, width: 1),
          bottom: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
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
                      color: typeColor.withOpacity(0.1),
                      child: Text(
                        _getTypeLabel(),
                        style: AppTypography.labelCaps.copyWith(
                          fontSize: 9,
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${place.distanceKm.toStringAsFixed(1)} KM AWAY',
                      style: AppTypography.monoMedium.copyWith(
                        fontSize: 9,
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
                    Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place.address,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
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
                  backgroundColor: AppColors.emergencyRed,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
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
                        fontSize: 10,
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
    );
  }
}
