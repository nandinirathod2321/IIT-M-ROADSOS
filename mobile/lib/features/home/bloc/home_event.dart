import 'package:equatable/equatable.dart';
import 'home_state.dart';
import '../../../presentation/blocs/nearby/nearby_state.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class HomeLocationUpdated extends HomeEvent {
  final double latitude;
  final double longitude;
  const HomeLocationUpdated({required this.latitude, required this.longitude});
  @override
  List<Object?> get props => [latitude, longitude];
}

class HomeCrashDetectionToggled extends HomeEvent {
  const HomeCrashDetectionToggled();
}

class HomeConnectivityChanged extends HomeEvent {
  final ConnectivityType type;
  const HomeConnectivityChanged(this.type);
  @override
  List<Object?> get props => [type];
}

class HomeMeshStatusUpdated extends HomeEvent {
  final MeshSOSStatus status;
  final int nearbyDevicesCount;
  final String signalQuality;
  final String syncStatus;
  const HomeMeshStatusUpdated(
    this.status,
    this.nearbyDevicesCount,
    this.signalQuality,
    this.syncStatus,
  );
  @override
  List<Object?> get props => [status, nearbyDevicesCount, signalQuality, syncStatus];
}

class HomeRespondersUpdated extends HomeEvent {
  final NearbyState responderState;
  const HomeRespondersUpdated(this.responderState);
  @override
  List<Object?> get props => [responderState];
}

enum ConnectivityType { wifi, mobile, offline }
