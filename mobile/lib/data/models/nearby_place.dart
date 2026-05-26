import 'package:equatable/equatable.dart';

enum NearbyPlaceType { hospital, police, towing }

class NearbyPlace extends Equatable {
  final String id;
  final String name;
  final NearbyPlaceType type;
  final double latitude;
  final double longitude;
  final String address;
  final double distanceKm;
  final String? phone;
  final bool isOperating;

  const NearbyPlace({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distanceKm,
    this.phone,
    this.isOperating = true,
  });

  NearbyPlace copyWith({
    String? id,
    String? name,
    NearbyPlaceType? type,
    double? latitude,
    double? longitude,
    String? address,
    double? distanceKm,
    String? phone,
    bool? isOperating,
  }) {
    return NearbyPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      phone: phone ?? this.phone,
      isOperating: isOperating ?? this.isOperating,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        latitude,
        longitude,
        address,
        distanceKm,
        phone,
        isOperating,
      ];
}
