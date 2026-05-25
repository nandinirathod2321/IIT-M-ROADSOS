import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a persistent AI chat history log matching the `ai_chat_history` SQLite table.
class ChatMessageModel extends Equatable {
  final String id;
  final String userId;
  final String userMessage;
  final String aiResponse;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    this.userId = 'me',
    required this.userMessage,
    required this.aiResponse,
    required this.timestamp,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'me',
      userMessage: map['user_message'] as String? ?? '',
      aiResponse: map['ai_response'] as String? ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory ChatMessageModel.fromJson(String source) => 
      ChatMessageModel.fromMap(json.decode(source) as Map<String, dynamic>);

  // ── Copy With ────────────────────────────────────────────────────────

  ChatMessageModel copyWith({
    String? id,
    String? userId,
    String? userMessage,
    String? aiResponse,
    DateTime? timestamp,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, userId, userMessage, aiResponse, timestamp];
}
