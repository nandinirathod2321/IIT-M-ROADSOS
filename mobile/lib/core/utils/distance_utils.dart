import 'dart:math';

/// Geospatial utility helpers for RoadSOS.
///
/// Provides Haversine-based distance calculations and ETA estimation
/// used by the database layer for sorting nearby services.
abstract final class DistanceUtils {
  /// Mean radius of the Earth in kilometres.
  static const double _earthRadiusKm = 6371.0;

  /// Returns the great-circle distance in **kilometres** between two
  /// geographic coordinates using the Haversine formula.
  ///
  /// [lat1], [lng1] — origin point (degrees).
  /// [lat2], [lng2] — destination point (degrees).
  static double haversine(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  /// Estimates travel time in **minutes** for a given [distanceKm],
  /// assuming an average urban speed of [avgSpeedKmh] (default 40 km/h).
  static double estimateMinutes(
    double distanceKm, {
    double avgSpeedKmh = 40.0,
  }) {
    if (avgSpeedKmh <= 0) return double.infinity;
    return (distanceKm / avgSpeedKmh) * 60;
  }

  /// Converts [degrees] to radians.
  static double _degToRad(double degrees) => degrees * (pi / 180);
}
