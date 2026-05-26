import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../location/location_cubit.dart';
import '../location/location_state.dart';
import '../../../data/repositories/nearby_repository.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/distance_utils.dart';
import 'nearby_state.dart';

class NearbyCubit extends Cubit<NearbyState> {
  final NearbyRepository _repository;
  final LocationCubit _locationCubit;
  StreamSubscription<LocationState>? _locationSub;

  /// Minimum distance moved (km) before automatically refetching responders.
  static const double _refetchRadiusKm = 1.5;
  /// Minimum time between automatic fetches (minutes).
  static const int _throttleMinutes = 10;

  NearbyCubit({
    required LocationCubit locationCubit,
    NearbyRepository? repository,
  })  : _locationCubit = locationCubit,
        _repository = repository ?? NearbyRepository(),
        super(const NearbyState()) {
    _subscribeToLocation();
  }

  void _subscribeToLocation() {
    // Immediately check if location is already resolved
    final locState = _locationCubit.state;
    if (locState.hasLocation) {
      _onLocationAvailable(locState.latitude!, locState.longitude!);
    }

    _locationSub = _locationCubit.stream.listen((locState) {
      if (locState.hasLocation) {
        _onLocationAvailable(locState.latitude!, locState.longitude!);
      }
    });
  }

  void _onLocationAvailable(double lat, double lng) {
    if (state.hasData && !_shouldRefetch(lat, lng)) {
      AppLogger.info('NearbyCubit: Throttling auto-refresh (moved '
          '${_distanceFrom(lat, lng).toStringAsFixed(2)} km, '
          '${_minutesSinceLastFetch()} mins ago).');
      return;
    }
    fetchResponders(lat, lng);
  }

  bool _shouldRefetch(double lat, double lng) {
    if (state.lastFetchedLat == null || state.lastFetchedLng == null) return true;
    final movedKm = _distanceFrom(lat, lng);
    final elapsedMin = _minutesSinceLastFetch();
    return movedKm >= _refetchRadiusKm || elapsedMin >= _throttleMinutes;
  }

  double _distanceFrom(double lat, double lng) {
    if (state.lastFetchedLat == null || state.lastFetchedLng == null) return double.infinity;
    return DistanceUtils.haversine(lat, lng, state.lastFetchedLat!, state.lastFetchedLng!);
  }

  int _minutesSinceLastFetch() {
    if (state.lastFetchedAt == null) return 9999;
    return DateTime.now().difference(state.lastFetchedAt!).inMinutes;
  }

  /// Manually triggers a reload using the current coordinates.
  Future<void> retry() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      AppLogger.info('NearbyCubit: Manual retry triggered.');
      await fetchResponders(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  /// Forces a complete bypass of throttling rules.
  Future<void> forceRefresh() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      AppLogger.info('NearbyCubit: Force refresh triggered.');
      await fetchResponders(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  /// Main action to fetch places from repository.
  Future<void> fetchResponders(double lat, double lng, {bool forceRefresh = false}) async {
    if (isClosed) return;

    emit(state.copyWith(status: NearbyStatus.loading, errorMessage: ''));

    // Check connectivity
    bool isOffline = false;
    try {
      final conn = await Connectivity().checkConnectivity();
      isOffline = conn.contains(ConnectivityResult.none);
    } catch (_) {}

    try {
      final places = await _repository.getNearbyPlaces(lat, lng, forceRefresh: forceRefresh);
      
      if (isClosed) return;

      if (places.isEmpty) {
        emit(state.copyWith(
          status: NearbyStatus.failure,
          isOffline: isOffline,
          errorMessage: 'No emergency services could be located nearby. Please try again.',
        ));
      } else {
        emit(state.copyWith(
          status: NearbyStatus.success,
          places: places,
          isOffline: isOffline,
          lastFetchedLat: lat,
          lastFetchedLng: lng,
          lastFetchedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLogger.error('NearbyCubit: Failed to fetch responders', e);
      if (!isClosed) {
        emit(state.copyWith(
          status: NearbyStatus.failure,
          isOffline: isOffline,
          errorMessage: 'Failed to retrieve emergency services: $e',
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
