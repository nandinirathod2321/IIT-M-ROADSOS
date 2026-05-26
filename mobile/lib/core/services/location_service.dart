import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import '../errors/app_exceptions.dart';
import '../utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Requests permissions and resolves the current position.
  /// Web-safe: always uses getCurrentPosition with timeouts, never uses getLastKnownPosition.
  Future<Position> getCurrentLocation() async {
    AppLogger.info('Resolving GPS location...');

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      AppLogger.warning('Could not verify if location services are enabled: $e');
      serviceEnabled = true; // Safe fallback for web/mock environments
    }

    if (!serviceEnabled) {
      throw const LocationException('Location services are disabled on this device.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Location permissions are permanently denied. Please enable them in device settings.');
    }

    final timeoutSecs = kIsWeb ? 8 : 5;
    AppLogger.info('Location services approved. Fetching coordinates (timeout: $timeoutSecs s)...');

    try {
      if (kIsWeb) {
        // Flutter Web: ALWAYS use getCurrentPosition with timeouts.
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: timeoutSecs),
        );
      } else {
        // Native: try high accuracy, fallback to low accuracy, then last known position.
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          AppLogger.warning('High accuracy position resolution failed, falling back to low accuracy: $e');
          try {
            return await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 3),
            );
          } catch (e2) {
            AppLogger.warning('Low accuracy position resolution failed, trying last known position: $e2');
            final lastPos = await Geolocator.getLastKnownPosition();
            if (lastPos != null) return lastPos;
            throw const LocationException('Failed to acquire coordinates from device sensor.');
          }
        }
      }
    } catch (e) {
      AppLogger.error('GPS resolution failed', e);
      throw LocationException('Failed to acquire GPS position: $e');
    }
  }

  /// Listens to location updates as a stream.
  Stream<Position> getLocationStream() {
    AppLogger.info('Subscribing to real-time location stream');
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    );
  }
}
