import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Mobile SQLite copy initializer
class DbInitializer {
  static Future<void> initialize() async {
    Directory docsDir = await getApplicationDocumentsDirectory();
    String dbPath = join(docsDir.path, 'roadsos.db');

    bool dbExists = await File(dbPath).exists();

    if (!dbExists || await _isDatabaseEmpty(dbPath)) {
      // Copy sqlite from assets bundle
      ByteData data = await rootBundle.load('assets/roadsos.db');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(dbPath).writeAsBytes(bytes, flush: true);
      print("RoadSOS DB copied: ${bytes.length} bytes");

      // FIX 4: Add SQLite Indexes
      try {
        Database dbIndex = await openDatabase(dbPath);
        await dbIndex.execute('CREATE INDEX IF NOT EXISTS idx_h_latitude ON hospitals(latitude)');
        await dbIndex.execute('CREATE INDEX IF NOT EXISTS idx_h_longitude ON hospitals(longitude)');
        await dbIndex.execute('CREATE INDEX IF NOT EXISTS idx_p_latitude ON police_stations(latitude)');
        await dbIndex.execute('CREATE INDEX IF NOT EXISTS idx_p_longitude ON police_stations(longitude)');
        await dbIndex.close();
        print("RoadSOS DB: indexes created successfully");
      } catch (e) {
        print("RoadSOS DB: failed to create indexes: $e");
      }
    } else {
      print("RoadSOS DB already exists at $dbPath");
    }

    // Verify hospitals exist
    try {
      Database db = await openDatabase(dbPath, readOnly: true);
      int count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM hospitals')
      ) ?? 0;
      await db.close();
      print('RoadSOS DB ready: $count hospitals loaded');
    } catch (e) {
      print('RoadSOS DB: verification failed: $e');
    }
  }

  static Future<bool> _isDatabaseEmpty(String path) async {
    try {
      Database db = await openDatabase(path, readOnly: true);
      int count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM hospitals')
      ) ?? 0;
      await db.close();
      return count == 0;
    } catch (e) {
      return true;
    }
  }
}
