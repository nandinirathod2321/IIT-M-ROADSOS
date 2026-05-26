import 'package:equatable/equatable.dart';
import '../../../data/models/nearby_place.dart';

enum NearbyStatus { initial, loading, success, failure }

class NearbyState extends Equatable {
  final NearbyStatus status;
  final List<NearbyPlace> places;
  final String errorMessage;
  final bool isOffline;
  final bool isFromCache;
  final double? lastFetchedLat;
  final double? lastFetchedLng;
  final DateTime? lastFetchedAt;

  const NearbyState({
    this.status = NearbyStatus.initial,
    this.places = const [],
    this.errorMessage = '',
    this.isOffline = false,
    this.isFromCache = false,
    this.lastFetchedLat,
    this.lastFetchedLng,
    this.lastFetchedAt,
  });

  bool get hasData => places.isNotEmpty;

  List<NearbyPlace> get hospitals => places.where((p) => p.type == NearbyPlaceType.hospital).toList();
  List<NearbyPlace> get police => places.where((p) => p.type == NearbyPlaceType.police).toList();
  List<NearbyPlace> get towing => places.where((p) => p.type == NearbyPlaceType.towing).toList();

  NearbyState copyWith({
    NearbyStatus? status,
    List<NearbyPlace>? places,
    String? errorMessage,
    bool? isOffline,
    bool? isFromCache,
    double? lastFetchedLat,
    double? lastFetchedLng,
    DateTime? lastFetchedAt,
  }) {
    return NearbyState(
      status: status ?? this.status,
      places: places ?? this.places,
      errorMessage: errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
      isFromCache: isFromCache ?? this.isFromCache,
      lastFetchedLat: lastFetchedLat ?? this.lastFetchedLat,
      lastFetchedLng: lastFetchedLng ?? this.lastFetchedLng,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        places,
        errorMessage,
        isOffline,
        isFromCache,
        lastFetchedLat,
        lastFetchedLng,
        lastFetchedAt,
      ];
}
