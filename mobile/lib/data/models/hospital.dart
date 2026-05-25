import 'dart:convert';
import 'package:equatable/equatable.dart';

/// The type of medical facility.
enum HospitalType {
  trauma,
  general,
  clinic;

  static HospitalType fromString(String value) {
    return HospitalType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HospitalType.general,
    );
  }
}

/// Represents a hospital / medical facility stored in the `hospitals` SQLite table.
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
  final double distanceKm;
  final double estimatedMinutes;
  final DateTime lastUpdated;
  final String sourceApi;
  final double rating;
  final String city;
  final String state;

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
    this.city = '',
    this.state = '',
  });

  /// Getters for coordinates mapping
  double get latitude => lat;
  double get longitude => lng;

  // ── Serialisation ────────────────────────────────────────────────────

  factory Hospital.fromMap(Map<String, dynamic> map) {
    final double resLat = (map['latitude'] as num?)?.toDouble() ?? 
                         (map['lat'] as num?)?.toDouble() ?? 0.0;
    final double resLng = (map['longitude'] as num?)?.toDouble() ?? 
                         (map['lng'] as num?)?.toDouble() ?? 0.0;
    return Hospital(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      lat: resLat,
      lng: resLng,
      phone: map['phone'] as String? ?? '',
      type: HospitalType.fromString(map['type'] as String? ?? 'general'),
      hasEmergency: (map['hasEmergency'] as int? ?? 0) == 1 || map['hasEmergency'] == true,
      hasICU: (map['hasICU'] as int? ?? 0) == 1 || map['hasICU'] == true,
      hasBloodBank: (map['hasBloodBank'] as int? ?? 0) == 1 || map['hasBloodBank'] == true,
      ambulanceCount: map['ambulanceCount'] as int? ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'] as String)
          : DateTime.now(),
      sourceApi: map['sourceApi'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'address': address,
      'phone': phone,
      'city': city,
      'state': state,
      // Extensible SQLite helper values
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

  String toJson() => json.encode(toMap());

  factory Hospital.fromJson(String source) => 
      Hospital.fromMap(json.decode(source) as Map<String, dynamic>);

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
      city: city,
      state: state,
    );
  }

  Hospital copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? phone,
    HospitalType? type,
    bool? hasEmergency,
    bool? hasICU,
    bool? hasBloodBank,
    int? ambulanceCount,
    double? distanceKm,
    double? estimatedMinutes,
    DateTime? lastUpdated,
    String? sourceApi,
    double? rating,
    String? city,
    String? state,
  }) {
    return Hospital(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      hasEmergency: hasEmergency ?? this.hasEmergency,
      hasICU: hasICU ?? this.hasICU,
      hasBloodBank: hasBloodBank ?? this.hasBloodBank,
      ambulanceCount: ambulanceCount ?? this.ambulanceCount,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sourceApi: sourceApi ?? this.sourceApi,
      rating: rating ?? this.rating,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }

  @override
  List<Object?> get props => [id, name, address, lat, lng, phone, type, distanceKm, city, state];
}
