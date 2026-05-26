import 'package:equatable/equatable.dart';
import '../../data/models/hospital.dart';
import '../../data/models/police_station.dart';
import '../../data/models/towing_service.dart';
import '../../data/models/emergency_shelter.dart';

enum ResponderLoadStatus {
  initial,       // Never fetched
  loading,       // Actively fetching
  loaded,        // Successfully loaded (may be from cache)
  retrying,      // Auto-retry in progress
  error,         // All attempts failed and no cache available
}

class ResponderState extends Equatable {
  final ResponderLoadStatus status;
  final List<Hospital> hospitals;
  final List<PoliceStation> police;
  final List<TowingService> towing;
  final List<EmergencyShelter> shelters;
  final bool isOffline;
  final bool isFromCache;
  final String errorMessage;
  final double? lastFetchedLat;
  final double? lastFetchedLng;
  final DateTime? lastFetchedAt;

  const ResponderState({
    this.status = ResponderLoadStatus.initial,
    this.hospitals = const [],
    this.police = const [],
    this.towing = const [],
    this.shelters = const [],
    this.isOffline = false,
    this.isFromCache = false,
    this.errorMessage = '',
    this.lastFetchedLat,
    this.lastFetchedLng,
    this.lastFetchedAt,
  });

  bool get hasData =>
      hospitals.isNotEmpty || police.isNotEmpty || towing.isNotEmpty || shelters.isNotEmpty;

  bool get isLoading =>
      status == ResponderLoadStatus.loading || status == ResponderLoadStatus.retrying;

  bool get hasFailed => status == ResponderLoadStatus.error;

  ResponderState copyWith({
    ResponderLoadStatus? status,
    List<Hospital>? hospitals,
    List<PoliceStation>? police,
    List<TowingService>? towing,
    List<EmergencyShelter>? shelters,
    bool? isOffline,
    bool? isFromCache,
    String? errorMessage,
    double? lastFetchedLat,
    double? lastFetchedLng,
    DateTime? lastFetchedAt,
  }) {
    return ResponderState(
      status: status ?? this.status,
      hospitals: hospitals ?? this.hospitals,
      police: police ?? this.police,
      towing: towing ?? this.towing,
      shelters: shelters ?? this.shelters,
      isOffline: isOffline ?? this.isOffline,
      isFromCache: isFromCache ?? this.isFromCache,
      errorMessage: errorMessage ?? this.errorMessage,
      lastFetchedLat: lastFetchedLat ?? this.lastFetchedLat,
      lastFetchedLng: lastFetchedLng ?? this.lastFetchedLng,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  @override
  List<Object?> get props => [
        status, hospitals, police, towing, shelters,
        isOffline, isFromCache, errorMessage,
        lastFetchedLat, lastFetchedLng, lastFetchedAt,
      ];
}
