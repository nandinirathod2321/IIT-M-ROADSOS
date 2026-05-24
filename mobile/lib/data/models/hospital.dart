import 'package:equatable/equatable.dart';

/// The type of medical facility.
enum HospitalType {
  trauma,
  general,
  clinic;

  /// Parses a stored string back to an enum value.
  static HospitalType fromString(String value) {
    return HospitalType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HospitalType.general,
    );
  }
}

/// Represents a hospital / medical facility fetched from the local
/// database or a remote API.
///
/// [distanceKm] and [estimatedMinutes] are **computed** at query time
/// based on the user's current location and are not persisted.
class Hospital extends Equatable {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final HospitalType type;
  final bool hasEmergency;
  final bool hasICU;
  final bool hasBloodBank;
  final int ambulanceCount;

  /// Computed — straight-line distance from the user's position (km).
  final double distanceKm;

  /// Computed — estimated travel time in minutes.
  final double estimatedMinutes;

  final DateTime lastUpdated;
  final String sourceApi;
  final double rating;

  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    this.type = HospitalType.general,
    this.hasEmergency = false,
    this.hasICU = false,
    this.hasBloodBank = false,
    this.ambulanceCount = 0,
    this.distanceKm = 0.0,
    this.estimatedMinutes = 0.0,
    required this.lastUpdated,
    this.sourceApi = '',
    this.rating = 0.0,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  /// Creates a [Hospital] from a database row / JSON map.
  factory Hospital.fromMap(Map<String, dynamic> map) {
    return Hospital(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      phone: map['phone'] as String? ?? '',
      type: HospitalType.fromString(map['type'] as String? ?? 'general'),
      hasEmergency: (map['hasEmergency'] as int? ?? 0) == 1,
      hasICU: (map['hasICU'] as int? ?? 0) == 1,
      hasBloodBank: (map['hasBloodBank'] as int? ?? 0) == 1,
      ambulanceCount: map['ambulanceCount'] as int? ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'] as String)
          : DateTime.now(),
      sourceApi: map['sourceApi'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
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
      'type': type.name,
      'hasEmergency': hasEmergency ? 1 : 0,
      'hasICU': hasICU ? 1 : 0,
      'hasBloodBank': hasBloodBank ? 1 : 0,
      'ambulanceCount': ambulanceCount,
      'lastUpdated': lastUpdated.toIso8601String(),
      'sourceApi': sourceApi,
      'rating': rating,
    };
  }

  /// Returns a copy with the computed distance fields populated.
  Hospital copyWithDistance({
    required double distanceKm,
    required double estimatedMinutes,
  }) {
    return Hospital(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      type: type,
      hasEmergency: hasEmergency,
      hasICU: hasICU,
      hasBloodBank: hasBloodBank,
      ambulanceCount: ambulanceCount,
      distanceKm: distanceKm,
      estimatedMinutes: estimatedMinutes,
      lastUpdated: lastUpdated,
      sourceApi: sourceApi,
      rating: rating,
    );
  }

  @override
  List<Object?> get props => [id];
}
