import 'package:equatable/equatable.dart';

/// Represents an emergency shelter / safety zone fetched from the local
/// database or a remote API.
class EmergencyShelter extends Equatable {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final int capacity;

  /// Computed — straight-line distance from the user's position (km).
  final double distanceKm;

  const EmergencyShelter({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    this.capacity = 0,
    this.distanceKm = 0.0,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates an [EmergencyShelter] from a database row / JSON map.
  factory EmergencyShelter.fromMap(Map<String, dynamic> map) {
    return EmergencyShelter(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      phone: map['phone'] as String? ?? '',
      capacity: map['capacity'] as int? ?? 0,
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
      'capacity': capacity,
    };
  }

  /// Returns a copy with the computed distance fields populated.
  EmergencyShelter copyWithDistance({
    required double distanceKm,
  }) {
    return EmergencyShelter(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      capacity: capacity,
      distanceKm: distanceKm,
    );
  }

  @override
  List<Object?> get props => [id];
}
