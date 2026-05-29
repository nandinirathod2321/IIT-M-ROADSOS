import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_card.dart';

/// Launches navigation intent or browser URL to Google Maps directions.
Future<void> launchHospitalNavigation(double? lat, double? lng) async {
  if (lat == null || lng == null) {
    final fallbackUrl = Uri.parse("https://www.google.com/maps/search/hospital+near+me");
    try {
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return;
  }

  final primaryUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");

  if (kIsWeb) {
    try {
      if (await canLaunchUrl(primaryUrl)) {
        await launchUrl(primaryUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return;
  }

  if (Platform.isAndroid) {
    final androidIntent = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    try {
      if (await canLaunchUrl(androidIntent)) {
        await launchUrl(androidIntent, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(primaryUrl)) {
          await launchUrl(primaryUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      try {
        if (await canLaunchUrl(primaryUrl)) {
          await launchUrl(primaryUrl, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  } else {
    try {
      if (await canLaunchUrl(primaryUrl)) {
        await launchUrl(primaryUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}

/// Screen displayed after a critical SOS alert is dispatched.
/// Replaces the responder tracker screen and focuses solely on guiding
/// the user to the nearest hospital facility using Google Maps.
class SosSuccessScreen extends StatelessWidget {
  final String? hospitalName;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? distanceText;
  final String? estimatedTime;
  final bool isFallback;

  const SosSuccessScreen({
    super.key,
    required this.hospitalName,
    required this.hospitalLat,
    required this.hospitalLng,
    required this.distanceText,
    required this.estimatedTime,
  }) : isFallback = false;

  const SosSuccessScreen.fallback({super.key})
      : hospitalName = null,
        hospitalLat = null,
        hospitalLng = null,
        distanceText = null,
        estimatedTime = null,
        isFallback = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      // Strictly no back button in appBar and no leading dismiss button
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // 1. Success State Icon & Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.safeGreen,
                  size: 72,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "EMERGENCY ALERT SENT",
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.safeGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Emergency Alert Sent Successfully",
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your critical broadcast was transmitted to Cellular and BLE Mesh networks. Responders have been notified of your incident.",
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),

              const Spacer(flex: 1),

              // 2. Hospital details card
              if (!isFallback && hospitalName != null) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: AppColors.emergencyRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Nearest Hospital Found",
                              style: AppTypography.labelCaps.copyWith(
                                color: AppColors.emergencyRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hospitalName!,
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 20,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMetricBadge(Icons.navigation_rounded, distanceText ?? "Pending"),
                          const SizedBox(width: 12),
                          _buildMetricBadge(Icons.access_time_filled_rounded, estimatedTime ?? "Pending"),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Fallback card if hospital data is null
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningAmber.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_searching_rounded,
                              color: AppColors.warningAmber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Nearest Hospital Pending",
                              style: AppTypography.labelCaps.copyWith(
                                color: AppColors.warningAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Could not resolve nearest trauma facility in real-time. Please utilize external search mode below.",
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // 3. NAVIGATE NOW (Primary CTA)
              if (!isFallback) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => launchHospitalNavigation(hospitalLat, hospitalLng),
                    icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 20),
                    label: Text(
                      "NAVIGATE NOW",
                      style: AppTypography.labelCaps.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 4. Search Nearby Hospitals (Secondary or Primary Fallback)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => launchHospitalNavigation(null, null),
                  icon: Icon(
                    Icons.search_rounded,
                    color: isFallback ? Colors.white : AppColors.textPrimary,
                    size: 20,
                  ),
                  label: Text(
                    "Search Nearby Hospitals",
                    style: AppTypography.labelCaps.copyWith(
                      color: isFallback ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isFallback ? AppColors.emergencyRed : Colors.transparent,
                    side: BorderSide(
                      color: isFallback ? Colors.transparent : AppColors.borderSubtle,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // 5. Safe Return to Home Menu Button
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  "RETURN TO HOME SCREEN",
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTypography.monoMedium.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
