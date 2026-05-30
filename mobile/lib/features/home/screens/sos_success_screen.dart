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
  try {
    if (lat == null || lng == null) {
      final searchUrl = Uri.parse("https://www.google.com/maps/search/hospital+near+me");
      if (await canLaunchUrl(searchUrl)) {
        await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final fallbackUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");

    if (kIsWeb) {
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (Platform.isAndroid) {
      final nativeIntent = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
      if (await canLaunchUrl(nativeIntent)) {
        await launchUrl(nativeIntent, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        }
      }
    } else {
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    }
  } catch (_) {
    // Graceful degradation - never crash
  }
}

/// Screen displayed after a critical SOS alert is dispatched.
class SosSuccessScreen extends StatelessWidget {
  final String? hospitalName;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? distanceText;
  final String? estimatedTime;
  final bool isFallback;

  // Actions Checklist States
  final bool callTriggered;
  final bool callPermissionGranted;
  final int smsCount;
  final bool smsPermissionGranted;
  final bool emailSentOrQueued;
  final bool isOffline;

  const SosSuccessScreen({
    super.key,
    required this.hospitalName,
    required this.hospitalLat,
    required this.hospitalLng,
    required this.distanceText,
    required this.estimatedTime,
    this.callTriggered = true,
    this.callPermissionGranted = true,
    this.smsCount = 0,
    this.smsPermissionGranted = true,
    this.emailSentOrQueued = true,
    this.isOffline = false,
  }) : isFallback = false;

  const SosSuccessScreen.fallback({
    super.key,
    this.callTriggered = false,
    this.callPermissionGranted = false,
    this.smsCount = 0,
    this.smsPermissionGranted = false,
    this.emailSentOrQueued = false,
    this.isOffline = false,
  })  : hospitalName = null,
        hospitalLat = null,
        hospitalLng = null,
        distanceText = null,
        estimatedTime = null,
        isFallback = true;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Do not allow back navigation
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            "EMERGENCY DISPATCH STATUS",
            style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary, fontSize: 13),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Success Indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.safeGreen,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Emergency Alert Sent Successfully",
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineLarge.copyWith(
                          color: AppColors.safeGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Actions Completed Checklist
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "COMMUNICATION LOGS",
                          style: AppTypography.labelCaps.copyWith(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildChecklistItem(
                              isSuccess: callTriggered,
                              text: callTriggered 
                                  ? "Emergency services called" 
                                  : "Emergency services call skipped",
                              fallbackWidget: !callPermissionGranted
                                  ? TextButton.icon(
                                      onPressed: () => launchHospitalNavigation(null, null), // calls tel:108
                                      icon: const Icon(Icons.phone, size: 14, color: AppColors.emergencyRed),
                                      label: Text(
                                        "Tap to call 108",
                                        style: AppTypography.bodySmall.copyWith(color: AppColors.emergencyRed, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                            ),
                            const Divider(color: AppColors.borderSubtle, height: 16),
                            _buildChecklistItem(
                              isSuccess: smsPermissionGranted && smsCount > 0,
                              text: smsPermissionGranted 
                                  ? "SMS sent to $smsCount contacts" 
                                  : "SMS permission not granted",
                              isWarning: !smsPermissionGranted,
                            ),
                            const Divider(color: AppColors.borderSubtle, height: 16),
                            _buildChecklistItem(
                              isSuccess: emailSentOrQueued,
                              text: isOffline 
                                  ? "Queued — will send when online" 
                                  : "Email alerts sent",
                              isPending: isOffline,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. Hospital Card
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "NEAREST MEDICAL ASSISTANCE",
                          style: AppTypography.labelCaps.copyWith(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isFallback && hospitalName != null) ...[
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_hospital, color: AppColors.emergencyRed, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Nearest Hospital Found",
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                hospitalName!,
                                style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildMetricBadge(Icons.navigation, distanceText ?? "Pending"),
                                  const SizedBox(width: 8),
                                  _buildMetricBadge(Icons.access_time, estimatedTime ?? "Pending"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_searching, color: AppColors.warningAmber, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Nearest Hospital Pending",
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.warningAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Trauma facility coordinates could not be resolved instantly. Utilize external map navigation below.",
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom persistent navigation actions
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Emergency Call Fallback Button (red & prominent if call permission denied)
                    if (!callPermissionGranted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:108'), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: Text(
                            "CALL 108 NOW",
                            style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emergencyRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Navigate to hospital
                    if (!isFallback) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => launchHospitalNavigation(hospitalLat, hospitalLng),
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: Text(
                            "NAVIGATE TO HOSPITAL",
                            style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 13, letterSpacing: 1.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: callPermissionGranted ? AppColors.emergencyRed : AppColors.surfaceAlt,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Search Nearby
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => launchHospitalNavigation(null, null),
                        icon: Icon(Icons.search, color: isFallback ? Colors.white : AppColors.textPrimary),
                        label: Text(
                          "SEARCH NEARBY HOSPITALS",
                          style: AppTypography.labelCaps.copyWith(
                            color: isFallback ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isFallback ? AppColors.emergencyRed : Colors.transparent,
                          side: BorderSide(color: isFallback ? Colors.transparent : AppColors.borderSubtle, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Safe Home Return Button
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        "RETURN TO HOME SCREEN",
                        style: AppTypography.labelCaps.copyWith(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem({
    required bool isSuccess,
    required String text,
    bool isWarning = false,
    bool isPending = false,
    Widget? fallbackWidget,
  }) {
    IconData iconData = Icons.check_circle;
    Color iconColor = AppColors.safeGreen;

    if (isPending) {
      iconData = Icons.hourglass_empty;
      iconColor = AppColors.warningAmber;
    } else if (isWarning || !isSuccess) {
      iconData = Icons.warning;
      iconColor = AppColors.warningAmber;
    }

    return Row(
      children: [
        Icon(iconData, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (fallbackWidget != null) fallbackWidget,
      ],
    );
  }

  Widget _buildMetricBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.monoMedium.copyWith(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
