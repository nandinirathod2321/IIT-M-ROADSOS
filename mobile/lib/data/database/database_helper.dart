import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/distance_utils.dart';
import '../models/hospital.dart';
import '../models/police_station.dart';
import '../models/towing_service.dart';
import '../models/emergency_contact.dart';
import '../models/medical_profile.dart';

/// Singleton helper that owns the SQLite database lifecycle for RoadSOS.
///
/// Tables created:
///   • `hospitals`
///   • `police_stations`
///   • `towing_services`
///   • `emergency_contacts`
///   • `medical_profiles`
///
/// Spatial queries use the Haversine formula (computed in Dart after a
/// coarse bounding-box filter in SQL) and indexes on `lat`/`lng`
/// columns for fast pre-filtering.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  /// Returns the open database, initialising it on first call.
  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  // ── Initialisation ───────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'road_sos.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Public entry point — ensures the database and all tables exist.
  Future<void> initialize() async {
    await database;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── Hospitals ────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE hospitals (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        address        TEXT,
        lat            REAL NOT NULL,
        lng            REAL NOT NULL,
        phone          TEXT,
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
    batch.execute('CREATE INDEX idx_hospitals_lat ON hospitals (lat)');
    batch.execute('CREATE INDEX idx_hospitals_lng ON hospitals (lng)');

    // ── Police stations ─────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE police_stations (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        address      TEXT,
        lat          REAL NOT NULL,
        lng          REAL NOT NULL,
        phone        TEXT,
        districtCode TEXT,
        is24Hours    INTEGER DEFAULT 1
      )
    ''');
    batch.execute('CREATE INDEX idx_police_lat ON police_stations (lat)');
    batch.execute('CREATE INDEX idx_police_lng ON police_stations (lng)');

    // ── Towing services ─────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE towing_services (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        phone          TEXT,
        lat            REAL NOT NULL,
        lng            REAL NOT NULL,
        serviceRadius  REAL DEFAULT 0.0,
        operatingHours TEXT,
        vehicleTypes   TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_towing_lat ON towing_services (lat)');
    batch.execute('CREATE INDEX idx_towing_lng ON towing_services (lng)');

    // ── Emergency contacts ──────────────────────────────────────────
    batch.execute('''
      CREATE TABLE emergency_contacts (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        relationship TEXT,
        phone        TEXT NOT NULL,
        isPrimary    INTEGER DEFAULT 0,
        avatarEmoji  TEXT DEFAULT '👤'
      )
    ''');

    // ── Medical profile ─────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE medical_profiles (
        userId             TEXT PRIMARY KEY,
        fullName           TEXT,
        bloodGroup         TEXT,
        allergies          TEXT,
        medications        TEXT,
        conditions         TEXT,
        emergencyContactId TEXT,
        insuranceProvider  TEXT,
        insurancePolicyNo  TEXT,
        organDonor         INTEGER DEFAULT 0
      )
    ''');

    await batch.commit(noResult: true);
  }

  // ── Seeding ──────────────────────────────────────────────────────────

  /// Seeds the database from a bundled JSON asset file.
  ///
  /// Expected JSON structure:
  /// ```json
  /// {
  ///   "hospitals": [...],
  ///   "police_stations": [...],
  ///   "towing_services": [...]
  /// }
  /// ```
  Future<void> seedFromJson(String jsonPath) async {
    final db = await database;
    final raw = await rootBundle.loadString(jsonPath);
    final data = json.decode(raw) as Map<String, dynamic>;

    final batch = db.batch();

    if (data.containsKey('hospitals')) {
      for (final item in data['hospitals'] as List) {
        final hospital = Hospital.fromMap(item as Map<String, dynamic>);
        batch.insert('hospitals', hospital.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data.containsKey('police_stations')) {
      for (final item in data['police_stations'] as List) {
        final station =
            PoliceStation.fromMap(item as Map<String, dynamic>);
        batch.insert('police_stations', station.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data.containsKey('towing_services')) {
      for (final item in data['towing_services'] as List) {
        final towing =
            TowingService.fromMap(item as Map<String, dynamic>);
        batch.insert('towing_services', towing.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    await batch.commit(noResult: true);
  }

  // ── Spatial queries ──────────────────────────────────────────────────

  /// Returns hospitals within [limitKm] of ([lat], [lng]), sorted by
  /// ascending Haversine distance.
  ///
  /// A coarse bounding-box filter is applied in SQL first so that
  /// only nearby rows are loaded into memory for precise calculation.
  Future<List<Hospital>> getNearbyHospitals(
    double lat,
    double lng, {
    int limitKm = 50,
  }) async {
    final db = await database;
    final bounds = _boundingBox(lat, lng, limitKm.toDouble());

    final rows = await db.query(
      'hospitals',
      where: 'lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?',
      whereArgs: [bounds.minLat, bounds.maxLat, bounds.minLng, bounds.maxLng],
    );

    final results = <Hospital>[];
    for (final row in rows) {
      final hospital = Hospital.fromMap(row);
      final dist =
          DistanceUtils.haversine(lat, lng, hospital.lat, hospital.lng);
      if (dist <= limitKm) {
        results.add(hospital.copyWithDistance(
          distanceKm: double.parse(dist.toStringAsFixed(2)),
          estimatedMinutes: double.parse(
              DistanceUtils.estimateMinutes(dist).toStringAsFixed(1)),
        ));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  /// Returns police stations within [limitKm] of ([lat], [lng]),
  /// sorted by ascending Haversine distance.
  Future<List<PoliceStation>> getNearbyPolice(
    double lat,
    double lng, {
    int limitKm = 20,
  }) async {
    final db = await database;
    final bounds = _boundingBox(lat, lng, limitKm.toDouble());

    final rows = await db.query(
      'police_stations',
      where: 'lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?',
      whereArgs: [bounds.minLat, bounds.maxLat, bounds.minLng, bounds.maxLng],
    );

    final results = <PoliceStation>[];
    for (final row in rows) {
      final station = PoliceStation.fromMap(row);
      final dist =
          DistanceUtils.haversine(lat, lng, station.lat, station.lng);
      if (dist <= limitKm) {
        results.add(station.copyWithDistance(
          distanceKm: double.parse(dist.toStringAsFixed(2)),
        ));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  /// Returns towing services within [limitKm] of ([lat], [lng]),
  /// sorted by ascending Haversine distance.
  Future<List<TowingService>> getNearbyTowing(
    double lat,
    double lng, {
    int limitKm = 30,
  }) async {
    final db = await database;
    final bounds = _boundingBox(lat, lng, limitKm.toDouble());

    final rows = await db.query(
      'towing_services',
      where: 'lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?',
      whereArgs: [bounds.minLat, bounds.maxLat, bounds.minLng, bounds.maxLng],
    );

    final results = <TowingService>[];
    for (final row in rows) {
      final towing = TowingService.fromMap(row);
      final dist =
          DistanceUtils.haversine(lat, lng, towing.lat, towing.lng);
      if (dist <= limitKm) {
        results.add(towing.copyWithDistance(
          distanceKm: double.parse(dist.toStringAsFixed(2)),
        ));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  // ── Emergency contacts CRUD ──────────────────────────────────────────

  /// Inserts or replaces an emergency contact.
  Future<void> upsertEmergencyContact(EmergencyContact contact) async {
    final db = await database;
    await db.insert(
      'emergency_contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all saved emergency contacts.
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final db = await database;
    final rows = await db.query('emergency_contacts');
    return rows.map((r) => EmergencyContact.fromMap(r)).toList();
  }

  /// Deletes an emergency contact by [id].
  Future<void> deleteEmergencyContact(String id) async {
    final db = await database;
    await db.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Medical profile CRUD ─────────────────────────────────────────────

  /// Inserts or replaces the user's medical profile.
  Future<void> upsertMedicalProfile(MedicalProfile profile) async {
    final db = await database;
    await db.insert(
      'medical_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the stored medical profile, or `null` if none exists.
  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    final db = await database;
    final rows = await db.query(
      'medical_profiles',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MedicalProfile.fromMap(rows.first);
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Computes a coarse lat/lng bounding box for a radius in km.
  /// This is used to pre-filter rows in SQL before applying the
  /// more expensive Haversine formula in Dart.
  _BoundingBox _boundingBox(double lat, double lng, double radiusKm) {
    // ~111.32 km per degree of latitude
    final latDelta = radiusKm / 111.32;
    // Longitude degrees vary with latitude
    final lngDelta = radiusKm / (111.32 * cos(lat * pi / 180.0));
    return _BoundingBox(
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLng: lng - lngDelta,
      maxLng: lng + lngDelta,
    );
  }

  /// Closes the database connection.
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
