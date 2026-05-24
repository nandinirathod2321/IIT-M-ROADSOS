import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../data/database/database_helper.dart';
import 'home_event.dart';
import 'home_state.dart';

/// BLoC governing Home Screen rescue telemetry, network availability,
/// and automated local spatial queries.
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
    on<HomeDemoModeToggled>(_onDemoModeToggled);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
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

    // 3. Sensor/Location configurations (Default fallback: Ahmedabad center)
    const double ahmedabadLat = 23.0225;
    const double ahmedabadLng = 72.5714;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      add(HomeLocationUpdated(latitude: pos.latitude, longitude: pos.longitude));

      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((pos) {
        add(HomeLocationUpdated(latitude: pos.latitude, longitude: pos.longitude));
      });
    } catch (_) {
      // Fallback location matches Ahmedabad center for Ahmedabad counts seeding
      emit(
        state.copyWith(
          isLoading: false,
          latitude: ahmedabadLat,
          longitude: ahmedabadLng,
          address: 'Ahmedabad (Offline GPS)',
        ),
      );
      await _loadNearbyServices(ahmedabadLat, ahmedabadLng, emit);
    }

    _triggerMeshTransition(connType, state.crashDetectionEnabled);
  }

  Future<void> _onLocationUpdated(
    HomeLocationUpdated event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isDemoMode) return; // ignore updates in demo mode
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
    if (state.isDemoMode) return; // Locked in active state during demo mode

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

  void _onDemoModeToggled(
    HomeDemoModeToggled event,
    Emitter<HomeState> emit,
  ) {
    final nextDemo = !state.isDemoMode;
    _meshTimer?.cancel();

    if (nextDemo) {
      // Ahmedabad demo coordinate lock
      emit(
        state.copyWith(
          isDemoMode: true,
          crashDetectionEnabled: true,
          meshStatus: MeshSOSStatus.active,
          nearbyDevicesCount: 2,
          latitude: 23.0225,
          longitude: 72.5714,
          address: 'Ahmedabad (Demo Mode)',
        ),
      );
      _loadNearbyServices(23.0225, 72.5714, emit);
    } else {
      emit(state.copyWith(isDemoMode: false));
      add(const HomeStarted());
    }
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
