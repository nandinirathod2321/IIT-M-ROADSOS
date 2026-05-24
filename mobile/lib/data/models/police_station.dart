import 'package:equatable/equatable.dart';

/// Represents a police station stored in the local database.
///
/// [distanceKm] is computed at query time based on the user's current
/// location and is not persisted to the database.
class PoliceStation extends Equatable {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final String districtCode;
  final bool is24Hours;

  /// Computed — straight-line distance from the user's position (km).
  final double distanceKm;

  const PoliceStation({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    this.districtCode = '',
    this.is24Hours = true,
    this.distanceKm = 0.0,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates a [PoliceStation] from a database row / JSON map.
  factory PoliceStation.fromMap(Map<String, dynamic> map) {
    return PoliceStation(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      phone: map['phone'] as String? ?? '',
      districtCode: map['districtCode'] as String? ?? '',
      is24Hours: (map['is24Hours'] as int? ?? 1) == 1,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'districtCode': districtCode,
      'is24Hours': is24Hours ? 1 : 0,
    };
  }

  /// Returns a copy with the computed distance field populated.
  PoliceStation copyWithDistance({required double distanceKm}) {
    return PoliceStation(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      districtCode: districtCode,
      is24Hours: is24Hours,
      distanceKm: distanceKm,
    );
  }

  @override
  List<Object?> get props => [id];
}
