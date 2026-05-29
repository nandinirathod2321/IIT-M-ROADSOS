import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import 'crash_detection_service.dart';
import 'crash_detector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/blocs/location/location_cubit.dart';

class CrashDetectionProvider extends ChangeNotifier {
  static final CrashDetectionProvider instance = CrashDetectionProvider._internal();
  CrashDetectionProvider._internal();

  bool _drivingMode = false;
  bool get drivingMode => _drivingMode;

  bool _isCooldownActive = false;
  bool get isCooldownActive => _isCooldownActive;

  bool _testingMode = false;
  bool get testingMode => _testingMode;

  double _currentAccel = 0.0;
  double get currentAccel => _currentAccel;

  double _currentGyro = 0.0;
  double get currentGyro => _currentGyro;

  double _currentScore = 0.0;
  double get currentScore => _currentScore;

  Map<String, dynamic>? _lastLocation;
  Map<String, dynamic>? get lastLocation => _lastLocation;

  StreamSubscription<Position>? _positionSub;
  Timer? _cooldownTimer;

  void toggleTestingMode(bool value) {
    _testingMode = value;
    notifyListeners();
  }

  void updateSensorValues(double accel, double gyro, double score) {
    _currentAccel = accel;
    _currentGyro = gyro;
    _currentScore = score;
    notifyListeners();
  }

  static Map<String, dynamic>? getCachedLocation() {
    return instance._lastLocation;
  }

  void toggleDrivingMode(bool value) {
    if (_drivingMode == value) return;
    _drivingMode = value;

    final context = AppRouter.rootNavigatorKey.currentContext;
    LocationCubit? locCubit;
    if (context != null) {
      try {
        locCubit = context.read<LocationCubit>();
      } catch (_) {}
    }

    if (_drivingMode) {
      debugPrint("DRIVING_MODE_ENABLED");
      debugPrint("DRIVING_MODE_STARTED");
      _startLocationCaching();
      CrashDetectionService.instance.startMonitoring();
      locCubit?.enableLocationUpdates();
      try {
        CrashDetector.instance.startListening();
      } catch (e) {
        debugPrint("Failed to start legacy crash detector: $e");
      }
    } else {
      debugPrint("DRIVING_MODE_DISABLED");
      _stopLocationCaching();
      CrashDetectionService.instance.stopMonitoring();
      locCubit?.disableLocationUpdates();
      try {
        CrashDetector.instance.stopListening();
      } catch (e) {
        debugPrint("Failed to stop legacy crash detector: $e");
      }
    }
    notifyListeners();
  }

  void _startLocationCaching() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _lastLocation = {
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': position.timestamp,
        'speed': position.speed,
      };
      debugPrint("Cached GPS update: $_lastLocation");
      notifyListeners();
    }, onError: (e) {
      debugPrint("Geolocator position stream error: $e");
    });
  }

  void _stopLocationCaching() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void onCrashDetected() {
    if (_isCooldownActive) return;

    // Heavy haptic feedback on possible crash detection
    HapticFeedback.heavyImpact();

    // Trigger possible crash log
    debugPrint("POSSIBLE_CRASH_DETECTED");

    // Start 30 second cooldown
    _isCooldownActive = true;
    notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 30), () {
      _isCooldownActive = false;
      notifyListeners();
    });

    // Full screen navigation to crash screen
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context != null) {
      context.push('/crash_detected');
    }
  }

  void resetCooldown() {
    _cooldownTimer?.cancel();
    _isCooldownActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLocationCaching();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
