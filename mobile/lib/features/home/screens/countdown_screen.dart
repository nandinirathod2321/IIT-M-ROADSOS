import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/emergency_communication_service.dart';
import '../../../core/utils/emergency_logger.dart';
import '../../../presentation/blocs/location/location_cubit.dart';
import 'sos_success_screen.dart';

/// Full-screen critical SOS Countdown Screen.
class CountdownScreen extends StatefulWidget {
  final String triggerType;
  const CountdownScreen({super.key, this.triggerType = 'manual'});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with SingleTickerProviderStateMixin {
  final EmergencyCommunicationService _communicationService = EmergencyCommunicationService();

  int _secondsLeft = 10;
  Timer? _countdownTimer;
  bool _isDispatching = false;
  bool _isCancelled = false;

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    
    // Log countdown start
    EmergencyLogger.log("Countdown started (source: ${widget.triggerType})");

    // Animation controller for the circular sweep (10 seconds total)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _progressController.forward();

    // Start 1-second interval periodic timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          timer.cancel();
          _dispatchEmergency();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  /// Cancels the emergency flow and returns to HomeScreen
  void _cancelSos() {
    setState(() {
      _isCancelled = true;
      _countdownTimer?.cancel();
      _progressController.stop();
    });
    
    EmergencyLogger.log("Countdown cancelled by user.");
    context.go('/');
  }

  /// Triggers the background orchestrator and navigates to the success checklist screen
  Future<void> _dispatchEmergency() async {
    if (_isCancelled || _isDispatching) return;

    setState(() {
      _isDispatching = true;
    });

    await EmergencyLogger.log("Countdown completed. Initiating emergency broadcasts...");

    final locCubit = context.read<LocationCubit>();
    final double lat = locCubit.state.latitude ?? 23.0225;
    final double lng = locCubit.state.longitude ?? 72.5714;
    final String name = AuthService.instance.currentUserFullName ?? 'RoadSOS User';

    try {
      // Execute steps 4-7 concurrently in the background
      final result = await _communicationService.triggerEmergency(
        lat: lat,
        lng: lng,
        userName: name,
        emergencyType: widget.triggerType,
      );

      final prefs = await SharedPreferences.getInstance();
      final permCall = prefs.getBool('perm_call') ?? false;
      final permSms = prefs.getBool('perm_sms') ?? false;
      final conn = await Connectivity().checkConnectivity();
      final isOffline = conn.contains(ConnectivityResult.none);

      final hospitals = result['hospitals'] as List? ?? [];
      final nearest = hospitals.isNotEmpty ? hospitals.first : null;

      if (!mounted) return;

      if (nearest != null) {
        // Compute estimated minutes at 40 km/h: (distance / 40) * 60 minutes
        final int minutes = nearest.estimatedMinutes > 0
            ? nearest.estimatedMinutes.round()
            : (nearest.distanceKm / 40.0 * 60).round();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SosSuccessScreen(
              hospitalName: nearest.name,
              hospitalLat: nearest.latitude,
              hospitalLng: nearest.longitude,
              distanceText: "${nearest.distanceKm.toStringAsFixed(1)} km",
              estimatedTime: "~$minutes min",
              callTriggered: result['callTriggered'] ?? false,
              callPermissionGranted: permCall,
              smsCount: result['smsCount'] ?? 0,
              smsPermissionGranted: permSms,
              emailSentOrQueued: result['emailSentOrQueued'] ?? false,
              isOffline: isOffline,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SosSuccessScreen.fallback(
              callTriggered: result['callTriggered'] ?? false,
              callPermissionGranted: permCall,
              smsCount: result['smsCount'] ?? 0,
              smsPermissionGranted: permSms,
              emailSentOrQueued: result['emailSentOrQueued'] ?? false,
              isOffline: isOffline,
            ),
          ),
        );
      }
    } catch (e) {
      await EmergencyLogger.log("Critical error during SOS orchestration: $e");
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // 1. Critical Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: AppColors.emergencyRed,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "⚠ Emergency Detected",
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.emergencyRed,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isDispatching
                      ? "BROADCASTING SOS ALERT PACKETS..."
                      : "Calling emergency services in $_secondsLeft seconds",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDispatching
                      ? "Alerting rescue contacts & establishing satellite routing..."
                      : "Hold CANCEL to halt emergency alerts if this was a mistake.",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),

                const Spacer(),

                // 2. Animated Circular Countdown Sweep
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner Outer Ripple Ring
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emergencyRed.withValues(alpha: 0.05),
                        ),
                      ),
                      // Circular Sweep
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: 1.0 - _progressController.value,
                              strokeWidth: 10,
                              backgroundColor: AppColors.surfaceAlt,
                              color: AppColors.emergencyRed,
                            );
                          },
                        ),
                      ),
                      // Centered Counter
                      Container(
                        width: 150,
                        height: 150,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                        ),
                        child: Center(
                          child: _isDispatching
                              ? const CircularProgressIndicator(
                                  color: AppColors.emergencyRed,
                                  strokeWidth: 4,
                                )
                              : Text(
                                  "$_secondsLeft",
                                  style: AppTypography.displayMedium.copyWith(
                                    fontSize: 64,
                                    color: AppColors.emergencyRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 3. CANCEL Action Button
                if (!_isDispatching)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _cancelSos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "CANCEL",
                        style: AppTypography.labelCaps.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
