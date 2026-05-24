import 'package:equatable/equatable.dart';

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

enum ConnectivityType { wifi, mobile, offline }
