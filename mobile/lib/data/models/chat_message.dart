import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String id;
  
  // Single message fields (ChatCubit / CacheService)
  final String text;
  final bool isUser;
  final bool isError;
  
  // Paired message fields (first_aid_screen / AiChatRepository / DB)
  final String userId;
  final String userMessage;
  final String aiResponse;
  
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    this.text = '',
    this.isUser = false,
    this.isError = false,
    this.userId = '',
    this.userMessage = '',
    this.aiResponse = '',
    required this.timestamp,
  });

  ChatMessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    bool? isError,
    String? userId,
    String? userMessage,
    String? aiResponse,
    DateTime? timestamp,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isError: isError ?? this.isError,
      userId: userId ?? this.userId,
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId.isNotEmpty ? userId : (isUser ? 'me' : 'ai'),
      'user_message': userMessage.isNotEmpty ? userMessage : (isUser ? text : ''),
      'ai_response': aiResponse.isNotEmpty ? aiResponse : (!isUser ? text : ''),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final String uMsg = map['user_message'] ?? '';
    final String aResp = map['ai_response'] ?? '';
    final bool isUserVal = uMsg.isNotEmpty;
    return ChatMessageModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      userMessage: uMsg,
      aiResponse: aResp,
      text: uMsg.isNotEmpty ? uMsg : aResp,
      isUser: isUserVal,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        isUser,
        isError,
        userId,
        userMessage,
        aiResponse,
        timestamp,
      ];
}
