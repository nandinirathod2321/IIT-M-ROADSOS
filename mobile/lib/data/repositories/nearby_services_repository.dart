import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  static const _fetchThrottleMs = 10 * 60 * 1000; // 10 minutes
  static const _fetchDistanceKm = 1.5;

  NearbyServicesRepository({
    EmergencyServicesApiService? apiService,
    LocalCacheService? cacheService,
  })  : _apiService = apiService ?? EmergencyServicesApiService(),
        _cacheService = cacheService ?? LocalCacheService();

  /// Fetches live OSM Overpass data and persists results locally.
  Future<void> fetchAndCacheNearbyServices(
    double lat,
    double lng, {
    bool forceRefresh = false,
    int radiusMeters = 10000,
  }) async {
    if (!forceRefresh && await _isFetchThrottled(lat, lng)) {
      debugPrint('[NearbyServices] Skipping Overpass fetch — throttled for ($lat, $lng)');
      return;
    }

    bool offline = false;
    try {
      final conn = await Connectivity().checkConnectivity();
      offline = conn.contains(ConnectivityResult.none);
    } catch (_) {}

    if (offline) {
      debugPrint('[NearbyServices] Offline — skipping Overpass API request');
      return;
    }

    debugPrint('[NearbyServices] Overpass API request sent at ($lat, $lng), radius=${radiusMeters}m');

    try {
      final raw = await _apiService
          .fetchNearbyServices(lat, lng, radiusMeters: radiusMeters)
          .timeout(const Duration(seconds: 15));

      final hospitals = _withDistance<Hospital>(
        lat,
        lng,
        List<Hospital>.from(raw['hospitals'] ?? []),
        (h, d) => h.copyWithDistance(distanceKm: d, estimatedMinutes: (d / 0.5).roundToDouble()),
      );
      final police = _withDistance<PoliceStation>(
        lat,
        lng,
        List<PoliceStation>.from(raw['police'] ?? []),
        (p, d) => p.copyWithDistance(distanceKm: d),
      );
      final towing = _withDistance<TowingService>(
        lat,
        lng,
        List<TowingService>.from(raw['towing'] ?? []),
        (t, d) => t.copyWithDistance(distanceKm: d),
      );
      final shelters = _withDistance<EmergencyShelter>(
        lat,
        lng,
        List<EmergencyShelter>.from(raw['shelters'] ?? []),
        (s, d) => s.copyWithDistance(distanceKm: d),
      );

      debugPrint('[NearbyServices] Overpass API response count: '
          '${hospitals.length} hospitals, ${police.length} police, '
          '${towing.length} towing, ${shelters.length} shelters');

      if (hospitals.isEmpty && police.isEmpty && towing.isEmpty && shelters.isEmpty) {
        debugPrint('[NearbyServices] Overpass returned no named services in radius');
        return;
      }

      await saveToCache(
        hospitals: hospitals,
        police: police,
        towing: towing,
        shelters: shelters,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_fetch_lat', lat);
      await prefs.setDouble('last_fetch_lng', lng);
      await prefs.setInt('last_fetch_time', DateTime.now().millisecondsSinceEpoch);

      debugPrint('[NearbyServices] Cached ${hospitals.length + police.length + towing.length + shelters.length} services locally');
    } catch (e) {
      debugPrint('[NearbyServices] Overpass API failure: $e');
      rethrow;
    }
  }

  Future<bool> _isFetchThrottled(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt('last_fetch_time');
    final lastLat = prefs.getDouble('last_fetch_lat');
    final lastLng = prefs.getDouble('last_fetch_lng');
    if (lastTime == null || lastLat == null || lastLng == null) return false;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastTime;
    if (elapsed >= _fetchThrottleMs) return false;

    final movedKm = DistanceUtils.haversine(lat, lng, lastLat, lastLng);
    return movedKm < _fetchDistanceKm;
  }

  List<T> _withDistance<T>(
    double lat,
    double lng,
    List<T> items,
    T Function(T item, double distanceKm) applyDistance,
  ) {
    final withDist = items.map((item) {
      double itemLat = 0;
      double itemLng = 0;
      if (item is Hospital) {
        itemLat = item.lat;
        itemLng = item.lng;
      } else if (item is PoliceStation) {
        itemLat = item.lat;
        itemLng = item.lng;
      } else if (item is TowingService) {
        itemLat = item.lat;
        itemLng = item.lng;
      } else if (item is EmergencyShelter) {
        itemLat = item.lat;
        itemLng = item.lng;
      }
      final dist = DistanceUtils.haversine(lat, lng, itemLat, itemLng);
      return applyDistance(item, double.parse(dist.toStringAsFixed(2)));
    }).toList();

    withDist.sort((a, b) {
      double distA = 0;
      double distB = 0;
      if (a is Hospital) distA = a.distanceKm;
      if (a is PoliceStation) distA = a.distanceKm;
      if (a is TowingService) distA = a.distanceKm;
      if (a is EmergencyShelter) distA = a.distanceKm;
      if (b is Hospital) distB = b.distanceKm;
      if (b is PoliceStation) distB = b.distanceKm;
      if (b is TowingService) distB = b.distanceKm;
      if (b is EmergencyShelter) distB = b.distanceKm;
      return distA.compareTo(distB);
    });

    return withDist;
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
