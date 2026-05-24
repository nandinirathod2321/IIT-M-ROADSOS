import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/colors.dart';
import 'features/crash_detection/crash_detector.dart';
import 'core/router/app_router.dart';
import 'data/database/db_initializer.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock device orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system navigation overlay styling for premium immersive visuals
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize SQLite local spatial nodes database
  await DbInitializer.initialize();

  // Inspect onboarding status
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_complete') ?? false;

  // Initialize and run background telemetry daemon if enabled
  final double accelThreshold = prefs.getDouble('accel_threshold') ?? 25.0;
  final double gyroThreshold = prefs.getDouble('gyro_threshold') ?? 4.0;
  final bool crashEnabled = prefs.getBool('crash_detection') ?? true;

  if (crashEnabled) {
    CrashDetector.instance.updateThresholds(
      accel: accelThreshold,
      gyro: gyroThreshold,
    );
    CrashDetector.instance.startListening();
    CrashDetector.instance.onCrashDetected = (event) {
      // Direct global routing context breakout outside the widget lifecycle
      AppRouter.navigatorKey.currentContext?.go(
        '/countdown',
        extra: event,
      );
    };
  }

  runApp(RoadSOSApp(initialLocation: onboardingDone ? '/' : '/onboarding'));
}
