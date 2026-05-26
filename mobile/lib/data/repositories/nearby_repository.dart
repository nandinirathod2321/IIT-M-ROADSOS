import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/errors/app_exceptions.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/overpass_service.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/distance_utils.dart';
import '../models/nearby_place.dart';
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import 'nearby_services_repository.dart';

class NearbyRepository {
  final OverpassService _overpassService;
  final CacheService _inMemoryCache;
  final NearbyServicesRepository _localDbRepo;

  NearbyRepository({
    OverpassService? overpassService,
    CacheService? inMemoryCache,
    NearbyServicesRepository? localDbRepo,
  })  : _overpassService = overpassService ?? OverpassService(),
        _inMemoryCache = inMemoryCache ?? CacheService(),
        _localDbRepo = localDbRepo ?? NearbyServicesRepository();

  /// Orchestrates fetching nearby emergency responders.
  /// 1. Tries in-memory cache (within 1.5 km and 10 mins).
  /// 2. Tries OSM Overpass API.
  /// 3. Falls back to pre-seeded local SQLite database.
  Future<List<NearbyPlace>> getNearbyPlaces(double lat, double lng, {bool forceRefresh = false}) async {
    AppLogger.info('NearbyRepository: fetching nearby emergency responders...');

    // 1. Tries in-memory cache
    if (!forceRefresh && _inMemoryCache.hasValidPlaces(lat, lng, 1.5)) {
      AppLogger.info('NearbyRepository: Serving from in-memory cache.');
      return _inMemoryCache.cachedPlaces;
    }

    // 2. Tries OSM Overpass API
    try {
      AppLogger.info('NearbyRepository: Fetching fresh responders from OSM Overpass...');
      final places = await _overpassService.fetchNearbyResponders(lat, lng);
      
      if (places.isNotEmpty) {
        // Cache in memory
        _inMemoryCache.setNearbyPlaces(places, lat, lng);
        
        // Background cache save to SQLite (do not block UI thread)
        _saveToLocalDbAsync(places, lat, lng);
        
        return places;
      }
    } catch (e) {
      AppLogger.warning('NearbyRepository: OSM Overpass fetch failed. Degrading gracefully to SQLite cache: $e');
    }

    // 3. Fallback: Pre-seeded local SQLite Database
    try {
      AppLogger.info('NearbyRepository: Querying pre-seeded local SQLite/fallback database...');
      final hospitals = await _localDbRepo.getNearbyHospitals(lat, lng);
      final police = await _localDbRepo.getNearbyPolice(lat, lng);
      final towing = await _localDbRepo.getNearbyTowing(lat, lng);

      final List<NearbyPlace> localPlaces = [];

      for (final h in hospitals) {
        localPlaces.add(NearbyPlace(
          id: 'db_hospital_${h.id}',
          name: h.name,
          type: NearbyPlaceType.hospital,
          latitude: h.latitude,
          longitude: h.longitude,
          address: h.address,
          distanceKm: DistanceUtils.haversine(lat, lng, h.latitude, h.longitude),
          phone: h.phone,
        ));
      }

      for (final p in police) {
        localPlaces.add(NearbyPlace(
          id: 'db_police_${p.id}',
          name: p.name,
          type: NearbyPlaceType.police,
          latitude: p.latitude,
          longitude: p.longitude,
          address: p.address,
          distanceKm: DistanceUtils.haversine(lat, lng, p.latitude, p.longitude),
          phone: p.phone,
        ));
      }

      for (final t in towing) {
        localPlaces.add(NearbyPlace(
          id: 'db_towing_${t.id}',
          name: t.name,
          type: NearbyPlaceType.towing,
          latitude: t.latitude,
          longitude: t.longitude,
          address: t.address,
          distanceKm: DistanceUtils.haversine(lat, lng, t.latitude, t.longitude),
          phone: t.phone,
        ));
      }

      // Sort by distance (closest first)
      localPlaces.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      if (localPlaces.isNotEmpty) {
        AppLogger.info('NearbyRepository: Loaded ${localPlaces.length} services from local fallback DB.');
        _inMemoryCache.setNearbyPlaces(localPlaces, lat, lng);
        return localPlaces;
      }
    } catch (e) {
      AppLogger.error('NearbyRepository: Failed to load from local SQLite fallback DB', e);
    }

    // Return empty list if everything failed
    AppLogger.warning('NearbyRepository: No services found anywhere.');
    return [];
  }

  /// Converts and saves the fresh places list into the SQLite database.
  Future<void> _saveToLocalDbAsync(List<NearbyPlace> places, double lat, double lng) async {
    try {
      // Create database models matching SQLite expectations
      final hospitals = places
          .where((p) => p.type == NearbyPlaceType.hospital)
          .map((p) => _convertToHospital(p))
          .toList();
          
      final police = places
          .where((p) => p.type == NearbyPlaceType.police)
          .map((p) => _convertToPolice(p))
          .toList();
          
      final towing = places
          .where((p) => p.type == NearbyPlaceType.towing)
          .map((p) => _convertToTowing(p))
          .toList();

      await _localDbRepo.saveToCache(
        hospitals: hospitals,
        police: police,
        towing: towing,
        shelters: [], // Overpass query doesn't query shelters directly
      );
      AppLogger.info('NearbyRepository: Successfully synchronized fresh places to SQLite cache.');
    } catch (e) {
      AppLogger.warning('NearbyRepository: Background SQLite cache sync failed: $e');
    }
  }

  Hospital _convertToHospital(NearbyPlace p) {
    return Hospital(
      id: p.id,
      name: p.name,
      address: p.address,
      lat: p.latitude,
      lng: p.longitude,
      phone: p.phone ?? '',
      lastUpdated: DateTime.now(),
    );
  }

  PoliceStation _convertToPolice(NearbyPlace p) {
    return PoliceStation(
      id: p.id,
      name: p.name,
      address: p.address,
      lat: p.latitude,
      lng: p.longitude,
      phone: p.phone ?? '',
    );
  }

  TowingService _convertToTowing(NearbyPlace p) {
    return TowingService(
      id: p.id,
      name: p.name,
      phone: p.phone ?? '',
      lat: p.latitude,
      lng: p.longitude,
      address: p.address,
    );
  }
}
