import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/nearby_services_repository.dart';
import '../../presentation/blocs/location/location_cubit.dart';
import '../../presentation/blocs/location/location_state.dart';
import '../utils/distance_utils.dart';
import 'responder_state.dart';

/// Single source of truth for all nearby emergency responder data.
class ResponderCubit extends Cubit<ResponderState> {
  final NearbyServicesRepository _repo;
  final LocationCubit _locationCubit;
  StreamSubscription<LocationState>? _locationSub;
  bool _inFlight = false;

  static const double _refetchRadiusKm = 1.5;
  static const int _throttleMinutes = 10;

  ResponderCubit({
    required LocationCubit locationCubit,
    NearbyServicesRepository? repo,
  })  : _locationCubit = locationCubit,
        _repo = repo ?? NearbyServicesRepository(),
        super(const ResponderState()) {
    _subscribeToLocation();
  }

  Future<void> retry() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      debugPrint('[Responders] Manual retry triggered.');
      await _fetch(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  Future<void> forceRefresh() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      debugPrint('[Responders] Force refresh triggered.');
      await _fetch(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  void _subscribeToLocation() {
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
      debugPrint('[Responders] Throttled — serving existing data');
      return;
    }
    _fetch(lat, lng);
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

  Future<void> _fetch(double lat, double lng, {bool forceRefresh = false}) async {
    if (isClosed) return;
    if (_inFlight) {
      debugPrint('[Responders] Fetch skipped — in flight');
      return;
    }
    _inFlight = true;

    bool offline = false;
    try {
      final conn = await Connectivity().checkConnectivity();
      offline = conn.contains(ConnectivityResult.none);
    } catch (_) {}

    debugPrint('[Responders] Fetch started at ($lat, $lng)');

    // Show cached data immediately while refreshing.
    final cached = await _readCached(lat, lng);
    if (cached.hasData && !forceRefresh) {
      emit(cached.copyWith(
        status: ResponderLoadStatus.loaded,
        isFromCache: true,
        isOffline: offline,
      ));
    } else {
      emit(state.copyWith(
        status: ResponderLoadStatus.loading,
        isOffline: offline,
        errorMessage: '',
      ));
    }

    if (!offline) {
      try {
        await _repo
            .fetchAndCacheNearbyServices(lat, lng, forceRefresh: forceRefresh)
            .timeout(const Duration(seconds: 18));
      } catch (e) {
        debugPrint('[Responders] Live Overpass fetch failed: $e');
        if (!cached.hasData && !state.hasData) {
          await _retryWithExpandedRadius(lat, lng, offline: offline);
          return;
        }
      }
    }

    final fresh = await _readCached(lat, lng);
    if (isClosed) return;

    if (fresh.hasData) {
      debugPrint('[Responders] Loaded ${fresh.hospitals.length} hospitals, '
          '${fresh.police.length} police, ${fresh.towing.length} towing');
      emit(fresh.copyWith(
        status: ResponderLoadStatus.loaded,
        isFromCache: offline,
        isOffline: offline,
        errorMessage: '',
        lastFetchedLat: lat,
        lastFetchedLng: lng,
        lastFetchedAt: DateTime.now(),
      ));
      _inFlight = false;
      return;
    }

    if (offline) {
      emit(state.copyWith(
        status: ResponderLoadStatus.error,
        errorMessage: 'No internet connection. Connect to load nearby emergency services.',
        isOffline: true,
      ));
      _inFlight = false;
      return;
    }

    debugPrint('[Responders] No services found — retrying with expanded radius');
    emit(state.copyWith(status: ResponderLoadStatus.retrying));
    await _retryWithExpandedRadius(lat, lng, offline: offline);
    _inFlight = false;
    return;
  }

  Future<ResponderState> _readCached(double lat, double lng) async {
    try {
      final hospitals = await _repo.getNearbyHospitals(lat, lng);
      final police = await _repo.getNearbyPolice(lat, lng);
      final towing = await _repo.getNearbyTowing(lat, lng);
      final shelters = await _repo.getNearbyShelters(lat, lng);

      return ResponderState(
        hospitals: hospitals,
        police: police,
        towing: towing,
        shelters: shelters,
      );
    } catch (e) {
      debugPrint('[Responders] Cache read failed: $e');
      return const ResponderState();
    }
  }

  Future<void> _retryWithExpandedRadius(double lat, double lng, {required bool offline}) async {
    if (isClosed) return;
    try {
      debugPrint('[Responders] Expanded radius search at ($lat, $lng)');
      if (!offline) {
        await _repo
            .fetchAndCacheNearbyServices(lat, lng, forceRefresh: true, radiusMeters: 25000)
            .timeout(const Duration(seconds: 20));
      }

      final fresh = await _readCached(lat, lng);
      if (isClosed) return;

      if (fresh.hasData) {
        emit(fresh.copyWith(
          status: ResponderLoadStatus.loaded,
          isFromCache: offline,
          isOffline: offline,
          lastFetchedLat: lat,
          lastFetchedLng: lng,
          lastFetchedAt: DateTime.now(),
        ));
      } else {
        emit(state.copyWith(
          status: ResponderLoadStatus.error,
          errorMessage: offline
              ? 'No cached emergency services available offline.'
              : 'No emergency services found within 25 km of your location.',
          isOffline: offline,
        ));
      }
    } catch (e) {
      debugPrint('[Responders] Expanded radius retry failed: $e');
      if (!isClosed) {
        emit(state.copyWith(
          status: ResponderLoadStatus.error,
          errorMessage: 'Could not load emergency services. Please try again.',
          isOffline: offline,
        ));
      }
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
