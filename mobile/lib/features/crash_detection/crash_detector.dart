import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Model representing a crash event detected by sensors or simulated in demo mode.
class CrashEvent {
  final DateTime timestamp;
  final double? lat;
  final double? lng;
  final String severity;
  final double accelMagnitude;
  final double gyroMagnitude;

  const CrashEvent({
    required this.timestamp,
    this.lat,
    this.lng,
    required this.severity,
    required this.accelMagnitude,
    required this.gyroMagnitude,
  });
}

/// Core singleton service for monitoring device sensors and triggering crash detection alerts.
class CrashDetector {
  CrashDetector._privateConstructor();
  static final CrashDetector instance = CrashDetector._privateConstructor();

  void Function(CrashEvent)? onCrashDetected;

  bool _isListening = false;
  bool get isListening => _isListening;

  double _accelThreshold = 25.0;
  double _gyroThreshold = 4.0;

  double get accelThreshold => _accelThreshold;
  double get gyroThreshold => _gyroThreshold;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double? _lastAccelMag;
  DateTime? _lastAccelTime;
  DateTime? _lastTriggerTime;

  /// Dynamic battery-safe activation: sensor streams are only active when listening is true.
  void startListening() {
    if (_isListening) return;
    _isListening = true;
    debugPrint("CrashDetector: started listening with accel=$_accelThreshold, gyro=$_gyroThreshold");

    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _handleAccelerometer(event);
      },
      onError: (e) {
        debugPrint("CrashDetector: Accelerometer error: $e");
      },
    );

    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream().listen(
      (GyroscopeEvent event) {
        _handleGyroscope(event);
      },
      onError: (e) {
        debugPrint("CrashDetector: Gyroscope error: $e");
      },
    );
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    debugPrint("CrashDetector: stopped listening");

    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _lastAccelMag = null;
    _lastAccelTime = null;
  }

  void updateThresholds({required double accel, required double gyro}) {
    _accelThreshold = accel;
    _gyroThreshold = gyro;
    debugPrint("CrashDetector: updated thresholds to accel=$accel, gyro=$gyro");
  }

  /// Processes accelerometer events to monitor impacts and sudden deceleration.
  void _handleAccelerometer(AccelerometerEvent event) {
    final now = DateTime.now();
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Sudden Deceleration & Sudden Stop Logic:
    // Tracks vector change rate and magnitude delta over time.
    if (_lastAccelMag != null && _lastAccelTime != null) {
      final timeDeltaMs = now.difference(_lastAccelTime!).inMilliseconds;
      if (timeDeltaMs > 0 && timeDeltaMs < 250) {
        final accelDelta = (magnitude - _lastAccelMag!).abs();

        // Trigger condition 1: Sudden Impact (magnitude exceeds peak threshold)
        // Trigger condition 2: Sudden Deceleration (sudden velocity delta exceeding 60% of threshold)
        if (magnitude > _accelThreshold || accelDelta > (_accelThreshold * 0.6)) {
          _triggerCrash(magnitude, 0.0);
        }
      }
    }

    _lastAccelMag = magnitude;
    _lastAccelTime = now;
  }

  /// Processes gyroscope events to detect abnormal roll/yaw/spin anomalies.
  void _handleGyroscope(GyroscopeEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Trigger condition 3: Extreme rotation speed representing vehicular rollover
    if (magnitude > _gyroThreshold) {
      _triggerCrash(0.0, magnitude);
    }
  }

  /// Unified trigger pipeline executing callbacks and outputting required console metrics.
  void _triggerCrash(double accelMag, double gyroMag) {
    final now = DateTime.now();
    // Cooldown window (15 seconds) to avoid duplicate countdown stack launches
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inSeconds < 15) {
      return;
    }
    _lastTriggerTime = now;

    debugPrint('[OfflineMode] POSSIBLE_CRASH_DETECTED');

    final event = CrashEvent(
      timestamp: now,
      severity: accelMag > 40.0 ? 'Critical' : 'Moderate',
      accelMagnitude: accelMag,
      gyroMagnitude: gyroMag,
    );

    if (onCrashDetected != null) {
      onCrashDetected!(event);
    }
  }
}
