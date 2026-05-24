/// Application-wide constants for RoadSOS.
///
/// Crash-detection thresholds, search radii, mesh-network limits, and
/// version metadata are all centralised here so they can be tuned
/// from a single location.
abstract final class AppConstants {
  // ── Crash detection ──────────────────────────────────────────────────

  /// Linear acceleration threshold (m/s²) to flag a potential crash.
  static const double crashAccelThreshold = 25.0;

  /// Angular velocity threshold (rad/s) to flag a potential crash.
  static const double crashGyroThreshold = 4.0;

  /// Time window (ms) within which both accel + gyro must exceed their
  /// respective thresholds for a crash event to be considered valid.
  static const int crashFusionWindowMs = 500;

  // ── Countdown ────────────────────────────────────────────────────────

  /// Seconds the user has to cancel an auto-triggered SOS.
  static const int countdownSeconds = 10;

  // ── Search ───────────────────────────────────────────────────────────

  /// Default radius (km) for nearby-service queries.
  static const int defaultSearchRadiusKm = 50;

  // ── Mesh networking ──────────────────────────────────────────────────

  /// Maximum number of hops an SOS packet may take in the mesh network.
  static const int meshMaxHops = 8;

  // ── App metadata ─────────────────────────────────────────────────────

  /// Current public version string.
  static const String appVersion = '1.0.0';
}
