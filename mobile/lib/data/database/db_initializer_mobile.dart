import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile SQLite copy initializer
class DbInitializer {
  static Future<void> initialize() async {
    Directory docsDir = await getApplicationDocumentsDirectory();
    String dbPath = join(docsDir.path, 'roadsos.db');

    if (!await File(dbPath).exists()) {
      // Copy sqlite from assets bundle
      ByteData data = await rootBundle.load('assets/roadsos.db');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(dbPath).writeAsBytes(bytes, flush: true);
      print("DbInitializer: SQLite copied to docs: ${bytes.length} bytes");
    } else {
      print("DbInitializer: database already exists at $dbPath");
    }
  }
}
