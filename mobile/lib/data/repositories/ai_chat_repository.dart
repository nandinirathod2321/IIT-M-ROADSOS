import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/chat_message.dart';

class AiChatRepository {
  final DatabaseHelper _db;

  AiChatRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// Retrieves chronological AI assistant conversations for [userId].
  Future<List<ChatMessageModel>> getChatHistory(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('web_ai_chat_history_v2');
      if (raw == null) return [];
      final List list = json.decode(raw) as List;
      return list.map((item) => ChatMessageModel.fromMap(item as Map<String, dynamic>)).toList();
    }

    final db = await _db.database;
    final rows = await db.query(
      'ai_chat_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp ASC',
    );

    return rows.map((r) => ChatMessageModel.fromMap(r)).toList();
  }

  /// Inserts a new chat exchange between user and AI into persistent history logs.
  Future<void> saveChatMessage(ChatMessageModel message) async {
    if (kIsWeb) {
      final history = await getChatHistory(message.userId);
      history.add(message);
      final prefs = await SharedPreferences.getInstance();
      final listJson = history.map((e) => e.toMap()).toList();
      await prefs.setString('web_ai_chat_history_v2', json.encode(listJson));
      return;
    }

    final db = await _db.database;
    await db.insert(
      'ai_chat_history',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Erases chat history entries matching [userId].
  Future<void> clearChatHistory(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_ai_chat_history_v2');
      return;
    }

    final db = await _db.database;
    await db.delete(
      'ai_chat_history',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
