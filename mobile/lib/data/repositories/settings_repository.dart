import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/settings.dart';

class SettingsRepository {
  final DatabaseHelper _db;

  SettingsRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieves the current app settings, falling back to SharedPreferences on Web or if DB is empty.
  Future<Settings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Support web or shared preference fallback values
    final bool voice = prefs.getBool('voice_activation_enabled') ?? false;
    final bool dark = prefs.getBool('dark_mode_enabled') ?? true;
    final bool share = prefs.getBool('auto_share_enabled') ?? true;
    final bool ai = prefs.getBool('ai_chatbot_enabled') ?? true;
    final int countdown = prefs.getInt('sos_countdown_seconds') ?? 5;
    final bool crash = prefs.getBool('crash_detection_enabled') ?? false;

    if (kIsWeb) {
      return Settings(
        voiceSosEnabled: voice,
        darkMode: dark,
        emergencyAutoShare: share,
        aiAssistantEnabled: ai,
        sosCountdown: countdown,
        crashDetectionEnabled: crash,
      );
    }

    try {
      final db = await _db.database;
      final rows = await db.query('settings', where: "id = 'default'", limit: 1);
      if (rows.isEmpty) {
        final defaultSettings = Settings(
          voiceSosEnabled: voice,
          darkMode: dark,
          emergencyAutoShare: share,
          aiAssistantEnabled: ai,
          sosCountdown: countdown,
          crashDetectionEnabled: crash,
        );
        await db.insert('settings', defaultSettings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        return defaultSettings;
      }
      return Settings.fromMap(rows.first);
    } catch (_) {
      return Settings(
        voiceSosEnabled: voice,
        darkMode: dark,
        emergencyAutoShare: share,
        aiAssistantEnabled: ai,
        sosCountdown: countdown,
        crashDetectionEnabled: crash,
      );
    }
  }

  /// Saves updated settings both to SQLite database and SharedPreferences for dual redundancy.
  Future<void> saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_activation_enabled', settings.voiceSosEnabled);
    await prefs.setBool('dark_mode_enabled', settings.darkMode);
    await prefs.setBool('auto_share_enabled', settings.emergencyAutoShare);
    await prefs.setBool('ai_chatbot_enabled', settings.aiAssistantEnabled);
    await prefs.setInt('sos_countdown_seconds', settings.sosCountdown);
    await prefs.setBool('crash_detection_enabled', settings.crashDetectionEnabled);

    if (kIsWeb) return;

    try {
      final db = await _db.database;
      await db.insert(
        'settings',
        settings.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("SettingsRepository save error: $e");
    }
  }

  /// Retrieves record counts across spatial and SOS logs.
  Future<int> getDatabaseRecordCount() async {
    return await _db.getDatabaseRecordCount();
  }

  /// Retrieves file footprint sizes on native filesystems.
  Future<int> getDatabaseSizeInBytes() async {
    return await _db.getDatabaseSizeInBytes();
  }

  /// Refreshes demo data templates.
  Future<void> syncDatabaseDemoData() async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.delete('hospitals');
    await db.delete('police_stations');
    await db.delete('towing_services');
    await _db.seedDemoData(db);
  }
}
