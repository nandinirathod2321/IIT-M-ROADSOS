import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/crash_detection/crash_detector.dart';
import 'core/router/app_router.dart';
import 'data/database/db_initializer.dart';
import 'core/services/auth_service.dart';
import 'core/services/map_cache_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log sensor initialization skipped at startup as required by FIX 2
  debugPrint("SENSOR_INIT_SKIPPED_AT_STARTUP");

  // Load environment variables (fast)
  try {
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    debugPrint("[AntiGravity] API Key loaded: ${apiKey.isNotEmpty}");
  } catch (e) {
    debugPrint("[AntiGravity] Failed to load .env file: $e");
  }

  // Lock device orientation to portrait
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint("SystemChrome error: $e");
  }

  // Set system navigation overlay styling for premium light mode visuals
  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  } catch (e) {
    debugPrint("SystemUIOverlayStyle error: $e");
  }

  // Retrieve SharedPreferences and determine initialLocation immediately (fast and safe)
  SharedPreferences? prefs;
  bool onboardingDone = false;
  bool loggedIn = false;
  try {
    prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  } catch (e) {
    debugPrint("SharedPreferences initialization error: $e");
  }

  // Defer heavy database and authentication initialization after the first frame renders
  Future.microtask(() async {
    try {
      // Initialize SQLite local spatial nodes database in background
      await DbInitializer.initialize();
      debugPrint("DbInitializer initialized in background.");
    } catch (e) {
      debugPrint("DbInitializer error (graceful fallback): $e");
    }

    try {
      // Initialize unified Authentication and session manager in background
      await AuthService.initialize();
      debugPrint("AuthService initialized in background.");
    } catch (e) {
      debugPrint("AuthService error (graceful fallback): $e");
    }

    // Pre-initialize map tile cache store (fire-and-forget)
    () async {
      try {
        await MapCacheService.instance.getCacheStore();
      } catch (e) {
        debugPrint('[MapCache] Pre-init failed (non-blocking): $e');
      }
    }();

    // Initialize and run background telemetry daemon if enabled (without starting sensors)
    try {
      final SharedPreferences p = prefs ?? await SharedPreferences.getInstance();
      final double accelThreshold = p.getDouble('accel_threshold') ?? 25.0;
      final double gyroThreshold = p.getDouble('gyro_threshold') ?? 4.0;
      final bool crashEnabled = p.getBool('crash_detection') ?? true;

      if (crashEnabled) {
        CrashDetector.instance.updateThresholds(
          accel: accelThreshold,
          gyro: gyroThreshold,
        );
        // Do NOT call CrashDetector.instance.startListening() at startup to prevent opening sensor streams
        CrashDetector.instance.onCrashDetected = (event) {
          AppRouter.rootNavigatorKey.currentContext?.go(
            '/countdown',
            extra: event,
          );
        };
      }
    } catch (e) {
      debugPrint("Telemetry initialization error: $e");
    }

    debugPrint("ANDROID_READY");
  });

  // Resolve initial location
  try {
    loggedIn = AuthService.instance.isLoggedIn;
  } catch (_) {
    // If AuthService is not initialized yet, fall back to false
  }

  final String initialLocation;
  if (!onboardingDone) {
    initialLocation = '/onboarding';
  } else if (loggedIn) {
    initialLocation = '/';
  } else {
    initialLocation = '/login';
  }

  runApp(RoadSOSApp(initialLocation: initialLocation));
  debugPrint("APP_INITIALIZED");
}
