import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/geocoder.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  StreamSubscription<Position>? _positionSub;

  LocationCubit() : super(const LocationState()) {
    // Instantly load cached coordinates on boot to prevent blank/error states
    loadFromCache();
  }

  /// Instantly loads the last successfully resolved GPS location from SharedPreferences.
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final double? cachedLat = prefs.getDouble('cached_lat');
      final double? cachedLng = prefs.getDouble('cached_lng');
      final String? cachedCity = prefs.getString('cached_city');

      if (cachedLat != null && cachedLng != null) {
        print("[LocationCubit] GPS loaded from cache: $cachedLat, $cachedLng (${cachedCity ?? 'Unknown'})");
        emit(state.copyWith(
          latitude: cachedLat,
          longitude: cachedLng,
          city: cachedCity ?? 'Local',
          status: LocationStatus.success,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      print("[LocationCubit] Failed to load cached location: $e");
    }
  }

  /// Entry point to initialize global GPS and request permissions.
  /// Fetches the location exactly once during startup.
  /// Safe to call multiple times — ignores if already loading or resolved.
  Future<void> initLocation() async {
    // If already loading, skip (another init in progress)
    if (state.status == LocationStatus.loading) return;

    // Load from cache first if we don't have location yet
    if (!state.hasLocation) {
      await loadFromCache();
    }

    // If we have a cached location, we can resolve fresh GPS in the background
    // without blocking the user interface on startup.
    if (state.hasLocation) {
      print('[LocationCubit] GPS cached location found — resolving fresh GPS in background.');
      _resolvePositionInBackground();
      _startLocationStream();
      return;
    }

    emit(state.copyWith(status: LocationStatus.loading));

    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        // Platform fallback
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        emit(state.copyWith(
          status: LocationStatus.failure,
          errorMessage: 'Location services are disabled on your device.',
        ));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(state.copyWith(
            status: LocationStatus.denied,
            errorMessage: 'Location permissions are denied.',
          ));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(state.copyWith(
          status: LocationStatus.deniedForever,
          errorMessage: 'Location permissions are permanently denied. Please enable them in your settings.',
        ));
        return;
      }

      // Permissions cleared. Resolve location.
      await _resolvePosition();

      // Register location update stream for minor movements
      _startLocationStream();

    } catch (e) {
      print("[LocationCubit] Location initialization error: $e");
      emit(state.copyWith(
        status: state.hasLocation ? LocationStatus.success : LocationStatus.failure,
        errorMessage: 'GPS initialization failed: $e',
      ));
    }
  }

  /// Resolves fresh GPS position in the background without modifying loading status.
  Future<void> _resolvePositionInBackground() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true;
      }
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      await _resolvePosition();
    } catch (e) {
      print("[LocationCubit] Background GPS resolve failed: $e");
    }
  }

  /// Forces a fresh location fetch (e.g. when the user taps refresh manually).
  Future<void> forceRefreshLocation() async {
    emit(state.copyWith(status: LocationStatus.loading));
    await _resolvePosition();
  }

  /// Platform-safe position resolution.
  Future<void> _resolvePosition() async {
    Position? pos;
    final int timeoutSecs = kIsWeb ? 8 : 5;

    try {
      if (kIsWeb) {
        // Flutter Web: ALWAYS use getCurrentPosition with timeouts. NEVER use getLastKnownPosition.
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: timeoutSecs),
        );
      } else {
        // Native: try high accuracy, fallback to low accuracy or last known position
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (_) {
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 3),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
        }
      }

      if (pos != null) {
        await updateLocation(pos.latitude, pos.longitude);
      } else {
        if (!state.hasLocation) {
          throw Exception("Could not resolve location coordinates.");
        } else {
          // If we fail to resolve but have a cached position, maintain success using cached
          print("[LocationCubit] Failed to re-resolve GPS. Retaining cached state.");
          emit(state.copyWith(status: LocationStatus.success));
        }
      }

    } catch (e) {
      print("[LocationCubit] GPS fetch failed: $e");
      if (state.hasLocation) {
        // Graceful failover: maintain cached position
        emit(state.copyWith(status: LocationStatus.success));
      } else {
        emit(state.copyWith(
          status: LocationStatus.failure,
          errorMessage: 'Failed to acquire GPS position: $e',
        ));
      }
    }
  }

  /// Updates state and caches coordinates in SharedPreferences.
  Future<void> updateLocation(double lat, double lng) async {
    String city = 'Local';
    try {
      city = await performReverseGeocode(lat, lng);
    } catch (e) {
      print("[LocationCubit] Geocoding error: $e");
      city = state.city ?? 'Local';
    }

    print("[LocationCubit] GPS resolved successfully: $lat, $lng ($city)");
    
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

  /// Subscribes to geolocator location updates for slight movement trackers.
  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      print("[LocationCubit] GPS updated via stream: ${pos.latitude}, ${pos.longitude}");
      updateLocation(pos.latitude, pos.longitude);
    }, onError: (err) {
      print("[LocationCubit] GPS stream error: $err");
    });
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    return super.close();
  }
}
