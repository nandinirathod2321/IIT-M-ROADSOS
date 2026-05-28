import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/utils/geocoder.dart';
import '../../../data/repositories/emergency_contact_repository.dart';
import '../../../presentation/blocs/location/location_cubit.dart';
import '../../../presentation/blocs/location/location_state.dart';
import '../../../core/responders/responder_cubit.dart';
import '../../../core/responders/responder_state.dart';
import 'home_event.dart';
import 'home_state.dart';

/// BLoC governing Home Screen rescue telemetry, real location updates,
/// network availability, and automated local spatial queries.
///
/// GPS and responder data are consumed from shared root-level cubits
/// ([LocationCubit] and [ResponderCubit]) — no duplicate fetching occurs.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final EmergencyContactRepository _contactsRepo;
  final LocationCubit _locationCubit;
  final ResponderCubit _responderCubit;

  StreamSubscription<LocationState>? _locationSub;
  StreamSubscription<ResponderState>? _responderSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _meshTimer;
  Timer? _safetyTimer;

  HomeBloc({
    EmergencyContactRepository? contactsRepo,
    required LocationCubit locationCubit,
    required ResponderCubit responderCubit,
  })  : _contactsRepo = contactsRepo ?? EmergencyContactRepository(),
        _locationCubit = locationCubit,
        _responderCubit = responderCubit,
        super(HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<HomeLocationUpdated>(_onLocationUpdated);
    on<HomeRespondersUpdated>(_onRespondersUpdated);
    on<HomeCrashDetectionToggled>(_onCrashDetectionToggled);
    on<HomeConnectivityChanged>(_onConnectivityChanged);
    on<HomeMeshStatusUpdated>(_onMeshStatusUpdated);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true, isRespondersLoading: true, hasLocationError: false));

    // 1. Connectivity stream
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!isClosed) add(HomeConnectivityChanged(_mapConnectivity(results)));
    });

    final connResults = await Connectivity().checkConnectivity();
    final mappedConn = _mapConnectivity(connResults);
    if (mappedConn == ConnectivityType.offline) {
      debugPrint('[OfflineMode] OFFLINE_MODE_ENABLED');
    }
    emit(state.copyWith(connectivity: mappedConn));

    // 3. Subscribe to global LocationCubit
    _locationSub?.cancel();
    _locationSub = _locationCubit.stream.listen((locState) {
      if (!isClosed) {
        if (locState.hasLocation) {
          add(HomeLocationUpdated(latitude: locState.latitude!, longitude: locState.longitude!));
        } else if (locState.status == LocationStatus.denied ||
                   locState.status == LocationStatus.deniedForever ||
                   locState.status == LocationStatus.failure) {
          if (!isClosed && (state.latitude == null || state.longitude == null)) {
            _safetyTimer?.cancel();
            emit(state.copyWith(
              isLoading: false,
              isRespondersLoading: false,
              hasLocationError: true,
              locationErrorMessage: locState.errorMessage,
            ));
          }
        }
      }
    });

    // Check location right now (avoid missing already-emitted state)
    final locState = _locationCubit.state;
    if (locState.hasLocation) {
      debugPrint('[HomeBloc] GPS available immediately: ${locState.latitude}, ${locState.longitude}');
      add(HomeLocationUpdated(latitude: locState.latitude!, longitude: locState.longitude!));
    } else if (locState.status == LocationStatus.failure ||
               locState.status == LocationStatus.denied) {
      emit(state.copyWith(
        isLoading: false,
        isRespondersLoading: false,
        hasLocationError: true,
        locationErrorMessage: locState.errorMessage,
      ));
    } else {
      // Start 6-second safety timeout timer if location is not resolved immediately
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 6), () {
        if (!isClosed && state.isLoading && (state.latitude == null || state.longitude == null)) {
          debugPrint('[HomeBloc] GPS resolution timed out (6s). Checking for cache fallback.');
          final currentLoc = _locationCubit.state;
          if (currentLoc.hasLocation) {
            debugPrint('[HomeBloc] Safety timeout triggered — utilizing cached location: ${currentLoc.latitude}, ${currentLoc.longitude}');
            debugPrint('[OfflineMode] LAST_LOCATION_USED');
            add(HomeLocationUpdated(latitude: currentLoc.latitude!, longitude: currentLoc.longitude!));
          } else {
            debugPrint('[HomeBloc] Safety timeout triggered and no cached location. Showing error.');
            emit(state.copyWith(
              isLoading: false,
              isRespondersLoading: false,
              hasLocationError: true,
              locationErrorMessage: 'GPS lock timeout. Please ensure location services are enabled.',
            ));
          }
        }
      });
    }
    // If status is initial/loading, the stream listener above will handle it

    // 4. Subscribe to global ResponderCubit
    _responderSub?.cancel();
    _responderSub = _responderCubit.stream.listen((rState) {
      if (!isClosed) add(HomeRespondersUpdated(rState));
    });

    // Immediately apply current responder state if available
    final currentResponders = _responderCubit.state;
    if (currentResponders.hasData) {
      add(HomeRespondersUpdated(currentResponders));
    }

    // 5. Load contacts count
    try {
      final contacts = await _contactsRepo.getContacts();
      if (!isClosed) emit(state.copyWith(contactsCount: contacts.length));
    } catch (_) {}

    // 6. Start mesh telemetry
    _triggerMeshTransition(state.connectivity, state.crashDetectionEnabled);
  }

  Future<void> _onLocationUpdated(
    HomeLocationUpdated event,
    Emitter<HomeState> emit,
  ) async {
    _safetyTimer?.cancel();
    emit(state.copyWith(
      latitude: event.latitude,
      longitude: event.longitude,
      hasLocationError: false,
      isLoading: false, // Stop loading once we have location
    ));

    // Reverse geocode for the address label (non-blocking)
    try {
      final address = await performReverseGeocode(event.latitude, event.longitude);
      if (!isClosed) emit(state.copyWith(address: address));
    } catch (_) {}
  }

  void _onRespondersUpdated(
    HomeRespondersUpdated event,
    Emitter<HomeState> emit,
  ) {
    final rs = event.responderState;

    if (rs.status == ResponderLoadStatus.loaded || rs.hasData) {
      final nearest = rs.hospitals.isNotEmpty ? rs.hospitals.first : null;
      emit(state.copyWith(
        isLoading: false,
        isRespondersLoading: false,
        nearbyHospitalCount: rs.hospitals.length,
        nearbyPoliceCount: rs.police.length,
        nearbyTowingCount: rs.towing.length,
        nearestHospital: nearest,
        clearHospital: nearest == null,
        lastDbSync: rs.lastFetchedAt ?? DateTime.now(),
        isOffline: rs.isOffline,
        isFromCache: rs.isFromCache,
      ));
      debugPrint('[HomeBloc] Responders updated: ${rs.hospitals.length} hospitals, '
          '${rs.police.length} police, ${rs.towing.length} towing.');
    } else if (rs.isLoading) {
      if (state.latitude == null) {
        emit(state.copyWith(
          isLoading: true, 
          isRespondersLoading: true,
          isOffline: rs.isOffline,
          isFromCache: rs.isFromCache,
        ));
      } else {
        emit(state.copyWith(
          isRespondersLoading: true,
          isOffline: rs.isOffline,
          isFromCache: rs.isFromCache,
        ));
      }
    } else if (rs.hasFailed) {
      emit(state.copyWith(
        isRespondersLoading: false,
        isOffline: rs.isOffline,
        isFromCache: rs.isFromCache,
      ));
    }
  }

  void _onCrashDetectionToggled(
    HomeCrashDetectionToggled event,
    Emitter<HomeState> emit,
  ) {
    final nextEnabled = !state.crashDetectionEnabled;
    emit(state.copyWith(
      crashDetectionEnabled: nextEnabled,
      meshStatus: nextEnabled ? MeshSOSStatus.connecting : MeshSOSStatus.disabled,
      nearbyDevicesCount: 0,
    ));
    _triggerMeshTransition(state.connectivity, nextEnabled);
  }

  void _onConnectivityChanged(
    HomeConnectivityChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(connectivity: event.type));
    if (event.type == ConnectivityType.offline) {
      debugPrint('[OfflineMode] OFFLINE_MODE_ENABLED');
    }
    _triggerMeshTransition(event.type, state.crashDetectionEnabled);
  }

  void _onMeshStatusUpdated(
    HomeMeshStatusUpdated event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      meshStatus: event.status,
      nearbyDevicesCount: event.nearbyDevicesCount,
      signalQuality: event.signalQuality,
      syncStatus: event.syncStatus,
    ));
  }

  /// Triggers a realistic 3-second progressive transition for Mesh SOS BLE discovery.
  void _triggerMeshTransition(ConnectivityType conn, bool isCrashEnabled) {
    _meshTimer?.cancel();
    if (isClosed) return;
    if (!isCrashEnabled) {
      add(const HomeMeshStatusUpdated(MeshSOSStatus.disabled, 0, 'None', 'Mesh disarmed'));
      return;
    }

    add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 0, 'Scanning...', 'Scanning BLE channels...'));

    int tick = 0;
    _meshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) { timer.cancel(); return; }
      tick++;
      if (!state.crashDetectionEnabled) {
        timer.cancel();
        if (!isClosed) add(const HomeMeshStatusUpdated(MeshSOSStatus.disabled, 0, 'None', 'Mesh disarmed'));
        return;
      }

      if (tick == 1) {
        if (!isClosed) add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 1, 'Searching', 'Discovering local nodes (1 found)...'));
      } else if (tick == 2) {
        if (!isClosed) add(const HomeMeshStatusUpdated(MeshSOSStatus.connecting, 3, 'Syncing', 'Syncing telemetry logs (3 found)...'));
      } else if (tick >= 3) {
        timer.cancel();
        if (!isClosed) {
          if (conn == ConnectivityType.offline) {
            add(const HomeMeshStatusUpdated(MeshSOSStatus.offline, 3, 'Fair (62%)', 'Local Mesh Fallback Routing Active'));
          } else {
            final int peers = 2 + Random().nextInt(3);
            add(HomeMeshStatusUpdated(MeshSOSStatus.active, peers, 'Excellent (95%)', 'Synchronized with nearby mesh nodes'));
          }
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
    _responderSub?.cancel();
    _connectivitySub?.cancel();
    _meshTimer?.cancel();
    _safetyTimer?.cancel();
    return super.close();
  }
}
