import 'package:equatable/equatable.dart';
import '../../../data/models/hospital.dart';
import 'home_event.dart';

enum MeshSOSStatus { active, connecting, disabled, offline }

enum HomeLocationStatus {
  loading,
  success,
  timeout,
  permissionDenied,
  gpsDisabled,
}

class HomeState extends Equatable {
  final bool isLoading;
  final bool isRespondersLoading;
  final double? latitude;
  final double? longitude;
  final String address;
  final ConnectivityType connectivity;
  final bool crashDetectionEnabled;
  final MeshSOSStatus meshStatus;
  final int nearbyDevicesCount;
  final String signalQuality;
  final String syncStatus;
  final DateTime? lastDbSync;
  final int nearbyHospitalCount;
  final int nearbyPoliceCount;
  final int nearbyTowingCount;
  final int contactsCount;
  final Hospital? nearestHospital;
  final bool hasLocationError;
  final String locationErrorMessage;
  final bool isOffline;
  final bool isFromCache;
  final HomeLocationStatus locationStatus;

  const HomeState({
    this.isLoading = true,
    this.isRespondersLoading = true,
    this.latitude,
    this.longitude,
    this.address = 'Locating...',
    this.connectivity = ConnectivityType.offline,
    this.crashDetectionEnabled = true,
    this.meshStatus = MeshSOSStatus.connecting,
    this.nearbyDevicesCount = 0,
    this.signalQuality = 'None',
    this.syncStatus = 'Not Synced',
    this.lastDbSync,
    this.nearbyHospitalCount = 0,
    this.nearbyPoliceCount = 0,
    this.nearbyTowingCount = 0,
    this.contactsCount = 0,
    this.nearestHospital,
    this.hasLocationError = false,
    this.locationErrorMessage = '',
    this.isOffline = false,
    this.isFromCache = false,
    this.locationStatus = HomeLocationStatus.loading,
  });

  factory HomeState.initial() => HomeState(
        lastDbSync: DateTime.now(),
        signalQuality: 'None',
        syncStatus: 'Not Synced',
        isOffline: false,
        isFromCache: false,
        locationStatus: HomeLocationStatus.loading,
      );

  String get formattedCoordinates {
    if (latitude == null || longitude == null) return '-- --';
    final latDir = latitude! >= 0 ? 'N' : 'S';
    final lngDir = longitude! >= 0 ? 'E' : 'W';
    return '${latitude!.abs().toStringAsFixed(4)}° $latDir, ${longitude!.abs().toStringAsFixed(4)}° $lngDir';
  }

  String get connectivityLabel {
    switch (connectivity) {
      case ConnectivityType.wifi:
        return 'Wi-Fi';
      case ConnectivityType.mobile:
        return 'LTE';
      case ConnectivityType.offline:
        return 'Offline';
    }
  }

  HomeState copyWith({
    bool? isLoading,
    bool? isRespondersLoading,
    double? latitude,
    double? longitude,
    String? address,
    ConnectivityType? connectivity,
    bool? crashDetectionEnabled,
    MeshSOSStatus? meshStatus,
    int? nearbyDevicesCount,
    String? signalQuality,
    String? syncStatus,
    DateTime? lastDbSync,
    int? nearbyHospitalCount,
    int? nearbyPoliceCount,
    int? nearbyTowingCount,
    int? contactsCount,
    Hospital? nearestHospital,
    bool clearHospital = false,
    bool? hasLocationError,
    String? locationErrorMessage,
    bool? isOffline,
    bool? isFromCache,
    HomeLocationStatus? locationStatus,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isRespondersLoading: isRespondersLoading ?? this.isRespondersLoading,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      connectivity: connectivity ?? this.connectivity,
      crashDetectionEnabled: crashDetectionEnabled ?? this.crashDetectionEnabled,
      meshStatus: meshStatus ?? this.meshStatus,
      nearbyDevicesCount: nearbyDevicesCount ?? this.nearbyDevicesCount,
      signalQuality: signalQuality ?? this.signalQuality,
      syncStatus: syncStatus ?? this.syncStatus,
      lastDbSync: lastDbSync ?? this.lastDbSync,
      nearbyHospitalCount: nearbyHospitalCount ?? this.nearbyHospitalCount,
      nearbyPoliceCount: nearbyPoliceCount ?? this.nearbyPoliceCount,
      nearbyTowingCount: nearbyTowingCount ?? this.nearbyTowingCount,
      contactsCount: contactsCount ?? this.contactsCount,
      nearestHospital: clearHospital ? null : (nearestHospital ?? this.nearestHospital),
      hasLocationError: hasLocationError ?? this.hasLocationError,
      locationErrorMessage: locationErrorMessage ?? this.locationErrorMessage,
      isOffline: isOffline ?? this.isOffline,
      isFromCache: isFromCache ?? this.isFromCache,
      locationStatus: locationStatus ?? this.locationStatus,
    );
  }

  @override
  List<Object?> get props => [
        isLoading, isRespondersLoading, latitude, longitude, address, connectivity,
        crashDetectionEnabled, meshStatus, nearbyDevicesCount,
        signalQuality, syncStatus, lastDbSync,
        nearbyHospitalCount, nearbyPoliceCount, nearbyTowingCount,
        contactsCount, nearestHospital, hasLocationError, locationErrorMessage,
        isOffline, isFromCache, locationStatus,
      ];
}
