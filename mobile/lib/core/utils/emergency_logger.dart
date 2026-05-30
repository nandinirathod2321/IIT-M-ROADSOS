import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Central emergency logging system for RoadSOS.
/// Formats: [ROADSOS][TIMESTAMP] event
class EmergencyLogger {
  static Future<void> log(String event) async {
    final timestamp = DateTime.now().toIso8601String();
    final formattedLog = "[ROADSOS][$timestamp] $event";
    
    // Print to console in debug mode
    if (kDebugMode) {
      debugPrint(formattedLog);
    }
    
    // In release / non-web platforms, append to a local log file
    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/emergency_logs.txt');
        await file.writeAsString('$formattedLog\n', mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint("Error writing emergency log to file: $e");
      }
    }
  }
}
