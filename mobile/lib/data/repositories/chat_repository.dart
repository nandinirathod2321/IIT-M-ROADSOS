import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/logger.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final GeminiService _geminiService;
  final CacheService _inMemoryCache;

  ChatRepository({
    GeminiService? geminiService,
    CacheService? inMemoryCache,
  })  : _geminiService = geminiService ?? GeminiService(),
        _inMemoryCache = inMemoryCache ?? CacheService();

  List<ChatMessageModel> getHistory() {
    return _inMemoryCache.chatHistory;
  }

  /// Sends a message and returns the Gemini AI response.
  Future<ChatMessageModel> sendChatMessage(String messageText, {String? locationContext}) async {
    AppLogger.info('ChatRepository: sending message (${messageText.length} chars).');

    final userMsg = ChatMessageModel(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _inMemoryCache.addChatMessage(userMsg);

    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none)) {
        throw const NetworkException('No active internet connection.');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.warning('ChatRepository: connectivity check failed; continuing.', e);
    }

    final history = _inMemoryCache.chatHistory
        .where((m) => !m.isError)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    // Exclude the user message we just added — GeminiService appends it.
    if (history.isNotEmpty && history.last['role'] == 'user') {
      history.removeLast();
    }

    var queryText = messageText;
    if (locationContext != null && locationContext.isNotEmpty) {
      queryText = '[Location: $locationContext] $messageText';
    }

    try {
      final responseText = await _geminiService.generateEmergencyResponse(
        userMessage: queryText,
        chatHistory: history,
      );

      final aiMsg = ChatMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _inMemoryCache.addChatMessage(aiMsg);
      AppLogger.info('ChatRepository: response received (${responseText.length} chars).');
      return aiMsg;
    } catch (e) {
      AppLogger.error('ChatRepository: Gemini API failed', e);
      final aiMsg = ChatMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: _errorText(e),
        isUser: false,
        isError: true,
        timestamp: DateTime.now(),
      );
      _inMemoryCache.addChatMessage(aiMsg);
      return aiMsg;
    }
  }

  String _errorText(Object error) {
    if (error is NetworkException) {
      return '⚠️ Connection problem: ${error.message}';
    }
    if (error is ApiException) {
      return '⚠️ ${error.message}';
    }
    return '⚠️ Could not get AI response. Please try again.';
  }

  void clearConversation() {
    _inMemoryCache.clearChatHistory();
  }
}
