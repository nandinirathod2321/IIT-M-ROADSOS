import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../data/database/database_helper.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DatabaseHelper _db;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  HomeBloc({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper(),
      super(HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<HomeLocationUpdated>(_onLocationUpdated);
    on<HomeCrashDetectionToggled>(_onCrashDetectionToggled);
    on<HomeConnectivityChanged>(_onConnectivityChanged);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    // Check connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final type = _mapConnectivity(results);
      add(HomeConnectivityChanged(type));
    });

    final connResults = await Connectivity().checkConnectivity();
    final connType = _mapConnectivity(connResults);
    emit(state.copyWith(connectivity: connType));

    // Try to get location
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      add(
        HomeLocationUpdated(latitude: pos.latitude, longitude: pos.longitude),
      );

      // Listen for location changes
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((pos) {
            add(
              HomeLocationUpdated(
                latitude: pos.latitude,
                longitude: pos.longitude,
              ),
            );
          });
    } catch (_) {
      // Fallback — use default coordinates (New Delhi)
      emit(
        state.copyWith(
          isLoading: false,
          latitude: 28.6139,
          longitude: 77.2090,
          address: 'Location unavailable',
        ),
      );
      await _loadNearbyServices(28.6139, 77.2090, emit);
    }
  }

  Future<void> _onLocationUpdated(
    HomeLocationUpdated event,
    Emitter<HomeState> emit,
  ) async {
    emit(
      state.copyWith(
        latitude: event.latitude,
        longitude: event.longitude,
        address: 'Current Location',
      ),
    );
    await _loadNearbyServices(event.latitude, event.longitude, emit);
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
    emit(
      state.copyWith(
        crashDetectionEnabled: !state.crashDetectionEnabled,
        meshStatus: !state.crashDetectionEnabled
            ? MeshSOSStatus.searching
            : MeshSOSStatus.disabled,
      ),
    );
  }

  void _onConnectivityChanged(
    HomeConnectivityChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(connectivity: event.type));
  }

  ConnectivityType _mapConnectivity(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return ConnectivityType.wifi;
    if (results.contains(ConnectivityResult.mobile))
      return ConnectivityType.mobile;
    return ConnectivityType.offline;
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }
}
