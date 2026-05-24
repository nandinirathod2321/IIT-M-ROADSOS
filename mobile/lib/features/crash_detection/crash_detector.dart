
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

  void startListening() {
    _isListening = true;
    print("CrashDetector: started listening with accel=$_accelThreshold, gyro=$_gyroThreshold");
  }

  void stopListening() {
    _isListening = false;
    print("CrashDetector: stopped listening");
  }

  void updateThresholds({required double accel, required double gyro}) {
    _accelThreshold = accel;
    _gyroThreshold = gyro;
    print("CrashDetector: updated thresholds to accel=$accel, gyro=$gyro");
  }
}
