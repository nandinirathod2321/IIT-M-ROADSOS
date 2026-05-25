import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a roadside towing / vehicle recovery service stored in `towing_services` table.
class TowingService extends Equatable {
  final String id;
  final String name;
  final String phone;
  final double lat;
  final double lng;
  final double serviceRadius;
  final String operatingHours;
  final List<String> vehicleTypes;
  final double distanceKm;
  final String address;
  final String city;
  final String state;

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
    this.address = '',
    this.city = '',
    this.state = '',
  });

  /// Getters for coordinates mapping
  double get latitude => lat;
  double get longitude => lng;

  // ── Serialisation ────────────────────────────────────────────────────

  factory TowingService.fromMap(Map<String, dynamic> map) {
    final double resLat = (map['latitude'] as num?)?.toDouble() ?? 
                         (map['lat'] as num?)?.toDouble() ?? 0.0;
    final double resLng = (map['longitude'] as num?)?.toDouble() ?? 
                         (map['lng'] as num?)?.toDouble() ?? 0.0;
    return TowingService(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      lat: resLat,
      lng: resLng,
      serviceRadius: (map['serviceRadius'] as num?)?.toDouble() ?? 0.0,
      operatingHours: map['operatingHours'] as String? ?? '',
      vehicleTypes: map['vehicleTypes'] != null
          ? (map['vehicleTypes'] as String).split(',')
          : const [],
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
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
      'serviceRadius': serviceRadius,
      'operatingHours': operatingHours,
      'vehicleTypes': vehicleTypes.join(','),
    };
  }

  String toJson() => json.encode(toMap());

  factory TowingService.fromJson(String source) => 
      TowingService.fromMap(json.decode(source) as Map<String, dynamic>);

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
      address: address,
      city: city,
      state: state,
    );
  }

  TowingService copyWith({
    String? id,
    String? name,
    String? phone,
    double? lat,
    double? lng,
    double? serviceRadius,
    String? operatingHours,
    List<String>? vehicleTypes,
    double? distanceKm,
    String? address,
    String? city,
    String? state,
  }) {
    return TowingService(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      serviceRadius: serviceRadius ?? this.serviceRadius,
      operatingHours: operatingHours ?? this.operatingHours,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      distanceKm: distanceKm ?? this.distanceKm,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, lat, lng, distanceKm, city, state];
}
