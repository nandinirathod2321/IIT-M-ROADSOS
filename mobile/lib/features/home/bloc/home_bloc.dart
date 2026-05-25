import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../core/utils/geocoder.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../data/database/database_helper.dart';
import '../../../data/repositories/nearby_services_repository.dart';
import '../../../data/repositories/emergency_contact_repository.dart';
import '../../../core/location/location_cubit.dart';
import '../../../core/location/location_state.dart';
import 'home_event.dart';
import 'home_state.dart';

/// BLoC governing Home Screen rescue telemetry, real location updates,
/// network availability, and automated local spatial queries.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DatabaseHelper _db;
  final NearbyServicesRepository _servicesRepo;
  final EmergencyContactRepository _contactsRepo;
  final LocationCubit _locationCubit;
  
  StreamSubscription<LocationState>? _locationSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _meshTimer;

  HomeBloc({
    DatabaseHelper? db,
    NearbyServicesRepository? servicesRepo,
    EmergencyContactRepository? contactsRepo,
    required LocationCubit locationCubit,
  })  : _db = db ?? DatabaseHelper(),
        _servicesRepo = servicesRepo ?? NearbyServicesRepository(),
        _contactsRepo = contactsRepo ?? EmergencyContactRepository(),
        _locationCubit = locationCubit,
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

    // 3. Centralized location tracking (subscribing to global LocationCubit state)
    _locationSub?.cancel();
    _locationSub = _locationCubit.stream.listen((locState) {
      if (locState.hasLocation) {
        add(HomeLocationUpdated(latitude: locState.latitude!, longitude: locState.longitude!));
      } else if (locState.status == LocationStatus.denied ||
                 locState.status == LocationStatus.deniedForever ||
                 locState.status == LocationStatus.failure) {
        if (state.latitude == null || state.longitude == null) {
          emit(state.copyWith(
            isLoading: false,
            hasLocationError: true,
            locationErrorMessage: locState.errorMessage,
          ));
        }
      }
    });

    // Check location right away
    final locState = _locationCubit.state;
    if (locState.hasLocation) {
      print("[HomeBloc] GPS loaded from state: ${locState.latitude}, ${locState.longitude}");
      add(HomeLocationUpdated(latitude: locState.latitude!, longitude: locState.longitude!));
    } else {
      // Trigger initialization if not already done
      _locationCubit.initLocation();
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
    
    try {
      await _servicesRepo.fetchAndCacheNearbyServices(event.latitude, event.longitude);
    } catch (e) {
      print("HomeBloc: fetch and cache failed: $e");
    }

    await _loadNearbyServices(event.latitude, event.longitude, emit);
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    return performReverseGeocode(lat, lng);
  }

  Future<void> _loadNearbyServices(
    double lat,
    double lng,
    Emitter<HomeState> emit,
  ) async {
    try {
      final hospitals = await _servicesRepo.getNearbyHospitals(lat, lng);
      final police = await _servicesRepo.getNearbyPolice(lat, lng);
      final towing = await _servicesRepo.getNearbyTowing(lat, lng);
      final contacts = await _contactsRepo.getContacts();

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
        signalQuality: event.signalQuality,
        syncStatus: event.syncStatus,
      ),
    );
  }

  /// Triggers a realistic 3-second progressive transition state for Mesh SOS BLE discovery.
  void _triggerMeshTransition(ConnectivityType conn, bool isCrashEnabled) {
    _meshTimer?.cancel();
    if (!isCrashEnabled) {
      add(const HomeMeshStatusUpdated(MeshSOSStatus.disabled, 0, 'None', 'Mesh disarmed'));
      return;
    }

    // Shift to CONNECTING status
    add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 0, 'Scanning...', 'Scanning BLE channels...'));

    int tick = 0;
    _meshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      tick++;
      if (!state.crashDetectionEnabled) {
        timer.cancel();
        add(const HomeMeshStatusUpdated(MeshSOSStatus.disabled, 0, 'None', 'Mesh disarmed'));
        return;
      }

      if (tick == 1) {
        add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 1, 'Searching', 'Discovering local nodes (1 found)...'));
      } else if (tick == 2) {
        add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 3, 'Syncing', 'Syncing telemetry logs (3 found)...'));
      } else if (tick >= 3) {
        timer.cancel();
        // Final resolution based on online/offline state
        if (conn == ConnectivityType.offline) {
          add(const HomeMeshStatusUpdated(
            MeshSOSStatus.offline,
            3,
            'Fair (62%)',
            'Local Mesh Fallback Routing Active',
          ));
        } else {
          final int randomPeers = 2 + Random().nextInt(3); // 2 to 4 peers
          add(HomeMeshStatusUpdated(
            MeshSOSStatus.active,
            randomPeers,
            'Excellent (95%)',
            'Synchronized with nearby mesh nodes',
          ));
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
    _locationSub?.cancel();
    _connectivitySub?.cancel();
    _meshTimer?.cancel();
    return super.close();
  }
}
