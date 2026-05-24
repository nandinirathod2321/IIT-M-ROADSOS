import 'package:equatable/equatable.dart';

/// Represents a roadside towing / vehicle recovery service.
///
/// [distanceKm] is computed at query time based on the user's
/// current location and is not stored in the database.
class TowingService extends Equatable {
  final String id;
  final String name;
  final String phone;
  final double lat;
  final double lng;

  /// Maximum service radius this provider covers (km).
  final double serviceRadius;

  /// Human-readable operating hours, e.g. "24/7" or "08:00–22:00".
  final String operatingHours;

  /// Vehicle categories supported, e.g. ["car", "bike", "truck"].
  final List<String> vehicleTypes;

  /// Computed — straight-line distance from the user's position (km).
  final double distanceKm;

  const TowingService({
    required this.id,
    required this.name,
    required this.phone,
    required this.lat,
    required this.lng,
    this.serviceRadius = 0.0,
    this.operatingHours = '',
    this.vehicleTypes = const [],
    this.distanceKm = 0.0,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates a [TowingService] from a database row / JSON map.
  factory TowingService.fromMap(Map<String, dynamic> map) {
    return TowingService(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      serviceRadius: (map['serviceRadius'] as num?)?.toDouble() ?? 0.0,
      operatingHours: map['operatingHours'] as String? ?? '',
      vehicleTypes: map['vehicleTypes'] != null
          ? (map['vehicleTypes'] as String).split(',')
          : const [],
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'lat': lat,
      'lng': lng,
      'serviceRadius': serviceRadius,
      'operatingHours': operatingHours,
      'vehicleTypes': vehicleTypes.join(','),
    };
  }

  /// Returns a copy with the computed distance field populated.
  TowingService copyWithDistance({required double distanceKm}) {
    return TowingService(
      id: id,
      name: name,
      phone: phone,
      lat: lat,
      lng: lng,
      serviceRadius: serviceRadius,
      operatingHours: operatingHours,
      vehicleTypes: vehicleTypes,
      distanceKm: distanceKm,
    );
  }

  @override
  List<Object?> get props => [id];
}
