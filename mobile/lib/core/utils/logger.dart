import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void debug(String message) {
    debugPrint('[RoadSOS] [DEBUG] $message');
  }

  static void info(String message) {
    debugPrint('[RoadSOS] [INFO] $message');
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[RoadSOS] [WARNING] $message');
    if (error != null) {
      debugPrint('[RoadSOS] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[RoadSOS] StackTrace:\n$stackTrace');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[RoadSOS] [ERROR] $message');
    if (error != null) {
      debugPrint('[RoadSOS] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[RoadSOS] StackTrace:\n$stackTrace');
    }
  }
}
