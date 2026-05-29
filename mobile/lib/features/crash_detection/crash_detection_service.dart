import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sensors_plus/sensors_plus.dart';
import 'crash_detection_provider.dart';

class CrashDetectionService {
  static final CrashDetectionService instance = CrashDetectionService._internal();
  CrashDetectionService._internal();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  DateTime? _lastSpikeTime;
  DateTime? _lastDropTime;
  DateTime? _lastGyroTime;

  double _lastAccelMag = 0.0;
  double _lastGyroMag = 0.0;

  void startMonitoring() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint("DRIVING_MODE_ENABLED (Monitoring mock mode on unsupported platform)");
      return;
    }

    debugPrint("SENSOR_MONITORING_STARTED");
    debugPrint("SENSOR_LISTENER_STARTED");

    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((event) {
      _processAccelerometer(event);
    }, onError: (e) {
      debugPrint("Accelerometer stream error: $e");
    });

    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream().listen((event) {
      _processGyroscope(event);
    }, onError: (e) {
      debugPrint("Gyroscope stream error: $e");
    });
  }

  void stopMonitoring() {
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _lastSpikeTime = null;
    _lastDropTime = null;
    _lastGyroTime = null;
    _lastAccelMag = 0.0;
    _lastGyroMag = 0.0;
  }

  void _calculateAndLogCrashScore() {
    final provider = CrashDetectionProvider.instance;
    final isTesting = provider.testingMode;

    // Dynamically scale thresholds based on testing sensitivity mode
    final double accelThreshold = isTesting ? 14.0 : 28.0;
    final double gyroThreshold = isTesting ? 1.8 : 4.0;

    // Calculate component impact scores
    final double accelScore = (_lastAccelMag / accelThreshold).clamp(0.0, 1.2);
    final double gyroScore = (_lastGyroMag / gyroThreshold).clamp(0.0, 1.2);

    // Combined crash score (used for dev debug overlay display)
    final double crashScore = (accelScore * 0.5 + gyroScore * 0.5).clamp(0.0, 1.0);

    provider.updateSensorValues(_lastAccelMag, _lastGyroMag, crashScore);

    // Throttle printing to significant motion events to avoid terminal buffer issues
    if (_lastAccelMag > 5.0 || _lastGyroMag > 0.5) {
      debugPrint("ImpactMagnitude: ${_lastAccelMag.toStringAsFixed(1)}");
      debugPrint("GyroMagnitude: ${_lastGyroMag.toStringAsFixed(1)}");
      debugPrint("CrashScore: ${crashScore.toStringAsFixed(2)}");
    }
  }

  void _processAccelerometer(AccelerometerEvent event) {
    debugPrint("ACCEL_DATA_RECEIVED");
    final now = DateTime.now();
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _lastAccelMag = magnitude;

    final provider = CrashDetectionProvider.instance;
    final isTesting = provider.testingMode;

    final double spikeThreshold = isTesting ? 14.0 : 28.0;
    final double dropThreshold = isTesting ? 7.0 : 4.0;

    _calculateAndLogCrashScore();

    if (magnitude > spikeThreshold) {
      _lastSpikeTime = now;
      debugPrint("Accelerometer spike detected: ${magnitude.toStringAsFixed(2)} m/s²");
    } else if (magnitude < dropThreshold && _lastSpikeTime != null) {
      final timeSinceSpike = now.difference(_lastSpikeTime!).inMilliseconds;
      if (timeSinceSpike > 0 && timeSinceSpike <= 1500) {
        _lastDropTime = now;
        debugPrint("Accelerometer drop detected: ${magnitude.toStringAsFixed(2)} m/s² ($timeSinceSpike ms after spike)");
        _checkCrashCondition();
      }
    }
  }

  void _processGyroscope(GyroscopeEvent event) {
    debugPrint("GYRO_DATA_RECEIVED");
    final now = DateTime.now();
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _lastGyroMag = magnitude;

    final provider = CrashDetectionProvider.instance;
    final isTesting = provider.testingMode;

    final double gyroThreshold = isTesting ? 1.8 : 4.0;

    _calculateAndLogCrashScore();

    if (magnitude > gyroThreshold) {
      _lastGyroTime = now;
      debugPrint("Gyroscope spike detected: ${magnitude.toStringAsFixed(2)} rad/s");
      _checkCrashCondition();
    }
  }

  void _checkCrashCondition() {
    if (_lastSpikeTime == null || _lastDropTime == null || _lastGyroTime == null) {
      return;
    }

    final diffSpikeDrop = _lastDropTime!.difference(_lastSpikeTime!).inMilliseconds.abs();
    final diffSpikeGyro = _lastGyroTime!.difference(_lastSpikeTime!).inMilliseconds.abs();
    final diffDropGyro = _lastGyroTime!.difference(_lastDropTime!).inMilliseconds.abs();

    if (diffSpikeDrop <= 1500 && diffSpikeGyro <= 1500 && diffDropGyro <= 1500) {
      if (CrashDetectionProvider.instance.isCooldownActive) {
        debugPrint("Possible crash detected, but cooldown is active. Ignoring.");
        return;
      }

      // Trigger detection
      _lastSpikeTime = null;
      _lastDropTime = null;
      _lastGyroTime = null;

      CrashDetectionProvider.instance.onCrashDetected();
    }
  }
}
