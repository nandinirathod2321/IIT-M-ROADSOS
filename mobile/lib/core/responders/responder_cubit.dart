import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/nearby_services_repository.dart';
import '../../data/models/hospital.dart';
import '../../data/models/police_station.dart';
import '../../data/models/towing_service.dart';
import '../../data/models/emergency_shelter.dart';
import '../location/location_cubit.dart';
import '../location/location_state.dart';
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
      print('[ResponderCubit] Manual retry triggered.');
      await _fetch(loc.latitude!, loc.longitude!, forceRefresh: true);
    }
  }

  /// Forces a hard refresh regardless of throttle / distance gates.
  Future<void> forceRefresh() async {
    final loc = _locationCubit.state;
    if (loc.hasLocation) {
      print('[ResponderCubit] Force refresh triggered.');
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
      print('[ResponderCubit] Throttled — serving existing data (moved '
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

    print('[ResponderCubit] Fetching responders at ($lat, $lng) exclusively from SQLite cache.');

    emit(state.copyWith(
      status: ResponderLoadStatus.loading,
      isOffline: false,
      errorMessage: '',
    ));

    // ── Step 2: Always load from cache (populated from pre-seeded database) ──
    try {
      final hospitals = await _repo.getNearbyHospitals(lat, lng);
      final police = await _repo.getNearbyPolice(lat, lng);
      final towing = await _repo.getNearbyTowing(lat, lng);
      final shelters = await _repo.getNearbyShelters(lat, lng);

      final fromCache = true;

      if (isClosed) return;

      if (hospitals.isEmpty && police.isEmpty && towing.isEmpty && shelters.isEmpty) {
        // Cache empty + offline → error state
        if (offline) {
          print('[ResponderCubit] Offline and cache empty — error state.');
          emit(state.copyWith(
            status: ResponderLoadStatus.error,
            errorMessage: 'No data available. Please connect to the internet to load emergency services.',
            isOffline: true,
          ));
        } else {
          // Online but result empty → auto-retry once with expanded radius
          print('[ResponderCubit] Online but empty result — auto-retrying with expanded radius.');
          emit(state.copyWith(status: ResponderLoadStatus.retrying));
          await _retryWithExpandedRadius(lat, lng);
        }
        return;
      }

      print('[ResponderCubit] Loaded: ${hospitals.length} hospitals, '
          '${police.length} police, ${towing.length} towing, ${shelters.length} shelters '
          '(cache=$fromCache).');

      if (!isClosed) {
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
      print('[ResponderCubit] Cache read failed: $e');
      if (!isClosed) {
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
      await _repo.fetchAndCacheNearbyServices(lat, lng, forceRefresh: true, radiusMeters: 25000);

      final hospitals = await _repo.getNearbyHospitals(lat, lng);
      final police = await _repo.getNearbyPolice(lat, lng);
      final towing = await _repo.getNearbyTowing(lat, lng);
      final shelters = await _repo.getNearbyShelters(lat, lng);

      if (!isClosed) {
        if (hospitals.isEmpty && police.isEmpty) {
          emit(state.copyWith(
            status: ResponderLoadStatus.error,
            errorMessage: 'No emergency services found within 25km of your location.',
          ));
        } else {
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
      print('[ResponderCubit] Expanded radius retry failed: $e');
      if (!isClosed) {
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
