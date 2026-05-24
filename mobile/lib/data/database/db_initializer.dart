import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Database copy and initialization engine on app startup.
class DbInitializer {
  static Future<void> initialize() async {
    // Skip database initialization on web
    if (kIsWeb) {
      print("Skipping local database initialization on web.");
      return;
    }

    Directory docsDir = await getApplicationDocumentsDirectory();
    String dbPath = join(docsDir.path, 'roadsos.db');

    if (!await File(dbPath).exists()) {
      // First run: copy sqlite pre-populated nodes from assets bundle
      ByteData data = await rootBundle.load('assets/roadsos.db');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(dbPath).writeAsBytes(bytes, flush: true);

      print("Database copied from assets: ${bytes.length} bytes");
    } else {
      print("Database already exists at: $dbPath");
    }
  }
}
