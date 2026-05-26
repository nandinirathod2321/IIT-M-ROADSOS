import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/models/chat_message.dart';
import '../../../core/utils/logger.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;

  ChatCubit({
    ChatRepository? repository,
  })  : _repository = repository ?? ChatRepository(),
        super(const ChatState()) {
    _loadInitialMessages();
  }

  void _loadInitialMessages() {
    final cached = _repository.getHistory();
    if (cached.isEmpty) {
      // Add initial welcome message
      final welcome = ChatMessageModel(
        id: 'msg_welcome',
        text: "I'm RoadSOS AI. Tell me what emergency you're dealing with. I'll give you step-by-step instructions.",
        isUser: false,
        timestamp: DateTime.now(),
      );
      _repository.sendChatMessage(welcome.text); // prime the cache
      emit(state.copyWith(
        status: ChatStatus.success,
        messages: [welcome],
      ));
    } else {
      emit(state.copyWith(
        status: ChatStatus.success,
        messages: cached,
      ));
    }
  }

  /// Sends a message and updates the state.
  Future<void> sendMessage(String text, {String? locationContext}) async {
    if (text.trim().isEmpty || state.isLoading) return;

    AppLogger.info('ChatCubit: Emitting loading and sending message...');

    // Emit the loading state while keeping the existing message list (so user sees their prompt immediately)
    final existingMessages = List<ChatMessageModel>.from(state.messages);
    final userMsg = ChatMessageModel(
      id: 'msg_user_temp_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    emit(state.copyWith(
      status: ChatStatus.loading,
      messages: [...existingMessages, userMsg],
      errorMessage: '',
    ));

    try {
      final response = await _repository.sendChatMessage(text, locationContext: locationContext);
      
      if (isClosed) return;

      // Update with the final successfully returned message list from our repository
      emit(state.copyWith(
        status: ChatStatus.success,
        messages: _repository.getHistory(),
      ));
    } catch (e) {
      AppLogger.error('ChatCubit: Send message failed', e);
      if (!isClosed) {
        emit(state.copyWith(
          status: ChatStatus.failure,
          errorMessage: 'Failed to send message: $e',
        ));
      }
    }
  }

  /// Clears the chat history.
  void clearChat() {
    AppLogger.info('ChatCubit: Clearing chat conversation...');
    _repository.clearConversation();
    
    final welcome = ChatMessageModel(
      id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: "I'm RoadSOS AI. Tell me what emergency you're dealing with. I'll give you step-by-step instructions.",
      isUser: false,
      timestamp: DateTime.now(),
    );
    
    emit(state.copyWith(
      status: ChatStatus.success,
      messages: [welcome],
      errorMessage: '',
    ));
  }
}
