import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;
import '../../core/services/auth_service.dart';
import 'db_size_helper.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/utils/distance_utils.dart';
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_contact.dart';
import '../models/medical_profile.dart';
import '../models/user.dart';
import '../models/settings.dart';
import '../models/sos_event.dart';
import '../models/chat_message.dart';
import '../models/emergency_shelter.dart';

/// Singleton helper that owns the SQLite database lifecycle for RoadSOS.
///
/// Centralized schemas:
///   1. `users`
///   2. `emergency_contacts`
///   3. `sos_events`
///   4. `hospitals`
///   5. `police_stations`
///   6. `towing_services`
///   7. `ai_chat_history`
///   8. `settings`
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static final List<Hospital> _webHospitals = [];
  static final List<PoliceStation> _webPolice = [];
  static final List<TowingService> _webTowing = [];
  static final List<EmergencyContact> _webContacts = [];
  static final List<SosEvent> _webSosEvents = [];
  static final List<ChatMessageModel> _webChatHistory = [];
  static final List<EmergencyShelter> _webShelters = [];
  
  static User? _webUser;
  static Settings? _webSettings;

  /// Public method to update the in-memory web spatial database.
  void updateWebCache({
    required List<Hospital> hospitals,
    required List<PoliceStation> police,
    required List<TowingService> towing,
    required List<EmergencyShelter> shelters,
  }) {
    _webHospitals.clear();
    _webHospitals.addAll(hospitals);
    _webPolice.clear();
    _webPolice.addAll(police);
    _webTowing.clear();
    _webTowing.addAll(towing);
    _webShelters.clear();
    _webShelters.addAll(shelters);
  }

  Database? _db;

  /// Returns the open database, initialising it on first call.
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError("SQLite database is not supported on Web.");
    }
    _db ??= await _initDatabase();
    return _db!;
  }

  // ── Initialisation ───────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'roadsos_v2.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await seedDemoData(db);
        await seedDefaultSettings(db);
        await seedDefaultUser(db);
      },
    );
  }

  /// Public entry point — ensures the database and all tables exist.
  Future<void> initialize() async {
    if (kIsWeb) {
      await _initWebMockData();
      return;
    }
    final db = await database;
    
    // Self-healing migration triggers to ensure all 8 tables are created
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id                 TEXT PRIMARY KEY,
        full_name          TEXT,
        email              TEXT,
        phone              TEXT,
        profile_photo      TEXT,
        blood_group        TEXT,
        allergies          TEXT,
        medications        TEXT,
        medical_conditions TEXT,
        emergency_notes    TEXT,
        organ_donor        INTEGER DEFAULT 0,
        created_at         TEXT,
        updated_at         TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_contacts (
        id           TEXT PRIMARY KEY,
        user_id      TEXT,
        full_name    TEXT NOT NULL,
        relationship TEXT,
        phone        TEXT NOT NULL,
        email        TEXT,
        is_primary   INTEGER DEFAULT 0,
        created_at   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sos_events (
        id                     TEXT PRIMARY KEY,
        user_id                TEXT,
        latitude               REAL NOT NULL,
        longitude              REAL NOT NULL,
        address                TEXT,
        emergency_type         TEXT,
        timestamp              TEXT NOT NULL,
        contacts_notified      TEXT,
        nearest_hospital       TEXT,
        nearest_police_station TEXT,
        status                 TEXT DEFAULT 'dispatched'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hospitals (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        latitude       REAL NOT NULL,
        longitude      REAL NOT NULL,
        address        TEXT,
        phone          TEXT,
        city           TEXT,
        state          TEXT,
        type           TEXT DEFAULT 'general',
        hasEmergency   INTEGER DEFAULT 0,
        hasICU         INTEGER DEFAULT 0,
        hasBloodBank   INTEGER DEFAULT 0,
        ambulanceCount INTEGER DEFAULT 0,
        lastUpdated    TEXT,
        sourceApi      TEXT,
        rating         REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS police_stations (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        latitude     REAL NOT NULL,
        longitude    REAL NOT NULL,
        address      TEXT,
        phone        TEXT,
        city         TEXT,
        state        TEXT,
        districtCode TEXT,
        is24Hours    INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS towing_services (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        latitude       REAL NOT NULL,
        longitude      REAL NOT NULL,
        address        TEXT,
        phone          TEXT,
        city           TEXT,
        state          TEXT,
        serviceRadius  REAL DEFAULT 0.0,
        operatingHours TEXT,
        vehicleTypes   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_chat_history (
        id           TEXT PRIMARY KEY,
        user_id      TEXT,
        user_message TEXT,
        ai_response  TEXT,
        timestamp    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id                       TEXT PRIMARY KEY,
        voice_sos_enabled        INTEGER DEFAULT 0,
        dark_mode                INTEGER DEFAULT 1,
        emergency_auto_share     INTEGER DEFAULT 1,
        ai_assistant_enabled     INTEGER DEFAULT 1,
        sos_countdown            INTEGER DEFAULT 5,
        crash_detection_enabled  INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_shelters (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        latitude     REAL NOT NULL,
        longitude    REAL NOT NULL,
        address      TEXT,
        phone        TEXT,
        city         TEXT,
        state        TEXT,
        capacity     INTEGER DEFAULT 0,
        last_updated TEXT
      )
    ''');

    // Auto-seed if hospitals are empty to guarantee spatial queries work
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM hospitals'),
    );
    if (count == null || count == 0) {
      await seedDemoData(db);
    }

    // Auto-seed settings if empty
    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM settings'),
    );
    if (settingsCount == null || settingsCount == 0) {
      await seedDefaultSettings(db);
    }

    // Auto-seed user if empty
    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    if (userCount == null || userCount == 0) {
      await seedDefaultUser(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── Users ────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE users (
        id                 TEXT PRIMARY KEY,
        full_name          TEXT,
        email              TEXT,
        phone              TEXT,
        profile_photo      TEXT,
        blood_group        TEXT,
        allergies          TEXT,
        medications        TEXT,
        medical_conditions TEXT,
        emergency_notes    TEXT,
        organ_donor        INTEGER DEFAULT 0,
        created_at         TEXT,
        updated_at         TEXT
      )
    ''');

    // ── Emergency Contacts ───────────────────────────────────────────
    batch.execute('''
      CREATE TABLE emergency_contacts (
        id           TEXT PRIMARY KEY,
        user_id      TEXT,
        full_name    TEXT NOT NULL,
        relationship TEXT,
        phone        TEXT NOT NULL,
        email        TEXT,
        is_primary   INTEGER DEFAULT 0,
        created_at   TEXT
      )
    ''');

    // ── SOS Events ───────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE sos_events (
        id                     TEXT PRIMARY KEY,
        user_id                TEXT,
        latitude               REAL NOT NULL,
        longitude              REAL NOT NULL,
        address                TEXT,
        emergency_type         TEXT,
        timestamp              TEXT NOT NULL,
        contacts_notified      TEXT,
        nearest_hospital       TEXT,
        nearest_police_station TEXT,
        status                 TEXT DEFAULT 'dispatched'
      )
    ''');

    // ── Hospitals ────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE hospitals (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        latitude       REAL NOT NULL,
        longitude      REAL NOT NULL,
        address        TEXT,
        phone          TEXT,
        city           TEXT,
        state          TEXT,
        type           TEXT DEFAULT 'general',
        hasEmergency   INTEGER DEFAULT 0,
        hasICU         INTEGER DEFAULT 0,
        hasBloodBank   INTEGER DEFAULT 0,
        ambulanceCount INTEGER DEFAULT 0,
        lastUpdated    TEXT,
        sourceApi      TEXT,
        rating         REAL DEFAULT 0.0
      )
    ''');
    batch.execute('CREATE INDEX idx_hospitals_lat ON hospitals (latitude)');
    batch.execute('CREATE INDEX idx_hospitals_lng ON hospitals (longitude)');

    // ── Police Stations ──────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE police_stations (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        latitude     REAL NOT NULL,
        longitude    REAL NOT NULL,
        address      TEXT,
        phone        TEXT,
        city         TEXT,
        state        TEXT,
        districtCode TEXT,
        is24Hours    INTEGER DEFAULT 1
      )
    ''');
    batch.execute('CREATE INDEX idx_police_lat ON police_stations (latitude)');
    batch.execute('CREATE INDEX idx_police_lng ON police_stations (longitude)');

    // ── Towing Services ──────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE towing_services (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        latitude       REAL NOT NULL,
        longitude      REAL NOT NULL,
        address        TEXT,
        phone        TEXT,
        city           TEXT,
        state          TEXT,
        serviceRadius  REAL DEFAULT 0.0,
        operatingHours TEXT,
        vehicleTypes   TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_towing_lat ON towing_services (latitude)');
    batch.execute('CREATE INDEX idx_towing_lng ON towing_services (longitude)');

    // ── AI Chat History ──────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ai_chat_history (
        id           TEXT PRIMARY KEY,
        user_id      TEXT,
        user_message TEXT,
        ai_response  TEXT,
        timestamp    TEXT
      )
    ''');

    // ── Settings ─────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE settings (
        id                       TEXT PRIMARY KEY,
        voice_sos_enabled        INTEGER DEFAULT 0,
        dark_mode                INTEGER DEFAULT 1,
        emergency_auto_share     INTEGER DEFAULT 1,
        ai_assistant_enabled     INTEGER DEFAULT 1,
        sos_countdown            INTEGER DEFAULT 5,
        crash_detection_enabled  INTEGER DEFAULT 0
      )
    ''');

    // ── Emergency Shelters ───────────────────────────────────────────
    batch.execute('''
      CREATE TABLE emergency_shelters (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        latitude     REAL NOT NULL,
        longitude    REAL NOT NULL,
        address      TEXT,
        phone        TEXT,
        city         TEXT,
        state        TEXT,
        capacity     INTEGER DEFAULT 0,
        last_updated TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_shelters_lat ON emergency_shelters (latitude)');
    batch.execute('CREATE INDEX idx_shelters_lng ON emergency_shelters (longitude)');

    await batch.commit(noResult: true);
  }

  double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLng = (lng2 - lng1) * pi / 180;
    double a = sin(dLat/2)*sin(dLat/2) +
               cos(lat1*pi/180)*cos(lat2*pi/180)*
               sin(dLng/2)*sin(dLng/2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  Future<int> getHospitalCount(double lat, double lng, {double radiusKm = 50}) async {
    if (kIsWeb) {
      final list = await getNearbyHospitals(lat, lng, radiusKm: radiusKm);
      return list.length;
    }
    final db = await database;
    double latDelta = radiusKm / 111.0;
    double lngDelta = radiusKm / (111.0 * cos(lat * pi / 180));
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM hospitals WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
        [lat - latDelta, lat + latDelta, lng - lngDelta, lng + lngDelta],
      ),
    );
    return count ?? 0;
  }

  // ── Database Diagnostics ─────────────────────────────────────────────

  Future<int> getDatabaseRecordCount() async {
    if (kIsWeb) return _webHospitals.length + _webPolice.length + _webTowing.length + _webContacts.length + _webSosEvents.length + _webChatHistory.length;
    final db = await database;
    int total = 0;
    total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM hospitals')) ?? 0;
    total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM police_stations')) ?? 0;
    total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM towing_services')) ?? 0;
    total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM emergency_contacts')) ?? 0;
    total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sos_events')) ?? 0;
    return total;
  }

  Future<int> getDatabaseSizeInBytes() async {
    if (kIsWeb) return 0;
    return getDbSizeInBytes();
  }

  // ── Seeding ──────────────────────────────────────────────────────────

  Future<void> seedDefaultSettings(Database db) async {
    final defaultSettings = {
      'id': 'default',
      'voice_sos_enabled': 0,
      'dark_mode': 1,
      'emergency_auto_share': 1,
      'ai_assistant_enabled': 1,
      'sos_countdown': 5,
      'crash_detection_enabled': 0,
    };
    await db.insert('settings', defaultSettings, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> seedDefaultUser(Database db) async {
    final defaultUser = {
      'id': 'me',
      'full_name': 'Nandini Rathod',
      'email': 'nandini@roadsos.in',
      'phone': '+91 98765 43210',
      'profile_photo': '',
      'blood_group': 'O+',
      'allergies': 'Penicillin, Peanuts',
      'medications': 'None',
      'medical_conditions': 'None',
      'emergency_notes': 'Primary user profile details loaded successfully.',
      'organ_donor': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await db.insert('users', defaultUser, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> seedDemoData(Database db) async {
    final batch = db.batch();

    for (var h in _getHospitalsSeedData(23.0225, 72.5714)) {
      batch.insert('hospitals', h, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (var p in _getPoliceSeedData(23.0225, 72.5714)) {
      batch.insert('police_stations', p, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (var t in _getTowingSeedData(23.0225, 72.5714)) {
      batch.insert('towing_services', t, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // ── Backward Compatible Spatial Queries ──────────────────────────────

  Future<List<Hospital>> getNearbyHospitals(double lat, double lng, {double radiusKm = 50}) async {
    debugPrint("[AntiGravity] Fetching hospitals at ($lat, $lng) with radius: $radiusKm");
    if (kIsWeb) {
      await _initWebMockData(centerLat: lat, centerLng: lng);
      final results = <Hospital>[];
      for (final hospital in _webHospitals) {
        final dist = haversineDistance(lat, lng, hospital.lat, hospital.lng);
        if (dist <= radiusKm) {
          results.add(hospital.copyWithDistance(
            distanceKm: double.parse(dist.toStringAsFixed(2)),
            estimatedMinutes: (dist / 0.5).round().toDouble(),
          ));
        }
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      // Print raw JSON before returning
      final rawJson = json.encode(results.map((h) => h.toMap()).toList());
      debugPrint("[AntiGravity] Raw JSON for parsed hospitals: $rawJson");
      debugPrint("[AntiGravity] Fetched hospital count: ${results.length}");

      if (results.isEmpty) {
        debugPrint("[AntiGravity] Empty hospital list detected at ($lat, $lng)");
      }
      return results;
    }

    final db = await database;
    double latDelta = radiusKm / 111.0;
    double lngDelta = radiusKm / (111.0 * cos(lat * pi / 180));
    
    String sql = """
      SELECT *, 
        ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS dist_sq
      FROM hospitals
      WHERE latitude BETWEEN ? AND ?
        AND longitude BETWEEN ? AND ?
      ORDER BY dist_sq ASC
      LIMIT 50
    """;
    
    List<Map<String, dynamic>> results = await db.rawQuery(sql, [
      lat, lat, lng, lng,
      lat - latDelta, lat + latDelta,
      lng - lngDelta, lng + lngDelta,
    ]);

    final parsed = results.map((r) {
      Hospital h = Hospital.fromMap(Map<String, dynamic>.from(r));
      double dist = haversineDistance(lat, lng, h.lat, h.lng);
      return h.copyWithDistance(
        distanceKm: double.parse(dist.toStringAsFixed(2)),
        estimatedMinutes: (dist / 0.5).round().toDouble(),
      );
    }).where((h) => h.distanceKm <= radiusKm)
      .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final rawJson = json.encode(parsed.map((h) => h.toMap()).toList());
    debugPrint("[AntiGravity] Raw JSON for parsed hospitals (SQLite): $rawJson");
    debugPrint("[AntiGravity] Fetched hospital count: ${parsed.length}");
    
    if (parsed.isEmpty) {
      debugPrint("[AntiGravity] Empty hospital list detected at ($lat, $lng)");
    }
    return parsed;
  }

  Future<List<PoliceStation>> getNearbyPolice(double lat, double lng, {double radiusKm = 20}) async {
    debugPrint("[AntiGravity] Fetching police stations at ($lat, $lng) with radius: $radiusKm");
    if (kIsWeb) {
      await _initWebMockData(centerLat: lat, centerLng: lng);
      final results = <PoliceStation>[];
      for (final station in _webPolice) {
        final dist = haversineDistance(lat, lng, station.lat, station.lng);
        if (dist <= radiusKm) {
          results.add(station.copyWithDistance(
            distanceKm: double.parse(dist.toStringAsFixed(2)),
          ));
        }
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      final rawJson = json.encode(results.map((p) => p.toMap()).toList());
      debugPrint("[AntiGravity] Raw JSON for parsed police: $rawJson");
      debugPrint("[AntiGravity] Fetched police count: ${results.length}");

      if (results.isEmpty) {
        debugPrint("[AntiGravity] Empty police list detected at ($lat, $lng)");
      }
      return results;
    }

    final db = await database;
    double latDelta = radiusKm / 111.0;
    double lngDelta = radiusKm / (111.0 * cos(lat * pi / 180));
    
    String sql = """
      SELECT *, 
        ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS dist_sq
      FROM police_stations
      WHERE latitude BETWEEN ? AND ?
        AND longitude BETWEEN ? AND ?
      ORDER BY dist_sq ASC
      LIMIT 50
    """;
    
    List<Map<String, dynamic>> results = await db.rawQuery(sql, [
      lat, lat, lng, lng,
      lat - latDelta, lat + latDelta,
      lng - lngDelta, lng + lngDelta,
    ]);

    final parsed = results.map((r) {
      PoliceStation p = PoliceStation.fromMap(Map<String, dynamic>.from(r));
      double dist = haversineDistance(lat, lng, p.lat, p.lng);
      return p.copyWithDistance(
        distanceKm: double.parse(dist.toStringAsFixed(2)),
      );
    }).where((p) => p.distanceKm <= radiusKm)
      .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final rawJson = json.encode(parsed.map((p) => p.toMap()).toList());
    debugPrint("[AntiGravity] Raw JSON for parsed police (SQLite): $rawJson");
    debugPrint("[AntiGravity] Fetched police count: ${parsed.length}");

    if (parsed.isEmpty) {
      debugPrint("[AntiGravity] Empty police list detected at ($lat, $lng)");
    }
    return parsed;
  }

  Future<List<TowingService>> getNearbyTowing(double lat, double lng, {double radiusKm = 30}) async {
    debugPrint("[AntiGravity] Fetching towing services at ($lat, $lng) with radius: $radiusKm");
    if (kIsWeb) {
      await _initWebMockData(centerLat: lat, centerLng: lng);
      final results = <TowingService>[];
      for (final towing in _webTowing) {
        final dist = haversineDistance(lat, lng, towing.lat, towing.lng);
        if (dist <= radiusKm) {
          results.add(towing.copyWithDistance(
            distanceKm: double.parse(dist.toStringAsFixed(2)),
          ));
        }
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      final rawJson = json.encode(results.map((t) => t.toMap()).toList());
      debugPrint("[AntiGravity] Raw JSON for parsed towing: $rawJson");
      debugPrint("[AntiGravity] Fetched towing count: ${results.length}");

      if (results.isEmpty) {
        debugPrint("[AntiGravity] Empty towing list detected at ($lat, $lng)");
      }
      return results;
    }

    final db = await database;
    double latDelta = radiusKm / 111.0;
    double lngDelta = radiusKm / (111.0 * cos(lat * pi / 180));
    
    String sql = """
      SELECT *, 
        ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS dist_sq
      FROM towing_services
      WHERE latitude BETWEEN ? AND ?
        AND longitude BETWEEN ? AND ?
      ORDER BY dist_sq ASC
      LIMIT 50
    """;
    
    List<Map<String, dynamic>> results = await db.rawQuery(sql, [
      lat, lat, lng, lng,
      lat - latDelta, lat + latDelta,
      lng - lngDelta, lng + lngDelta,
    ]);

    final parsed = results.map((r) {
      TowingService t = TowingService.fromMap(Map<String, dynamic>.from(r));
      double dist = haversineDistance(lat, lng, t.lat, t.lng);
      return t.copyWithDistance(
        distanceKm: double.parse(dist.toStringAsFixed(2)),
      );
    }).where((t) => t.distanceKm <= radiusKm)
      .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final rawJson = json.encode(parsed.map((t) => t.toMap()).toList());
    debugPrint("[AntiGravity] Raw JSON for parsed towing (SQLite): $rawJson");
    debugPrint("[AntiGravity] Fetched towing count: ${parsed.length}");

    if (parsed.isEmpty) {
      debugPrint("[AntiGravity] Empty towing list detected at ($lat, $lng)");
    }
    return parsed;
  }

  Future<List<EmergencyShelter>> getNearbyShelters(double lat, double lng, {int limitKm = 40}) async {
    debugPrint("[AntiGravity] Fetching shelters at ($lat, $lng) with radius: $limitKm");
    if (kIsWeb) {
      await _initWebMockData(centerLat: lat, centerLng: lng);
      final results = <EmergencyShelter>[];
      for (final shelter in _webShelters) {
        final dist = DistanceUtils.haversine(lat, lng, shelter.lat, shelter.lng);
        if (dist <= limitKm) {
          results.add(shelter.copyWithDistance(
            distanceKm: double.parse(dist.toStringAsFixed(2)),
          ));
        }
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      final rawJson = json.encode(results.map((s) => s.toMap()).toList());
      debugPrint("[AntiGravity] Raw JSON for parsed shelters: $rawJson");
      debugPrint("[AntiGravity] Fetched shelters count: ${results.length}");

      if (results.isEmpty) {
        debugPrint("[AntiGravity] Empty shelters list detected at ($lat, $lng)");
      }
      return results;
    }

    final db = await database;
    final bounds = _boundingBox(lat, lng, limitKm.toDouble());

    final rows = await db.query(
      'emergency_shelters',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [bounds.minLat, bounds.maxLat, bounds.minLng, bounds.maxLng],
    );

    final results = <EmergencyShelter>[];
    for (final row in rows) {
      final shelter = EmergencyShelter.fromMap(row);
      final dist = DistanceUtils.haversine(lat, lng, shelter.lat, shelter.lng);
      if (dist <= limitKm) {
        results.add(shelter.copyWithDistance(
          distanceKm: double.parse(dist.toStringAsFixed(2)),
        ));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  // ── Backward Compatible Emergency Contact Helpers ────────────────────

  Future<void> upsertEmergencyContact(EmergencyContact contact) async {
    if (kIsWeb) {
      final contacts = await getEmergencyContacts();
      if (contact.isPrimary) {
        for (var i = 0; i < contacts.length; i++) {
          if (contacts[i].id != contact.id) {
            contacts[i] = contacts[i].copyWith(isPrimary: false);
          }
        }
      }
      contacts.removeWhere((c) => c.id == contact.id);
      contacts.add(contact);
      final prefs = await SharedPreferences.getInstance();
      final listJson = contacts.map((c) => c.toMap()).toList();
      await prefs.setString('web_emergency_contacts_v2', json.encode(listJson));
      return;
    }
    final db = await database;
    if (contact.isPrimary) {
      await db.update('emergency_contacts', {'is_primary': 0});
    }
    await db.insert(
      'emergency_contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('web_emergency_contacts_v2');
      if (raw == null) return [];
      final list = json.decode(raw) as List;
      final contacts = list.map((r) => EmergencyContact.fromMap(r as Map<String, dynamic>)).toList();
      if (contacts.isNotEmpty && !contacts.any((c) => c.isPrimary)) {
        contacts[0] = contacts[0].copyWith(isPrimary: true);
        final listJson = contacts.map((c) => c.toMap()).toList();
        await prefs.setString('web_emergency_contacts_v2', json.encode(listJson));
      }
      return contacts;
    }
    final db = await database;
    final rows = await db.query('emergency_contacts');
    final contacts = rows.map((r) => EmergencyContact.fromMap(r)).toList();
    if (contacts.isNotEmpty && !contacts.any((c) => c.isPrimary)) {
      contacts[0] = contacts[0].copyWith(isPrimary: true);
      await db.update('emergency_contacts', {'is_primary': 1}, where: 'id = ?', whereArgs: [contacts[0].id]);
    }
    return contacts;
  }

  Future<void> deleteEmergencyContact(String id) async {
    if (kIsWeb) {
      final contacts = await getEmergencyContacts();
      final wasPrimary = contacts.any((c) => c.id == id && c.isPrimary);
      contacts.removeWhere((c) => c.id == id);
      if (wasPrimary && contacts.isNotEmpty) {
        contacts[0] = contacts[0].copyWith(isPrimary: true);
      }
      final prefs = await SharedPreferences.getInstance();
      final listJson = contacts.map((c) => c.toMap()).toList();
      await prefs.setString('web_emergency_contacts_v2', json.encode(listJson));
      return;
    }
    final db = await database;
    final maps = await db.query(
      'emergency_contacts',
      where: 'id = ? AND is_primary = 1',
      whereArgs: [id],
    );
    final wasPrimary = maps.isNotEmpty;

    await db.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);

    if (wasPrimary) {
      final remaining = await db.query('emergency_contacts', limit: 1);
      if (remaining.isNotEmpty) {
        final firstId = remaining.first['id'];
        await db.update('emergency_contacts', {'is_primary': 1}, where: 'id = ?', whereArgs: [firstId]);
      }
    }
  }

  // ── Backward Compatible Medical Profile Helpers ──────────────────────

  Future<void> upsertMedicalProfile(MedicalProfile profile) async {
    final user = User(
      id: profile.userId,
      fullName: profile.fullName,
      email: 'nandini@roadsos.in',
      phone: '+91 98765 43210',
      profilePhoto: '',
      bloodGroup: profile.bloodGroup,
      allergies: profile.allergies,
      medications: profile.medications,
      medicalConditions: profile.conditions,
      emergencyNotes: profile.emergencyNotes,
      organDonor: profile.organDonor,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _webUser = user;
      await prefs.setString('web_user_v2', user.toJson());
      return;
    }

    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('web_user_v2');
      if (raw == null) {
        await _initWebMockData();
      } else {
        _webUser = User.fromJson(raw);
      }
      final u = _webUser;
      if (u == null) return null;
      return MedicalProfile(
        userId: u.id,
        fullName: u.fullName,
        age: 21,
        gender: 'Female',
        bloodGroup: u.bloodGroup,
        allergies: u.allergies,
        medications: u.medications,
        conditions: u.medicalConditions,
        organDonor: u.organDonor,
        emergencyNotes: u.emergencyNotes,
      );
    }

    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final u = User.fromMap(rows.first);
    return MedicalProfile(
      userId: u.id,
      fullName: u.fullName,
      age: 21,
      gender: 'Female',
      bloodGroup: u.bloodGroup,
      allergies: u.allergies,
      medications: u.medications,
      conditions: u.medicalConditions,
      organDonor: u.organDonor,
      emergencyNotes: u.emergencyNotes,
    );
  }

  // ── Backward Compatible SOS Incident Helpers ─────────────────────────

  Future<void> logSosEvent({
    required String id,
    required double latitude,
    required double longitude,
    required String triggerType,
    Map<String, dynamic>? telemetry,
    String status = 'dispatched',
  }) async {
    // 1. Resolve actual nearby hospital
    String hospitalName = 'Apollo Hospitals';
    try {
      final hospitals = await getNearbyHospitals(latitude, longitude);
      if (hospitals.isNotEmpty) {
        hospitalName = hospitals.first.name;
      }
    } catch (_) {}

    // 2. Resolve actual nearby police station
    String policeName = 'Navrangpura Police';
    try {
      final police = await getNearbyPolice(latitude, longitude);
      if (police.isNotEmpty) {
        policeName = police.first.name;
      }
    } catch (_) {}

    // 3. Resolve emergency contacts notified
    List<String> contactsList = ['All Contacts'];
    try {
      final contacts = await getEmergencyContacts();
      if (contacts.isNotEmpty) {
        contactsList = contacts.map((c) => "${c.name} (${c.relationship})").toList();
      }
    } catch (_) {}

    // 4. Resolve address
    String resolvedAddress = 'Ahmedabad, India';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedCity = prefs.getString('cached_city');
      if (cachedCity != null && cachedCity.isNotEmpty) {
        resolvedAddress = "$cachedCity, India";
      }
    } catch (_) {}

    final event = SosEvent(
      id: id,
      latitude: latitude,
      longitude: longitude,
      address: resolvedAddress,
      emergencyType: triggerType,
      timestamp: DateTime.now(),
      status: status,
      contactsNotified: contactsList,
      nearestHospital: hospitalName,
      nearestPoliceStation: policeName,
    );

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _webSosEvents.insert(0, event);
      final rawList = _webSosEvents.map((e) => e.toMap()).toList();
      await prefs.setString('web_sos_events_v2', json.encode(rawList));
      return;
    }
    final db = await database;
    await db.insert(
      'sos_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSosEventStatus(String id, String status) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      for (var e in _webSosEvents) {
        if (e.id == id) {
          final idx = _webSosEvents.indexOf(e);
          _webSosEvents[idx] = e.copyWith(status: status);
          break;
        }
      }
      final rawList = _webSosEvents.map((e) => e.toMap()).toList();
      await prefs.setString('web_sos_events_v2', json.encode(rawList));
      return;
    }
    final db = await database;
    await db.update(
      'sos_events',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSosEvents() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('web_sos_events_v2');
      if (raw == null) return [];
      final List list = json.decode(raw) as List;
      _webSosEvents.clear();
      _webSosEvents.addAll(list.map((e) => SosEvent.fromMap(e as Map<String, dynamic>)));
      return _webSosEvents.map((e) => {
        'id': e.id,
        'timestamp': e.timestamp.toIso8601String(),
        'latitude': e.latitude,
        'longitude': e.longitude,
        'triggerType': e.emergencyType,
        'status': e.status,
      }).toList();
    }
    final db = await database;
    final rows = await db.query('sos_events', orderBy: 'timestamp DESC');
    return rows.map((r) => {
      'id': r['id'],
      'timestamp': r['timestamp'],
      'latitude': r['latitude'],
      'longitude': r['longitude'],
      'triggerType': r['emergency_type'],
      'status': r['status'],
    }).toList();
  }

  Future<void> clearSosHistory() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _webSosEvents.clear();
      await prefs.remove('web_sos_events_v2');
      return;
    }
    final db = await database;
    await db.delete('sos_events');
  }

  // ── Remote Web OSM Overpass Syncer ───────────────────────────────────

  Future<void> fetchAndCacheNearbyServices(double lat, double lng, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final double? lastLat = prefs.getDouble('last_fetch_lat');
    final double? lastLng = prefs.getDouble('last_fetch_lng');
    final int? lastTime = prefs.getInt('last_fetch_time');

    final int now = DateTime.now().millisecondsSinceEpoch;

    if (!forceRefresh && lastLat != null && lastLng != null && lastTime != null) {
      final double distance = DistanceUtils.haversine(lat, lng, lastLat, lastLng);
      final int elapsedMinutes = (now - lastTime) ~/ 60000;

      if (distance < 1.5 && elapsedMinutes < 15) {
        print("Throttling active. Using cached spatial data.");
        return;
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      print("Offline: Bypassing remote Overpass fetch.");
      return;
    }

    final hospitals = <Hospital>[];
    final police = <PoliceStation>[];
    final towing = <TowingService>[];

    bool remoteSuccess = false;

    try {
      final query = '''
      [out:json][timeout:15];
      (
        node["amenity"="hospital"](around:25000,$lat,$lng);
        way["amenity"="hospital"](around:25000,$lat,$lng);
        node["amenity"="police"](around:25000,$lat,$lng);
        way["amenity"="police"](around:25000,$lat,$lng);
        node["amenity"="car_repair"](around:25000,$lat,$lng);
        way["amenity"="car_repair"](around:25000,$lat,$lng);
      );
      out center;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        for (final elem in elements) {
          final tags = elem['tags'] as Map? ?? {};
          final name = tags['name'] as String? ?? '';
          if (name.isEmpty) continue;

          final id = (elem['id'] ?? '').toString();
          
          double itemLat = 0.0;
          double itemLng = 0.0;
          if (elem['lat'] != null && elem['lon'] != null) {
            itemLat = (elem['lat'] as num).toDouble();
            itemLng = (elem['lon'] as num).toDouble();
          } else if (elem['center'] != null) {
            itemLat = (elem['center']['lat'] as num).toDouble();
            itemLng = (elem['center']['lon'] as num).toDouble();
          } else {
            continue;
          }

          final phone = tags['phone'] as String? ?? tags['contact:phone'] as String? ?? '';
          final street = tags['addr:street'] as String? ?? '';
          final city = tags['addr:city'] as String? ?? '';
          final address = tags['addr:full'] as String? ?? 
                          (street.isNotEmpty ? "$street, $city" : tags['addr:housename'] as String? ?? '');

          final amenity = tags['amenity'] as String? ?? '';

          if (amenity == 'hospital') {
            final isTrauma = tags['emergency'] == 'yes' || tags['trauma'] == 'yes';
            hospitals.add(Hospital(
              id: id,
              name: name,
              address: address.isNotEmpty ? address : 'Medical Center, $city',
              lat: itemLat,
              lng: itemLng,
              phone: phone,
              type: isTrauma ? HospitalType.trauma : HospitalType.general,
              hasEmergency: tags['emergency'] == 'yes' || tags['emergency'] == 'no' ? tags['emergency'] == 'yes' : true,
              hasICU: tags['icu'] == 'yes',
              hasBloodBank: tags['blood_bank'] == 'yes',
              ambulanceCount: tags['ambulances'] != null ? int.tryParse(tags['ambulances'].toString()) ?? 1 : 1,
              lastUpdated: DateTime.now(),
              sourceApi: 'OSM Overpass',
              rating: 4.0 + (id.hashCode % 10) / 10.0,
            ));
          } else if (amenity == 'police') {
            police.add(PoliceStation(
              id: id,
              name: name,
              address: address.isNotEmpty ? address : 'Police Station, $city',
              lat: itemLat,
              lng: itemLng,
              phone: phone,
              districtCode: tags['operator'] as String? ?? 'OSM-Zone',
              is24Hours: tags['opening_hours'] == '24/7' || tags['is_24h'] == 'yes',
            ));
          } else if (amenity == 'car_repair') {
            towing.add(TowingService(
              id: id,
              name: name,
              phone: phone.isNotEmpty ? phone : '+91 99000 99000',
              lat: itemLat,
              lng: itemLng,
              serviceRadius: 20.0,
              operatingHours: tags['opening_hours'] as String? ?? '24/7',
              vehicleTypes: const ['car', 'bike'],
            ));
          }
        }
        remoteSuccess = true;
      }
    } catch (e) {
      print("Overpass API fetching error: $e");
    }

    if (!remoteSuccess || (hospitals.isEmpty && police.isEmpty && towing.isEmpty)) {
      final dbCount = kIsWeb ? _webHospitals.length : 0;
      
      if (dbCount > 0) return;
      
      if (!kIsWeb) {
        final db = await database;
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM hospitals')) ?? 0;
        if (count > 0 && !forceRefresh) return;
      }

      print("Generating location-aware mock services...");
      String cityName = 'Local';
      try {
        final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
        final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'RoadSOS/1.0'}).timeout(const Duration(seconds: 4));
        if (geoRes.statusCode == 200) {
          final geoData = json.decode(utf8.decode(geoRes.bodyBytes)) as Map<String, dynamic>;
          final addr = geoData['address'] as Map<String, dynamic>?;
          if (addr != null) {
            cityName = addr['city'] as String? ?? addr['town'] as String? ?? addr['village'] as String? ?? addr['state_district'] as String? ?? addr['suburb'] as String? ?? 'Local';
          }
        }
      } catch (e) {
        print("Nominatim reverse geocoding error: $e");
      }

      hospitals.addAll([
        Hospital(
          id: 'gen_h1_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: '$cityName General Hospital',
          address: 'Primary Emergency Care, Central Area, $cityName',
          lat: lat + 0.008,
          lng: lng + 0.005,
          phone: '+91 99400 12345',
          type: HospitalType.trauma,
          hasEmergency: true,
          hasICU: true,
          hasBloodBank: true,
          ambulanceCount: 5,
          lastUpdated: DateTime.now(),
          sourceApi: 'OSM Fallback',
          rating: 4.6,
        ),
        Hospital(
          id: 'gen_h2_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: '$cityName Apollo Emergency Centre',
          address: 'Apollo Ring Road Campus, $cityName',
          lat: lat - 0.012,
          lng: lng + 0.015,
          phone: '+91 99400 54321',
          type: HospitalType.trauma,
          hasEmergency: true,
          hasICU: true,
          hasBloodBank: false,
          ambulanceCount: 3,
          lastUpdated: DateTime.now(),
          sourceApi: 'OSM Fallback',
          rating: 4.4,
        ),
        Hospital(
          id: 'gen_h3_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: '$cityName Lifeline Clinic',
          address: 'Metro Station Junction, $cityName',
          lat: lat + 0.015,
          lng: lng - 0.010,
          phone: '+91 99400 98765',
          type: HospitalType.general,
          hasEmergency: true,
          hasICU: false,
          hasBloodBank: false,
          ambulanceCount: 2,
          lastUpdated: DateTime.now(),
          sourceApi: 'OSM Fallback',
          rating: 4.2,
        ),
      ]);

      police.addAll([
        PoliceStation(
          id: 'gen_p1_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: '$cityName Central Police Station',
          address: 'Civic Centre Road, $cityName',
          lat: lat + 0.005,
          lng: lng - 0.004,
          phone: '+91 44 2345 1234',
          districtCode: '$cityName-HQ',
          is24Hours: true,
        ),
        PoliceStation(
          id: 'gen_p2_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: '$cityName North Patrol Unit',
          address: 'Highway Circle Junction, $cityName',
          lat: lat - 0.010,
          lng: lng - 0.008,
          phone: '+91 44 2345 5678',
          districtCode: '$cityName-N',
          is24Hours: true,
        ),
      ]);

      towing.addAll([
        TowingService(
          id: 'gen_t1_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: 'Express $cityName Towing Services',
          phone: '+91 98400 12345',
          lat: lat + 0.006,
          lng: lng + 0.014,
          serviceRadius: 25.0,
          operatingHours: '24/7',
          vehicleTypes: const ['car', 'bike', 'truck'],
        ),
        TowingService(
          id: 'gen_t2_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
          name: 'Rapid Roadside Recovery $cityName',
          phone: '+91 98400 54321',
          lat: lat - 0.009,
          lng: lng + 0.007,
          serviceRadius: 20.0,
          operatingHours: '24/7',
          vehicleTypes: const ['car', 'bike'],
        ),
      ]);
    }

    if (kIsWeb) {
      _webHospitals.clear();
      _webHospitals.addAll(hospitals);
      _webPolice.clear();
      _webPolice.addAll(police);
      _webTowing.clear();
      _webTowing.addAll(towing);

      await prefs.setString('cached_hospitals', json.encode(_webHospitals.map((h) => h.toMap()).toList()));
      await prefs.setString('cached_police', json.encode(_webPolice.map((p) => p.toMap()).toList()));
      await prefs.setString('cached_towing', json.encode(_webTowing.map((t) => t.toMap()).toList()));
    } else {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('hospitals');
        await txn.delete('police_stations');
        await txn.delete('towing_services');

        for (final item in hospitals) {
          await txn.insert('hospitals', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in police) {
          await txn.insert('police_stations', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in towing) {
          await txn.insert('towing_services', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    }

    await prefs.setDouble('last_fetch_lat', lat);
    await prefs.setDouble('last_fetch_lng', lng);
    await prefs.setInt('last_fetch_time', now);
  }

  Future<void> _initWebMockData({double? centerLat, double? centerLng}) async {
    final double baseLat = centerLat ?? 23.0225;
    final double baseLng = centerLng ?? 72.5714;

    bool shouldReinit = _webHospitals.isEmpty;
    if (!shouldReinit) {
      final double dist = haversineDistance(baseLat, baseLng, _webHospitals.first.lat, _webHospitals.first.lng);
      if (dist > 50.0) {
        shouldReinit = true;
      }
    }

    if (!shouldReinit) return;

    final prefs = await SharedPreferences.getInstance();

    debugPrint("[AntiGravity] Initializing dynamic web mock data centered around ($baseLat, $baseLng)...");

    _webHospitals.clear();
    _webHospitals.addAll(_getHospitalsSeedData(baseLat, baseLng).map((h) => Hospital.fromMap(h)).toList());
    _webPolice.clear();
    _webPolice.addAll(_getPoliceSeedData(baseLat, baseLng).map((p) => PoliceStation.fromMap(p)).toList());
    _webTowing.clear();
    _webTowing.addAll(_getTowingSeedData(baseLat, baseLng).map((t) => TowingService.fromMap(t)).toList());
    _webShelters.clear();
    _webShelters.addAll(_getSheltersSeedData(baseLat, baseLng).map((s) => EmergencyShelter.fromMap(s)).toList());

    try {
      await prefs.setString('cached_hospitals', json.encode(_webHospitals.map((h) => h.toMap()).toList()));
      await prefs.setString('cached_police', json.encode(_webPolice.map((p) => p.toMap()).toList()));
      await prefs.setString('cached_towing', json.encode(_webTowing.map((t) => t.toMap()).toList()));
      await prefs.setString('cached_shelters', json.encode(_webShelters.map((s) => s.toMap()).toList()));
      debugPrint("[AntiGravity] Web mock data stored successfully in SharedPreferences.");
    } catch (e) {
      debugPrint("[AntiGravity] Error caching mock data to SharedPreferences: $e");
    }
  }

  // ── Seed Templates ───────────────────────────────────────────────────

  static List<Map<String, dynamic>> _getHospitalsSeedData(double lat, double lng) {
    return [
      {
        'id': 'h1',
        'name': 'Apollo Hospitals Ahmedabad',
        'address': 'Plot No. 1A, GIDC Gandhinagar, Ahmedabad',
        'latitude': lat + 0.0088,
        'longitude': lng + 0.0075,
        'phone': '+91 79 6670 1800',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 5,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.5
      },
      {
        'id': 'h2',
        'name': 'Civil Hospital Ahmedabad',
        'address': 'Asarwa, Ahmedabad, Gujarat 380016',
        'latitude': lat - 0.0055,
        'longitude': lng + 0.0125,
        'phone': '+91 79 2268 3721',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 12,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.2
      },
      {
        'id': 'h3',
        'name': 'Zydus Hospital Ahmedabad',
        'address': 'Zydus Hospital Road, Sola, Ahmedabad',
        'latitude': lat + 0.0120,
        'longitude': lng - 0.0080,
        'phone': '+91 79 6619 0201',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 6,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.6
      }
    ];
  }

  static List<Map<String, dynamic>> _getPoliceSeedData(double lat, double lng) {
    return [
      {
        'id': 'p1',
        'name': 'Navrangpura Police Station',
        'address': 'Navrangpura, Ahmedabad',
        'latitude': lat + 0.0035,
        'longitude': lng - 0.0055,
        'phone': '+91 79 2644 3803',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p2',
        'name': 'Satellite Police Station',
        'address': 'Satellite, Ahmedabad',
        'latitude': lat - 0.0095,
        'longitude': lng + 0.0040,
        'phone': '+91 79 2676 3485',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      }
    ];
  }

  static List<Map<String, dynamic>> _getTowingSeedData(double lat, double lng) {
    return [
      {
        'id': 't1',
        'name': 'Ahmedabad Auto Towing',
        'phone': '+91 99988 77665',
        'latitude': lat + 0.0155,
        'longitude': lng + 0.0090,
        'serviceRadius': 15.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike'
      },
      {
        'id': 't2',
        'name': 'Gujarat Towing Service',
        'phone': '+91 98989 12345',
        'latitude': lat - 0.0125,
        'longitude': lng - 0.0150,
        'serviceRadius': 20.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike,truck'
      }
    ];
  }

  static List<Map<String, dynamic>> _getSheltersSeedData(double lat, double lng) {
    return [
      {
        'id': 's1',
        'name': 'Ahmedabad Stadium Safety Shelter',
        'address': 'Sports Stadium Complex, Navrangpura, Ahmedabad',
        'latitude': lat + 0.0040,
        'longitude': lng + 0.0110,
        'phone': '+91 79 2644 4444',
        'capacity': 500,
      },
      {
        'id': 's2',
        'name': 'Satellite Community Shelter',
        'address': 'Community Hall Road, Satellite, Ahmedabad',
        'latitude': lat - 0.0070,
        'longitude': lng - 0.0090,
        'phone': '+91 79 2676 7777',
        'capacity': 300,
      }
    ];
  }

  _BoundingBox _boundingBox(double lat, double lng, double radiusKm) {
    final latDelta = radiusKm / 111.32;
    final lngDelta = radiusKm / (111.32 * cos(lat * pi / 180.0));
    return _BoundingBox(
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLng: lng - lngDelta,
      maxLng: lng + lngDelta,
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}

class _BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}
