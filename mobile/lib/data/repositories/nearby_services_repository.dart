import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/distance_utils.dart';
import '../api/emergency_services_api_service.dart';
import '../cache/local_cache_service.dart';
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_shelter.dart';

class NearbyServicesRepository {
  final EmergencyServicesApiService _apiService;
  final LocalCacheService _cacheService;

  NearbyServicesRepository({
    EmergencyServicesApiService? apiService,
    LocalCacheService? cacheService,
  })  : _apiService = apiService ?? EmergencyServicesApiService(),
        _cacheService = cacheService ?? LocalCacheService();

  /// Forces or conditionally throttles the remote OSM Overpass fetch & database caching.
  Future<void> fetchAndCacheNearbyServices(double lat, double lng,
      {bool forceRefresh = false, int radiusMeters = 10000}) async {
    print("[NearbyServicesRepository] Overpass API disabled. Exclusively using pre-seeded local database.");
    return;
  }

  /// Queries nearby hospitals from the spatial database cache.
  Future<List<Hospital>> getNearbyHospitals(double lat, double lng) async {
    final cached = await _cacheService.getCachedServices(lat, lng);
    return List<Hospital>.from(cached['hospitals'] ?? []);
  }

  /// Queries nearby police stations from the spatial database cache.
  Future<List<PoliceStation>> getNearbyPolice(double lat, double lng) async {
    final cached = await _cacheService.getCachedServices(lat, lng);
    return List<PoliceStation>.from(cached['police'] ?? []);
  }

  /// Queries nearby towing services from the spatial database cache.
  Future<List<TowingService>> getNearbyTowing(double lat, double lng) async {
    final cached = await _cacheService.getCachedServices(lat, lng);
    return List<TowingService>.from(cached['towing'] ?? []);
  }

  /// Queries nearby emergency shelters from the spatial database cache.
  Future<List<EmergencyShelter>> getNearbyShelters(double lat, double lng) async {
    final cached = await _cacheService.getCachedServices(lat, lng);
    return List<EmergencyShelter>.from(cached['shelters'] ?? []);
  }

  /// Atomically purges and inserts new parsed services to cache.
  Future<void> saveToCache({
    required List<Hospital> hospitals,
    required List<PoliceStation> police,
    required List<TowingService> towing,
    required List<EmergencyShelter> shelters,
  }) async {
    await _cacheService.saveToCache(
      hospitals: hospitals,
      police: police,
      towing: towing,
      shelters: shelters,
    );
  }
}
