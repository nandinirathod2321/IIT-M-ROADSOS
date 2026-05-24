import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'roadsos.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await seedDemoData(db);
      },
    );
  }

  /// Public entry point — ensures the database and all tables exist.
  Future<void> initialize() async {
    final db = await database;
    // Auto-create sos_events table if it doesn't exist (seeding/safety support)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sos_events (
        id          TEXT PRIMARY KEY,
        timestamp   TEXT NOT NULL,
        latitude    REAL NOT NULL,
        longitude   REAL NOT NULL,
        triggerType TEXT NOT NULL,
        telemetry   TEXT,
        status      TEXT DEFAULT 'dispatched'
      )
    ''');

    // Ensure email column exists in emergency_contacts (self-healing migration)
    try {
      await db.execute('ALTER TABLE emergency_contacts ADD COLUMN email TEXT');
    } catch (_) {}

    // Ensure age & gender columns exist in medical_profiles (self-healing migration)
    try {
      await db.execute('ALTER TABLE medical_profiles ADD COLUMN age INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE medical_profiles ADD COLUMN gender TEXT');
    } catch (_) {}

    // Auto-seed if hospitals are empty to guarantee spatial queries work
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM hospitals'),
    );
    if (count == null || count == 0) {
      await seedDemoData(db);
    }
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
        email        TEXT,
        isPrimary    INTEGER DEFAULT 0,
        avatarEmoji  TEXT DEFAULT '👤'
      )
    ''');

    // ── Medical profile ─────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE medical_profiles (
        userId             TEXT PRIMARY KEY,
        fullName           TEXT,
        age                INTEGER,
        gender             TEXT,
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

    // ── SOS Events ──────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sos_events (
        id          TEXT PRIMARY KEY,
        timestamp   TEXT NOT NULL,
        latitude    REAL NOT NULL,
        longitude   REAL NOT NULL,
        triggerType TEXT NOT NULL,
        telemetry   TEXT,
        status      TEXT DEFAULT 'dispatched'
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

  // ── SOS Events CRUD ──────────────────────────────────────────────────

  /// Logs a new SOS event.
  Future<void> logSosEvent({
    required String id,
    required double latitude,
    required double longitude,
    required String triggerType,
    Map<String, dynamic>? telemetry,
    String status = 'dispatched',
  }) async {
    final db = await database;
    await db.insert(
      'sos_events',
      {
        'id': id,
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'triggerType': triggerType,
        'telemetry': telemetry != null ? json.encode(telemetry) : null,
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates the status of an SOS event (e.g. to 'resolved').
  Future<void> updateSosEventStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'sos_events',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns all logged SOS events.
  Future<List<Map<String, dynamic>>> getSosEvents() async {
    final db = await database;
    return await db.query('sos_events', orderBy: 'timestamp DESC');
  }

  // ── Database diagnostics and offline updates ─────────────────────────

  Future<int> getDatabaseRecordCount() async {
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
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'roadsos.db');
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future<void> seedDemoData(Database db) async {
    final batch = db.batch();

    // Hospitals (20 Real Landmark Facilities across Ahmedabad & India Metro Centers)
    final hospitals = [
      {
        'id': 'h1',
        'name': 'Apollo Hospitals Ahmedabad',
        'address': 'Plot No. 1A, GIDC Gandhinagar, Ahmedabad',
        'lat': 23.1028,
        'lng': 72.6025,
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
        'lat': 23.0512,
        'lng': 72.6033,
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
        'lat': 23.0610,
        'lng': 72.5255,
        'phone': '+91 79 6619 0201',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 6,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.6
      },
      {
        'id': 'h4',
        'name': 'Shalby Hospitals Ahmedabad',
        'address': 'Opp. Karnavati Club, S.G. Road, Ahmedabad',
        'lat': 23.0222,
        'lng': 72.5085,
        'phone': '+91 79 4020 3000',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 4,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.4
      },
      {
        'id': 'h5',
        'name': 'KD Hospital Ahmedabad',
        'address': 'S.G. Road, Vaishnodevi Circle, Ahmedabad',
        'lat': 23.1145,
        'lng': 72.5401,
        'phone': '+91 79 6677 0000',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 5,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.7
      },
      {
        'id': 'h6',
        'name': 'Sterling Hospital Ahmedabad',
        'address': 'Sterling Hospital Road, Gurukul, Ahmedabad',
        'lat': 23.0505,
        'lng': 72.5412,
        'phone': '+91 79 4001 1111',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 4,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.3
      },
      {
        'id': 'h7',
        'name': 'CIMS Hospital Ahmedabad',
        'address': 'Off Science City Road, Sola, Ahmedabad',
        'lat': 23.0682,
        'lng': 72.5188,
        'phone': '+91 79 2771 2771',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 6,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.6
      },
      {
        'id': 'h8',
        'name': 'HCG Cancer Centre Ahmedabad',
        'address': 'Sola-Science City Road, Sola, Ahmedabad',
        'lat': 23.0245,
        'lng': 72.5065,
        'phone': '+91 79 4041 0101',
        'type': 'clinic',
        'hasEmergency': 0,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 2,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.5
      },
      {
        'id': 'h9',
        'name': 'Rajasthan Hospital Ahmedabad',
        'address': 'Shahibaug, Ahmedabad',
        'lat': 23.0450,
        'lng': 72.6010,
        'phone': '+91 79 2286 6311',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 3,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.1
      },
      {
        'id': 'h10',
        'name': 'VS General Hospital Ahmedabad',
        'address': 'Ellisbridge, Ahmedabad',
        'lat': 23.0185,
        'lng': 72.5702,
        'phone': '+91 79 2657 7621',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 8,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.0
      },
      {
        'id': 'h11',
        'name': 'SAL Hospital Ahmedabad',
        'address': 'Drive-In Road, Thaltej, Ahmedabad',
        'lat': 23.0425,
        'lng': 72.5250,
        'phone': '+91 79 6611 5611',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 5,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.4
      },
      {
        'id': 'h12',
        'name': 'UN Mehta Institute of Cardiology',
        'address': 'Civil Hospital Campus, Asarwa, Ahmedabad',
        'lat': 23.0518,
        'lng': 72.6045,
        'phone': '+91 79 2268 4200',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 10,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.7
      },
      {
        'id': 'h13',
        'name': 'LG Hospital Ahmedabad',
        'address': 'Maninagar, Ahmedabad',
        'lat': 23.0035,
        'lng': 72.6085,
        'phone': '+91 79 2292 2321',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 6,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.0
      },
      {
        'id': 'h14',
        'name': 'Shardaben Hospital Ahmedabad',
        'address': 'Saraspur, Ahmedabad',
        'lat': 23.0315,
        'lng': 72.6080,
        'phone': '+91 79 2292 1421',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 0,
        'ambulanceCount': 4,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 3.9
      },
      {
        'id': 'h15',
        'name': 'GCS Medical College & Hospital',
        'address': 'Opp. DRM Office, Naroda Road, Ahmedabad',
        'lat': 23.0355,
        'lng': 72.6075,
        'phone': '+91 79 6604 8000',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 5,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.2
      },
      {
        'id': 'h16',
        'name': 'Lilavati Hospital Mumbai',
        'address': 'A-791, Bandra Reclamation, Bandra West, Mumbai',
        'lat': 19.0512,
        'lng': 72.8258,
        'phone': '+91 22 2675 1000',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 5,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.5
      },
      {
        'id': 'h17',
        'name': 'Kokilaben Dhirubhai Ambani Hospital Mumbai',
        'address': 'Rao Saheb Achutrao Patwardhan Marg, Four Bungalows, Andheri West, Mumbai',
        'lat': 19.1311,
        'lng': 72.8252,
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 7,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.6
      },
      {
        'id': 'h18',
        'name': 'AIIMS New Delhi',
        'address': 'Ansari Nagar, New Delhi',
        'lat': 28.5672,
        'lng': 77.2100,
        'phone': '+91 11 2658 8500',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 15,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.5
      },
      {
        'id': 'h19',
        'name': 'Safdarjung Hospital Delhi',
        'address': 'Ansari Nagar East, New Delhi',
        'lat': 28.5695,
        'lng': 77.2078,
        'phone': '+91 11 2673 0000',
        'type': 'trauma',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 12,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.1
      },
      {
        'id': 'h20',
        'name': 'Civil Hospital Gandhinagar',
        'address': 'Sector 12, Gandhinagar',
        'lat': 23.2185,
        'lng': 72.6512,
        'phone': '+91 79 2322 1931',
        'type': 'general',
        'hasEmergency': 1,
        'hasICU': 1,
        'hasBloodBank': 1,
        'ambulanceCount': 4,
        'lastUpdated': DateTime.now().toIso8601String(),
        'sourceApi': 'OSM',
        'rating': 4.2
      }
    ];

    for (var h in hospitals) {
      batch.insert('hospitals', h, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Police Stations (10 Real Emergency Jurisdictions)
    final police = [
      {
        'id': 'p1',
        'name': 'Navrangpura Police Station',
        'address': 'Navrangpura, Ahmedabad',
        'lat': 23.0360,
        'lng': 72.5615,
        'phone': '+91 79 2644 3803',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p2',
        'name': 'Satellite Police Station',
        'address': 'Satellite, Ahmedabad',
        'lat': 23.0275,
        'lng': 72.5285,
        'phone': '+91 79 2676 3485',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p3',
        'name': 'Vastrapur Police Station',
        'address': 'Vastrapur, Ahmedabad',
        'lat': 23.0392,
        'lng': 72.5312,
        'phone': '+91 79 2679 8831',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p4',
        'name': 'Ellisbridge Police Station',
        'address': 'Ellisbridge, Ahmedabad',
        'lat': 23.0210,
        'lng': 72.5695,
        'phone': '+91 79 2657 8421',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p5',
        'name': 'Naranpura Police Station',
        'address': 'Naranpura, Ahmedabad',
        'lat': 23.0608,
        'lng': 72.5528,
        'phone': '+91 79 2743 4567',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p6',
        'name': 'Paldi Police Station',
        'address': 'Paldi, Ahmedabad',
        'lat': 23.0125,
        'lng': 72.5610,
        'phone': '+91 79 2657 9821',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p7',
        'name': 'Sarkhej Police Station',
        'address': 'Sarkhej, Ahmedabad',
        'lat': 22.9812,
        'lng': 72.5015,
        'phone': '+91 79 2682 0331',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p8',
        'name': 'Vejalpur Police Station',
        'address': 'Vejalpur, Ahmedabad',
        'lat': 23.0025,
        'lng': 72.5312,
        'phone': '+91 79 2682 8421',
        'districtCode': 'AHD-W',
        'is24Hours': 1
      },
      {
        'id': 'p9',
        'name': 'Bandra Police Station Mumbai',
        'address': 'Hill Road, Bandra West, Mumbai',
        'lat': 19.0560,
        'lng': 72.8315,
        'phone': '+91 22 2642 1212',
        'districtCode': 'MUM-W',
        'is24Hours': 1
      },
      {
        'id': 'p10',
        'name': 'Chanakyapuri Police Station New Delhi',
        'address': 'Chanakyapuri, New Delhi',
        'lat': 28.5992,
        'lng': 77.1915,
        'phone': '+91 11 2410 1234',
        'districtCode': 'DEL-C',
        'is24Hours': 1
      }
    ];

    for (var p in police) {
      batch.insert('police_stations', p, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Towing Services (10 Towing / Heavy Crane Providers)
    final towing = [
      {
        'id': 't1',
        'name': 'Ahmedabad Auto Towing',
        'phone': '+91 99988 77665',
        'lat': 23.0185,
        'lng': 72.5595,
        'serviceRadius': 15.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike'
      },
      {
        'id': 't2',
        'name': 'Gujarat Towing Service',
        'phone': '+91 98989 12345',
        'lat': 23.0425,
        'lng': 72.5855,
        'serviceRadius': 20.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike,truck'
      },
      {
        'id': 't3',
        'name': 'SafeRide Towing Ahmedabad',
        'phone': '+91 97234 56789',
        'lat': 23.0012,
        'lng': 72.5122,
        'serviceRadius': 25.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car'
      },
      {
        'id': 't4',
        'name': 'Maruti Roadside Assistance',
        'phone': '+91 95432 10987',
        'lat': 23.0512,
        'lng': 72.5398,
        'serviceRadius': 15.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike'
      },
      {
        'id': 't5',
        'name': 'Shreeji Towing Ahmedabad',
        'phone': '+91 98250 12345',
        'lat': 23.0285,
        'lng': 72.5512,
        'serviceRadius': 20.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car'
      },
      {
        'id': 't6',
        'name': 'Quick Rescue Towing',
        'phone': '+91 94260 98765',
        'lat': 23.0695,
        'lng': 72.5712,
        'serviceRadius': 18.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike,truck'
      },
      {
        'id': 't7',
        'name': 'Express Crane Services',
        'phone': '+91 98980 54321',
        'lat': 23.0255,
        'lng': 72.5812,
        'serviceRadius': 30.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,truck'
      },
      {
        'id': 't8',
        'name': 'Mumbai Rapid Towing',
        'phone': '+91 98200 98765',
        'lat': 19.0622,
        'lng': 72.8425,
        'serviceRadius': 25.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,bike'
      },
      {
        'id': 't9',
        'name': 'Delhi Highways Assistance',
        'phone': '+91 98110 12345',
        'lat': 28.6112,
        'lng': 77.2185,
        'serviceRadius': 30.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car,truck'
      },
      {
        'id': 't10',
        'name': 'Capital Towing Gandhinagar',
        'phone': '+91 99099 12345',
        'lat': 23.2115,
        'lng': 72.6312,
        'serviceRadius': 15.0,
        'operatingHours': '24/7',
        'vehicleTypes': 'car'
      }
    ];

    for (var t in towing) {
      batch.insert('towing_services', t, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Emergency Contacts (with valid email fields seeded)
    final contacts = [
      {
        'id': 'c1',
        'name': 'Amit Patel',
        'relationship': 'Father',
        'phone': '+91 98765 43210',
        'email': 'amit.patel@example.com',
        'isPrimary': 1,
        'avatarEmoji': '👨'
      },
      {
        'id': 'c2',
        'name': 'Priya Patel',
        'relationship': 'Mother',
        'phone': '+91 98765 43211',
        'email': 'priya.patel@example.com',
        'isPrimary': 0,
        'avatarEmoji': '👩'
      }
    ];

    for (var c in contacts) {
      batch.insert('emergency_contacts', c, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
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
