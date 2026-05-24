import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../data/database/database_helper.dart';
import 'home_event.dart';
import 'home_state.dart';

/// BLoC governing Home Screen rescue telemetry, real location updates,
/// network availability, and automated local spatial queries.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DatabaseHelper _db;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _meshTimer;

  HomeBloc({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper(),
        super(HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<HomeLocationUpdated>(_onLocationUpdated);
    on<HomeCrashDetectionToggled>(_onCrashDetectionToggled);
    on<HomeConnectivityChanged>(_onConnectivityChanged);
    on<HomeMeshStatusUpdated>(_onMeshStatusUpdated);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true, hasLocationError: false));

    // 1. Initialise local database
    await _db.initialize();

    // 2. Connectivity streams
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final type = _mapConnectivity(results);
      add(HomeConnectivityChanged(type));
    });

    final connResults = await Connectivity().checkConnectivity();
    final connType = _mapConnectivity(connResults);
    emit(state.copyWith(connectivity: connType));

    // 3. Real Location Services & Permissions (Web, macOS, iOS, Android support)
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(
          state.copyWith(
            isLoading: false,
            hasLocationError: true,
            locationErrorMessage: 'Location services are disabled on your device.',
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(
            state.copyWith(
              isLoading: false,
              hasLocationError: true,
              locationErrorMessage: 'Location permissions are denied.',
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(
          state.copyWith(
            isLoading: false,
            hasLocationError: true,
            locationErrorMessage: 'Location permissions are permanently denied. Please enable them in system settings.',
          ),
        );
        return;
      }

      // Success: Resolve the primary location
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      add(HomeLocationUpdated(latitude: pos.latitude, longitude: pos.longitude));

      // 4. Register continuous location stream listeners
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        add(HomeLocationUpdated(latitude: pos.latitude, longitude: pos.longitude));
      }, onError: (err) {
        // Suppress stream glitches
      });

    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          hasLocationError: true,
          locationErrorMessage: 'GPS access failed: ${e.toString()}',
        ),
      );
    }

    _triggerMeshTransition(connType, state.crashDetectionEnabled);
  }

  Future<void> _onLocationUpdated(
    HomeLocationUpdated event,
    Emitter<HomeState> emit,
  ) async {
    emit(
      state.copyWith(
        latitude: event.latitude,
        longitude: event.longitude,
        hasLocationError: false,
      ),
    );
    final String address = await _reverseGeocode(event.latitude, event.longitude);
    emit(state.copyWith(address: address));
    await _loadNearbyServices(event.latitude, event.longitude, emit);
  }

  /// OSM Nominatim Reverse Geocoding with HttpClient timeout
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final request = await client.getUrl(uri);
      request.headers.setUserAgent('RoadSOS/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        return data['display_name'] ?? 'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }
    } catch (_) {
      // Graceful offline fallback
    }
    return 'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _loadNearbyServices(
    double lat,
    double lng,
    Emitter<HomeState> emit,
  ) async {
    try {
      final hospitals = await _db.getNearbyHospitals(lat, lng);
      final police = await _db.getNearbyPolice(lat, lng);
      final towing = await _db.getNearbyTowing(lat, lng);
      final contacts = await _db.getEmergencyContacts();

      final nearest = hospitals.isNotEmpty ? hospitals.first : null;

      emit(
        state.copyWith(
          isLoading: false,
          nearbyHospitalCount: hospitals.length,
          nearbyPoliceCount: police.length,
          nearbyTowingCount: towing.length,
          contactsCount: contacts.length,
          nearestHospital: nearest,
          clearHospital: nearest == null,
          lastDbSync: DateTime.now(),
        ),
      );
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onCrashDetectionToggled(
    HomeCrashDetectionToggled event,
    Emitter<HomeState> emit,
  ) {
    final nextEnabled = !state.crashDetectionEnabled;
    emit(
      state.copyWith(
        crashDetectionEnabled: nextEnabled,
        meshStatus: nextEnabled ? MeshSOSStatus.connecting : MeshSOSStatus.disabled,
        nearbyDevicesCount: 0,
      ),
    );

    _triggerMeshTransition(state.connectivity, nextEnabled);
  }

  void _onConnectivityChanged(
    HomeConnectivityChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(connectivity: event.type));
    _triggerMeshTransition(event.type, state.crashDetectionEnabled);
  }

  void _onMeshStatusUpdated(
    HomeMeshStatusUpdated event,
    Emitter<HomeState> emit,
  ) {
    emit(
      state.copyWith(
        meshStatus: event.status,
        nearbyDevicesCount: event.nearbyDevicesCount,
      ),
    );
  }

  /// Triggers a 2-second transition state for Mesh SOS.
  void _triggerMeshTransition(ConnectivityType conn, bool isCrashEnabled) {
    _meshTimer?.cancel();
    if (!isCrashEnabled) return;

    // Shift to CONNECTING status
    add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 0));

    _meshTimer = Timer(const Duration(seconds: 2), () {
      if (state.crashDetectionEnabled) {
        if (conn == ConnectivityType.offline) {
          add(const HomeMeshStatusUpdated(MeshSOSStatus.offline, 0));
        } else {
          final int randomPeers = Random().nextInt(4); // 0 to 3
          add(HomeMeshStatusUpdated(MeshSOSStatus.active, randomPeers));
        }
      }
    });
  }

  ConnectivityType _mapConnectivity(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return ConnectivityType.wifi;
    if (results.contains(ConnectivityResult.mobile)) return ConnectivityType.mobile;
    return ConnectivityType.offline;
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _connectivitySub?.cancel();
    _meshTimer?.cancel();
    return super.close();
  }
}
