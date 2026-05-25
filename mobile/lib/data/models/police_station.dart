import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a police station stored in the `police_stations` SQLite table.
class PoliceStation extends Equatable {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final String districtCode;
  final bool is24Hours;
  final double distanceKm;
  final String city;
  final String state;

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
    this.city = '',
    this.state = '',
  });

  /// Getters for coordinates mapping
  double get latitude => lat;
  double get longitude => lng;

  // ── Serialisation ────────────────────────────────────────────────────

  factory PoliceStation.fromMap(Map<String, dynamic> map) {
    final double resLat = (map['latitude'] as num?)?.toDouble() ?? 
                         (map['lat'] as num?)?.toDouble() ?? 0.0;
    final double resLng = (map['longitude'] as num?)?.toDouble() ?? 
                         (map['lng'] as num?)?.toDouble() ?? 0.0;
    return PoliceStation(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      lat: resLat,
      lng: resLng,
      phone: map['phone'] as String? ?? '',
      districtCode: map['districtCode'] as String? ?? '',
      is24Hours: (map['is24Hours'] as int? ?? 1) == 1 || map['is24Hours'] == true,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
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
      // Extensible helper values
      'districtCode': districtCode,
      'is24Hours': is24Hours ? 1 : 0,
    };
  }

  String toJson() => json.encode(toMap());

  factory PoliceStation.fromJson(String source) => 
      PoliceStation.fromMap(json.decode(source) as Map<String, dynamic>);

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
      city: city,
      state: state,
    );
  }

  PoliceStation copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? phone,
    String? districtCode,
    bool? is24Hours,
    double? distanceKm,
    String? city,
    String? state,
  }) {
    return PoliceStation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      districtCode: districtCode ?? this.districtCode,
      is24Hours: is24Hours ?? this.is24Hours,
      distanceKm: distanceKm ?? this.distanceKm,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }

  @override
  List<Object?> get props => [id, name, address, lat, lng, phone, distanceKm, city, state];
}
