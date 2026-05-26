import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API configuration constants for RoadSOS.
abstract final class ApiConstants {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? "";
  static const String geminiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
}
