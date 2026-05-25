import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _db;

  UserRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieves the active User profile by [id].
  Future<User?> getUser(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('web_user_v2');
      if (raw == null) return null;
      return User.fromJson(raw);
    }

    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  /// Inserts or replaces User profile telemetry.
  Future<void> saveUser(User user) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_user_v2', user.toJson());
      return;
    }

    final db = await _db.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
