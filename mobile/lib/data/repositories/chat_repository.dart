import 'dart:async';
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

  /// Sends a message and returns the response.
  /// Dynamically handles online Gemini requests and offline keywords fail-safes.
  Future<ChatMessageModel> sendChatMessage(String messageText, {String? locationContext}) async {
    AppLogger.info('ChatRepository: Sending message: "$messageText"');

    // 1. Cache the User's Message
    final userMsg = ChatMessageModel(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _inMemoryCache.addChatMessage(userMsg);

    // 2. Check online status
    bool isOffline = false;
    try {
      final conn = await Connectivity().checkConnectivity();
      isOffline = conn.contains(ConnectivityResult.none);
    } catch (_) {}

    if (isOffline) {
      AppLogger.warning('ChatRepository: System is offline. Directing to offline keyword fail-safe engine...');
      final offlineReply = _parseOfflineKeywords(messageText);
      
      final aiMsg = ChatMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: '$offlineReply\n\nNext: Maintain safety and wait for medical professionals.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _inMemoryCache.addChatMessage(aiMsg);
      return aiMsg;
    }

    // 3. Online Gemini API Call
    try {
      // Reformat cache history into Gemini turn mapping
      final history = _inMemoryCache.chatHistory
          .where((m) => !m.isError)
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.text,
              })
          .toList();

      // Include GPS location context if provided
      String queryText = messageText;
      if (locationContext != null && locationContext.isNotEmpty) {
        queryText = '[Location: $locationContext] $messageText';
      }

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
      return aiMsg;

    } catch (e) {
      AppLogger.error('ChatRepository: Online Gemini API failed. Falling back to offline matcher: $e');
      
      // Fallback to offline keyword responder if Gemini fails
      final offlineReply = _parseOfflineKeywords(messageText);
      final aiMsg = ChatMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: '⚠️ [Offline Fallback Mode active due to API timeout/error]\n\n$offlineReply\n\nNext: Tap retry once internet connection stabilizes.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _inMemoryCache.addChatMessage(aiMsg);
      return aiMsg;
    }
  }

  void clearConversation() {
    _inMemoryCache.clearChatHistory();
  }

  /// Specialized Military Medic offline keywords engine
  String _parseOfflineKeywords(String text) {
    final clean = text.toLowerCase();
    
    if (clean.contains('cpr') || clean.contains('breath') || clean.contains('chok')) {
      return '''
🚨 EMERGENCY LIFE SUPPORT (CPR) REQUIRED:
1. Position the victim flat on their back on a firm surface.
2. Place hands in the center of the chest (sternum).
3. Push hard and fast: 100-120 compressions per minute at 2 inches depth.
4. Give 2 rescue breaths after every 30 compressions if trained; otherwise, perform hands-only CPR.
5. Do not stop until professional responders arrive or the victim revives.''';
    }
    
    if (clean.contains('bleed') || clean.contains('blood') || clean.contains('cut') || clean.contains('wound')) {
      return '''
🚨 CRITICAL BLEEDING CONTROL PROCEDURE:
1. Apply direct pressure to the wound using a clean cloth or sterile dressing immediately.
2. Keep continuous firm pressure without lifting the cloth to check.
3. Elevate the injured limb above heart level if possible.
4. If blood soaks through, place another cloth on top. Do not remove the first one.
5. If bleeding is severe and uncontrollable on a limb, apply a tourniquet 2 inches above the wound (never on a joint).''';
    }

    if (clean.contains('unconscious') || clean.contains('faint') || clean.contains('passed out') || clean.contains('respond')) {
      return '''
🚨 UNCONSCIOUSNESS / RESPONSIVENESS GUIDE:
1. Shake the shoulders gently and shout "Are you okay?".
2. Check for breathing (look at chest rising, listen for breath sounds) for 10 seconds.
3. If breathing normally, roll the person onto their side into the Recovery Position to keep the airway open.
4. If not breathing normally, start CPR immediately.
5. Loosen any tight clothing around the neck.''';
    }

    if (clean.contains('fracture') || clean.contains('bone') || clean.contains('break') || clean.contains('sprain')) {
      return '''
🚨 SUSPECTED FRACTURE / SPINAL PROCEDURE:
1. Do not attempt to realign or push back a bone.
2. Immobilize the limb using a splint (rolled cardboard, stick) padded with cloth.
3. Apply a cold pack wrapped in cloth to reduce swelling.
4. If a spinal injury is suspected (accident impact, neck pain), DO NOT move the victim under any circumstances unless they are in immediate danger (fire, drowning). Keep the head and neck completely still.''';
    }

    if (clean.contains('burn') || clean.contains('fire') || clean.contains('scald')) {
      return '''
🚨 EMERGENCY BURN MANAGEMENT:
1. Cool the burn immediately under cool running tap water for at least 10-20 minutes. Never use ice or butter.
2. Remove any jewelry or tight items from the burned area before swelling starts.
3. Cover the burn loosely with a clean, non-stick sterile bandage or cling wrap.
4. Do not pop any blisters.
5. Seek immediate emergency care if the burn is large, on the face, hands, or joints.''';
    }

    if (clean.contains('shock') || clean.contains('pale') || clean.contains('cold')) {
      return '''
🚨 SHOCK MANAGEMENT:
1. Have the person lie down flat on their back.
2. Elevate their feet 12 inches off the ground to assist blood flow to vital organs (unless head, neck, or leg fracture is suspected).
3. Keep the person warm with a blanket or coat.
4. Do not give the person anything to eat or drink.
5. Loosen tight clothing and monitor their breathing continuously.''';
    }

    return '''
🚨 GENERAL ACCIDENT EMERGENCY PROTOCOL:
1. Ensure the accident scene is safe for you and the victim before approaching.
2. Call 112 or 100 immediately to alert emergency services.
3. Keep the victim calm, still, and warm. Avoid moving them unless in immediate danger.
4. Assess responsiveness and monitor breathing continuously.
5. Be ready to administer CPR or apply pressure to heavy bleeding wounds.''';
  }
}
