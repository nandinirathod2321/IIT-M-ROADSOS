import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/nearby_services_repository.dart';
import '../../data/models/hospital.dart';
import '../../data/models/police_station.dart';
import '../../data/models/towing_service.dart';
import '../../data/models/emergency_shelter.dart';
import '../../presentation/blocs/location/location_cubit.dart';
import '../../presentation/blocs/location/location_state.dart';
import '../utils/distance_utils.dart';
import 'responder_state.dart';

/// Single source of truth for all nearby emergency responder data.
///
/// Provided once at the app root and consumed by both HomeBloc and
/// EmergencyScreen — eliminating duplicate API calls and ensuring
/// consistent state across all screens.
class ResponderCubit extends Cubit<ResponderState> {
  final NearbyServicesRepository _repo;
  final LocationCubit _locationCubit;
  StreamSubscription<LocationState>? _locationSub;

  /// Minimum distance moved (km) before re-fetching responders.
  static const double _refetchRadiusKm = 1.5;
  /// Minimum time between fetches (minutes).
  static const int _throttleMinutes = 10;

  ResponderCubit({
    required LocationCubit locationCubit,
    NearbyServicesRepository? repo,
  })  : _locationCubit = locationCubit,
        _repo = repo ?? NearbyServicesRepository(),
        super(const ResponderState()) {
    _subscribeToLocation();
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Manually retries the fetch using last known coordinates.
  Future<void> retry() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      debugPrint('[AntiGravity] Manual retry triggered.');
      await _fetch(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  /// Forces a hard refresh regardless of throttle / distance gates.
  Future<void> forceRefresh() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      debugPrint('[AntiGravity] Force refresh triggered.');
      await _fetch(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _subscribeToLocation() {
    // Immediately check existing state (avoids missing events emitted before subscribe)
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
    // Throttle gate: skip if we already have data close to this location recently
    if (state.hasData && !_shouldRefetch(lat, lng)) {
      debugPrint('[AntiGravity] Throttled — serving existing data (moved '
          '${_distanceFrom(lat, lng).toStringAsFixed(2)} km, '
          '${_minutesSinceLastFetch()} min ago).');
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

    // Check connectivity
    bool offline = false;
    try {
      final conn = await Connectivity().checkConnectivity();
      offline = conn.contains(ConnectivityResult.none);
    } catch (_) {}

    debugPrint('[AntiGravity] Responder fetch started at ($lat, $lng)');

    debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.loading');
    emit(state.copyWith(
      status: ResponderLoadStatus.loading,
      isOffline: false,
      errorMessage: '',
    ));

    // ── Step 2: Always load from cache (populated from pre-seeded database) ──
    try {
      final hospitals = await _repo.getNearbyHospitals(lat, lng);
      debugPrint('[AntiGravity] Fetched hospital count: ${hospitals.length}');
      final police = await _repo.getNearbyPolice(lat, lng);
      debugPrint('[AntiGravity] Fetched police count: ${police.length}');
      final towing = await _repo.getNearbyTowing(lat, lng);
      debugPrint('[AntiGravity] Fetched towing count: ${towing.length}');
      final shelters = await _repo.getNearbyShelters(lat, lng);
      debugPrint('[AntiGravity] Fetched shelters count: ${shelters.length}');

      final fromCache = true;

      if (isClosed) return;

      if (hospitals.isEmpty && police.isEmpty && towing.isEmpty && shelters.isEmpty) {
        debugPrint('[AntiGravity] Empty responder lists detected at ($lat, $lng)');
        // Cache empty + offline → error state
        if (offline) {
          debugPrint('[AntiGravity] Offline and cache empty — error state.');
          debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.error due to offline & empty cache');
          emit(state.copyWith(
            status: ResponderLoadStatus.error,
            errorMessage: 'No data available. Please connect to the internet to load emergency services.',
            isOffline: true,
          ));
        } else {
          // Online but result empty → auto-retry once with expanded radius
          debugPrint('[AntiGravity] Online but empty result — auto-retrying with expanded radius.');
          debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.retrying');
          emit(state.copyWith(status: ResponderLoadStatus.retrying));
          await _retryWithExpandedRadius(lat, lng);
        }
        return;
      }

      debugPrint('[AntiGravity] Responder fetch success: ${hospitals.length} hospitals, '
          '${police.length} police, ${towing.length} towing, ${shelters.length} shelters.');

      if (!isClosed) {
        debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.loaded');
        emit(state.copyWith(
          status: ResponderLoadStatus.loaded,
          hospitals: hospitals,
          police: police,
          towing: towing,
          shelters: shelters,
          isOffline: offline,
          isFromCache: fromCache,
          errorMessage: '',
          lastFetchedLat: lat,
          lastFetchedLng: lng,
          lastFetchedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('[AntiGravity] Error caught in ResponderCubit: $e');
      debugPrint('[AntiGravity] Cache read failed: $e');
      if (!isClosed) {
        debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.error due to cache read failure');
        emit(state.copyWith(
          status: ResponderLoadStatus.error,
          errorMessage: 'Could not load emergency services: $e',
        ));
      }
    }
  }

  /// Auto-retry with 25km radius when default 10km returns nothing.
  Future<void> _retryWithExpandedRadius(double lat, double lng) async {
    if (isClosed) return;
    try {
      debugPrint('[AntiGravity] Expanded radius search started at ($lat, $lng)');
      await _repo.fetchAndCacheNearbyServices(lat, lng, forceRefresh: true, radiusMeters: 25000);

      final hospitals = await _repo.getNearbyHospitals(lat, lng);
      debugPrint('[AntiGravity] Fetched hospital count (retry): ${hospitals.length}');
      final police = await _repo.getNearbyPolice(lat, lng);
      debugPrint('[AntiGravity] Fetched police count (retry): ${police.length}');
      final towing = await _repo.getNearbyTowing(lat, lng);
      debugPrint('[AntiGravity] Fetched towing count (retry): ${towing.length}');
      final shelters = await _repo.getNearbyShelters(lat, lng);
      debugPrint('[AntiGravity] Fetched shelters count (retry): ${shelters.length}');

      if (!isClosed) {
        if (hospitals.isEmpty && police.isEmpty) {
          debugPrint('[AntiGravity] Empty responder lists detected after expanded radius search.');
          debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.error due to no results inside 25km');
          emit(state.copyWith(
            status: ResponderLoadStatus.error,
            errorMessage: 'No emergency services found within 25km of your location.',
          ));
        } else {
          debugPrint('[AntiGravity] Responder fetch success after expanded search: ${hospitals.length} hospitals, ${police.length} police');
          debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.loaded (retry success)');
          emit(state.copyWith(
            status: ResponderLoadStatus.loaded,
            hospitals: hospitals,
            police: police,
            towing: towing,
            shelters: shelters,
            errorMessage: '',
            lastFetchedLat: lat,
            lastFetchedLng: lng,
            lastFetchedAt: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint('[AntiGravity] Error caught in ResponderCubit (expanded search): $e');
      debugPrint('[AntiGravity] Expanded radius retry failed: $e');
      if (!isClosed) {
        debugPrint('[AntiGravity] State updating: emitting ResponderLoadStatus.error due to expanded search exception');
        emit(state.copyWith(
          status: ResponderLoadStatus.error,
          errorMessage: 'API unavailable. Please try again later.',
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
