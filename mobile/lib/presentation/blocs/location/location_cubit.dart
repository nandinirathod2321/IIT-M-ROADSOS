import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/geocoder.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationService _locationService;
  final CacheService _cacheService;
  StreamSubscription<Position>? _positionSub;

  LocationCubit({
    LocationService? locationService,
    CacheService? cacheService,
  })  : _locationService = locationService ?? LocationService(),
        _cacheService = cacheService ?? CacheService(),
        super(const LocationState()) {
    // Instantly load cached coordinates on boot to prevent blank/error states
    loadFromCache();
  }

  /// Instantly loads the last successfully resolved GPS location from SharedPreferences.
  Future<void> loadFromCache() async {
    AppLogger.info('LocationCubit: Loading coordinates from persistent storage cache...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final double? cachedLat = prefs.getDouble('cached_lat');
      final double? cachedLng = prefs.getDouble('cached_lng');
      final String? cachedCity = prefs.getString('cached_city');

      if (cachedLat != null && cachedLng != null) {
        final city = cachedCity ?? 'Local';
        AppLogger.info('LocationCubit: GPS loaded from persistent storage: $cachedLat, $cachedLng ($city)');
        
        // Populate in-memory cache service
        _cacheService.setCoordinates(cachedLat, cachedLng, city);

        emit(state.copyWith(
          latitude: cachedLat,
          longitude: cachedLng,
          city: city,
          status: LocationStatus.success,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLogger.warning('LocationCubit: Failed to load cached location from SharedPreferences: $e');
    }
  }

  /// Entry point to initialize global GPS and request permissions.
  /// Fetches the location exactly once during startup.
  Future<void> initLocation() async {
    if (state.status == LocationStatus.loading) return;

    // Load from cache first if we don't have location yet
    if (!state.hasLocation) {
      await loadFromCache();
    }

    // If we have a cached location, we can resolve fresh GPS in the background
    // without blocking the user interface on startup.
    if (state.hasLocation) {
      AppLogger.info('LocationCubit: GPS cached location found — resolving fresh GPS in background.');
      _resolvePositionInBackground();
      _startLocationStream();
      return;
    }

    emit(state.copyWith(status: LocationStatus.loading));

    try {
      final pos = await _locationService.getCurrentLocation();
      await updateLocation(pos.latitude, pos.longitude);
      _startLocationStream();
    } catch (e) {
      AppLogger.error('LocationCubit: GPS initialization error', e);
      if (state.hasLocation) {
        emit(state.copyWith(status: LocationStatus.success));
      } else {
        emit(state.copyWith(
          status: LocationStatus.failure,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  /// Resolves fresh GPS position in the background.
  Future<void> _resolvePositionInBackground() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      await updateLocation(pos.latitude, pos.longitude);
    } catch (e) {
      AppLogger.warning('LocationCubit: Background GPS resolve failed: $e');
    }
  }

  /// Forces a fresh location fetch (e.g. when the user taps refresh manually).
  Future<void> forceRefreshLocation() async {
    emit(state.copyWith(status: LocationStatus.loading));
    try {
      final pos = await _locationService.getCurrentLocation();
      await updateLocation(pos.latitude, pos.longitude);
    } catch (e) {
      AppLogger.error('LocationCubit: Force refresh failed', e);
      emit(state.copyWith(
        status: state.hasLocation ? LocationStatus.success : LocationStatus.failure,
        errorMessage: 'Failed to acquire location: $e',
      ));
    }
  }

  /// Updates state and caches coordinates in SharedPreferences & InMemory CacheService.
  Future<void> updateLocation(double lat, double lng) async {
    String city = 'Local';
    try {
      city = await performReverseGeocode(lat, lng);
    } catch (e) {
      AppLogger.warning('LocationCubit: Geocoding error: $e');
      city = state.city ?? 'Local';
    }

    AppLogger.info('LocationCubit: GPS resolved successfully: $lat, $lng ($city)');
    
    // Save to in-memory CacheService
    _cacheService.setCoordinates(lat, lng, city);

    // Save to SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cached_lat', lat);
      await prefs.setDouble('cached_lng', lng);
      await prefs.setString('cached_city', city);
    } catch (_) {}

    emit(state.copyWith(
      latitude: lat,
      longitude: lng,
      city: city,
      status: LocationStatus.success,
      timestamp: DateTime.now(),
    ));
  }

  /// Subscribes to geolocator location updates for minor movements.
  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = _locationService.getLocationStream().listen(
      (pos) {
        AppLogger.info('LocationCubit: GPS stream update: ${pos.latitude}, ${pos.longitude}');
        updateLocation(pos.latitude, pos.longitude);
      },
      onError: (err) {
        AppLogger.warning('LocationCubit: GPS stream error: $err');
      },
    );
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    return super.close();
  }
}
