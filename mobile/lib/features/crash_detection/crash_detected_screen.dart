import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../presentation/blocs/location/location_cubit.dart';
import 'crash_detection_provider.dart';

class CrashDetectedScreen extends StatefulWidget {
  const CrashDetectedScreen({super.key});

  @override
  State<CrashDetectedScreen> createState() => _CrashDetectedScreenState();
}

class _CrashDetectedScreenState extends State<CrashDetectedScreen>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 10;
  Timer? _timer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    // Trigger Heavy haptic feedback on screen load
    HapticFeedback.heavyImpact();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        _triggerSos(autoTriggered: true);
      } else {
        setState(() {
          _secondsRemaining--;
        });
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _triggerSos({required bool autoTriggered}) {
    _timer?.cancel();

    if (autoTriggered) {
      debugPrint("AUTO_SOS_TRIGGERED");
    }

    final cachedLoc = CrashDetectionProvider.instance.lastLocation;
    final locCubit = context.read<LocationCubit>();

    if (cachedLoc != null) {
      final double lat = cachedLoc['lat'] as double;
      final double lng = cachedLoc['lng'] as double;

      // Seed/update location cache if not already set or override with latest cached driving GPS
      locCubit.updateLocation(lat, lng);
      debugPrint("LAST_LOCATION_USED");
      debugPrint('[OfflineMode] LAST_LOCATION_USED');

      // Show toast/snackbar feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Using Last Known Location"),
          backgroundColor: AppColors.emergencyAmber,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // If we don't have a custom driving cached location, check if LocationCubit has cached coordinates
      if (!locCubit.state.hasLocation) {
        locCubit.loadFromCache();
      }
    }

    // Direct routing to existing SOS countdown/dispatch pipeline
    context.go('/countdown?trigger=crash');
  }

  void _cancelCrash() {
    _timer?.cancel();
    debugPrint("CRASH_CANCELLED");
    CrashDetectionProvider.instance.resetCooldown();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Top Icon: 64px red warning
              const Icon(
                Icons.warning_rounded,
                color: Color(0xFFDC2626),
                size: 64.0,
              ),
              const SizedBox(height: 24.0),

              // Title: Possible Crash Detected
              const Text(
                "Possible Crash Detected",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12.0),

              // Body text
              const Text(
                "We detected a severe impact. Are you okay?",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF475569),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Countdown Ring: circular progress
              SizedBox(
                width: 140.0,
                height: 140.0,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140.0,
                          height: 140.0,
                          child: CircularProgressIndicator(
                            value: 1.0 - _progressController.value,
                            strokeWidth: 8.0,
                            color: const Color(0xFFDC2626),
                            backgroundColor: const Color(0xFFF1F5F9),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          "$_secondsRemaining",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 48.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Spacer(),

              // Button 1: "I'm Safe"
              SizedBox(
                width: double.infinity,
                height: 52.0,
                child: OutlinedButton(
                  onPressed: _cancelCrash,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB), width: 2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    "I'm Safe",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12.0),

              // Button 2: "Trigger SOS Now"
              SizedBox(
                width: double.infinity,
                height: 52.0,
                child: ElevatedButton(
                  onPressed: () => _triggerSos(autoTriggered: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    "Trigger SOS Now",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }
}
