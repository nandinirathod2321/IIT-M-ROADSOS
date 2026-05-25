import 'package:equatable/equatable.dart';

enum LocationStatus { initial, loading, success, failure, denied, deniedForever }

class LocationState extends Equatable {
  final double? latitude;
  final double? longitude;
  final String? city;
  final DateTime? timestamp;
  final LocationStatus status;
  final String errorMessage;

  const LocationState({
    this.latitude,
    this.longitude,
    this.city,
    this.timestamp,
    this.status = LocationStatus.initial,
    this.errorMessage = '',
  });

  bool get hasLocation => latitude != null && longitude != null;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    String? city,
    DateTime? timestamp,
    LocationStatus? status,
    String? errorMessage,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, city, timestamp, status, errorMessage];
}
