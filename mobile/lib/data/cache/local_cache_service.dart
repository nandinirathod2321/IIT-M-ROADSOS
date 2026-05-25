import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_shelter.dart';

class LocalCacheService {
  final DatabaseHelper _db;

  LocalCacheService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieve cached services matching coordinate boundaries.
  Future<Map<String, List<dynamic>>> getCachedServices(double lat, double lng) async {
    final hospitals = await _db.getNearbyHospitals(lat, lng);
    final police = await _db.getNearbyPolice(lat, lng);
    final towing = await _db.getNearbyTowing(lat, lng);
    final shelters = await _db.getNearbyShelters(lat, lng);

    return {
      'hospitals': hospitals,
      'police': police,
      'towing': towing,
      'shelters': shelters,
    };
  }

  /// Atomically purges and inserts new parsed services.
  Future<void> saveToCache({
    required List<Hospital> hospitals,
    required List<PoliceStation> police,
    required List<TowingService> towing,
    required List<EmergencyShelter> shelters,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _db.updateWebCache(
        hospitals: hospitals,
        police: police,
        towing: towing,
        shelters: shelters,
      );

      await prefs.setString('cached_hospitals', json.encode(hospitals.map((h) => h.toMap()).toList()));
      await prefs.setString('cached_police', json.encode(police.map((p) => p.toMap()).toList()));
      await prefs.setString('cached_towing', json.encode(towing.map((t) => t.toMap()).toList()));
      await prefs.setString('cached_shelters', json.encode(shelters.map((s) => s.toMap()).toList()));
    } else {
      final db = await _db.database;
      await db.transaction((txn) async {
        await txn.delete('hospitals');
        await txn.delete('police_stations');
        await txn.delete('towing_services');
        await txn.delete('emergency_shelters');

        for (final item in hospitals) {
          await txn.insert('hospitals', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in police) {
          await txn.insert('police_stations', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in towing) {
          await txn.insert('towing_services', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in shelters) {
          await txn.insert('emergency_shelters', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    }
  }
}
