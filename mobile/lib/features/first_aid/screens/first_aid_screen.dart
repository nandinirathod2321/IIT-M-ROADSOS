import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/repositories/ai_chat_repository.dart';
import '../../../data/models/chat_message.dart' as db_model;
import 'package:uuid/uuid.dart';

/// Message model mapping chat history items.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Implements a fully featured offline-online hybrid AI Emergency Assistant and First Aid screen.
/// Includes dynamic keyword-matching medical responders, voice speech-to-text recorders,
/// typing simulations, action chips, and complete downloadable offline emergency guides.
class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0 = AI Assistant, 1 = Offline Guides

  // Chat configurations
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final GeminiService _geminiService = GeminiService();
  final AiChatRepository _chatRepo = AiChatRepository();
  final List<Map<String, String>> _aiHistory = [];

  // Speech integration
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Pulse animation controller for the active microphone state
  late AnimationController _micPulseController;
  late Animation<double> _micPulseAnim;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _micPulseAnim = Tween<double>(begin: 0.9, end: 1.3).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );

    // Seed default welcome message
    _messages.add(
      ChatMessage(
        text: "Hello! I am your RoadSOS First Aid Assistant. How can I guide you during this emergency?\n\n"
            "Feel free to ask questions like:\n"
            "• 'CPR steps'\n"
            "• 'How to stop bleeding'\n"
            "• 'Heart attack guidelines'\n"
            "• 'Burns first aid'",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    _initSpeech();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final currentUserId = AuthService.instance.currentUserId ?? 'me';
      final history = await _chatRepo.getChatHistory(currentUserId);
      if (history.isNotEmpty) {
        setState(() {
          _messages.clear();
          for (var h in history) {
            if (h.userMessage.isNotEmpty) {
              _messages.add(ChatMessage(text: h.userMessage, isUser: true, timestamp: h.timestamp));
              _aiHistory.add({'role': 'user', 'text': h.userMessage});
            }
            if (h.aiResponse.isNotEmpty) {
              _messages.add(ChatMessage(text: h.aiResponse, isUser: false, timestamp: h.timestamp));
              _aiHistory.add({'role': 'model', 'text': h.aiResponse});
            }
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      AppLogger.warning('Failed to load chat history', e);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  /// Initialises local device speech services
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && _isListening) {
            setState(() {
              _isListening = false;
              _micPulseController.stop();
            });
          }
        },
        onError: (err) {
          setState(() {
            _isListening = false;
            _micPulseController.stop();
          });
        },
      );
      setState(() {
        _speechAvailable = available;
      });
    } catch (_) {
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  /// Toggles speech listening stream
  void _toggleListening() async {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  /// Starts device mic capture
  void _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Microphone permission is required or speech services are unavailable.",
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.emergencyAmber,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _messageController.text = "Listening...";
      });
      _micPulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });
        },
      );
    } catch (_) {
      setState(() {
        _isListening = false;
        _micPulseController.stop();
      });
    }
  }

  /// Stops device mic capture
  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _micPulseController.stop();
    });
  }

  String _formatChatError(Object error) {
    if (error is NetworkException) {
      return '⚠️ Connection problem\n\n${error.message}\n\nCheck internet and try again.';
    }
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 401 || code == 403) {
        return '⚠️ API key invalid\n\nConfigure Gemini in Settings or .env.';
      }
      return '⚠️ AI unavailable\n\n${error.message}';
    }
    return '⚠️ Could not get AI response\n\n${error.toString().replaceFirst('Exception: ', '')}';
  }

  bool _isApiKeyError(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      return code == 401 || code == 403;
    }
    final s = error.toString().toLowerCase();
    return s.contains('api key') || s.contains('not configured');
  }

  /// Sends a message to Gemini and streams the response into the chat.
  Future<void> _handleSendMessage([String? forcedText]) async {
    if (_isTyping) return;
    final query = forcedText ?? _messageController.text.trim();
    if (query.isEmpty || query == "Listening...") return;

    _messageController.clear();
    _stopListening();

    AppLogger.info('First aid AI: user message sent (${query.length} chars).');

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    final historyForApi = List<Map<String, String>>.from(_aiHistory);
    final int aiMessageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false, timestamp: DateTime.now()));
    });

    String streamedText = '';
    var success = false;

    try {
      final stream = _geminiService.streamEmergencyResponse(
        userMessage: query,
        chatHistory: historyForApi,
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        streamedText += chunk;
        setState(() {
          _messages[aiMessageIndex] = ChatMessage(
            text: streamedText,
            isUser: false,
            timestamp: DateTime.now(),
          );
        });
        _scrollToBottom();
      }

      if (streamedText.trim().isEmpty) {
        throw const ApiException('Received an empty response from AI model.');
      }
      success = true;
      AppLogger.info('First aid AI: response received (${streamedText.length} chars).');
    } catch (e) {
      AppLogger.error('First aid AI stream failed', e);
      if (mounted) {
        final isKey = _isApiKeyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKey
                  ? 'Gemini API key is missing or invalid. Configure it in Settings.'
                  : 'Could not reach AI assistant. Check your connection.',
            ),
            backgroundColor: isKey ? AppColors.emergencyRed : AppColors.emergencyAmber,
          ),
        );
        setState(() {
          _isTyping = false;
          _messages[aiMessageIndex] = ChatMessage(
            text: _formatChatError(e),
            isUser: false,
            timestamp: DateTime.now(),
          );
        });
        _scrollToBottom();
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isTyping = false;
    });
    _scrollToBottom();

    _aiHistory.add({'role': 'user', 'text': query});
    _aiHistory.add({'role': 'model', 'text': streamedText});
    if (_aiHistory.length > 20) {
      _aiHistory.removeRange(0, _aiHistory.length - 20);
    }

    if (success) {
      try {
        final currentUserId = AuthService.instance.currentUserId ?? 'me';
        final modelMsg = db_model.ChatMessageModel(
          id: const Uuid().v4(),
          userId: currentUserId,
          userMessage: query,
          aiResponse: streamedText,
          timestamp: DateTime.now(),
        );
        await _chatRepo.saveChatMessage(modelMsg);
      } catch (e) {
        AppLogger.warning('Failed to save chat history item', e);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'EMERGENCY FIRST AID',
          style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab switches (AI Chat vs Offline Guides)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabHeader(0, "AI Emergency Chat", Icons.chat_bubble_outline_rounded),
                ),
                Expanded(
                  child: _buildTabHeader(1, "Offline Guides", Icons.chrome_reader_mode_outlined),
                ),
              ],
            ),
          ),

          // Main Screen Tab View content
          Expanded(
            child: _activeTab == 0 ? _buildChatbotTab() : _buildOfflineGuidesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emergencyRed : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotTab() {
    return Column(
      children: [
        // 1. High-priority Call Emergency warning banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.emergencyRed.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Icons.emergency_rounded, color: AppColors.emergencyRed, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "⚠️ AI is not a replacement for professional emergency services. Call emergency services (112 or 100) immediately for severe situations.",
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Chat history list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return _buildTypingIndicator();
              }
              final message = _messages[index];
              return _buildChatBubble(message);
            },
          ),
        ),

        // 3. Quick Chip recommendations
        Container(
          height: 42,
          padding: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildQuickChip("CPR"),
              _buildQuickChip("Bleeding"),
              _buildQuickChip("Burns"),
              _buildQuickChip("Fracture"),
              _buildQuickChip("Heart Attack"),
              _buildQuickChip("Choking"),
              _buildQuickChip("Panic Attack"),
            ],
          ),
        ),

        // 4. Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        "AI is not a substitute for professional emergency medical care.",
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Speech-to-text mic overlay
                    AnimatedBuilder(
                      animation: _micPulseAnim,
                      builder: (context, child) {
                        final scale = _isListening ? _micPulseAnim.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening ? AppColors.emergencyRed : AppColors.surfaceAlt,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isListening ? Colors.white : AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: _toggleListening,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Chat text input field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isListening ? "Listening..." : "Ask AI First Aid...",
                          hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.emergencyRed),
                          ),
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send Button
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergencyRed,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: () => _handleSendMessage(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label) {
    return GestureDetector(
      onTap: () => _handleSendMessage(label),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.surfaceAlt : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(message.isUser ? 12 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 12),
          ),
          border: Border.all(
            color: message.isUser ? AppColors.borderSubtle : AppColors.emergencyRed.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                style: AppTypography.bodySmall.copyWith(fontSize: 9, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.emergencyRed,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "AI Emergency Assistant is writing...",
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineGuidesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emergencyAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.emergencyAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.emergencyAmber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "OFFLINE FIRST-AID PROTOCOLS",
                        style: AppTypography.labelCaps.copyWith(
                          color: AppColors.emergencyAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Guides cover CPR, Severe Bleeding, Fractures, Burns, and Poisoning without internet.",
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // "AI EMERGENCY ASSISTANT" card
          Container(
            width: double.infinity,
            height: 80,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                left: BorderSide(color: AppColors.infoBlue, width: 5),
                top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
                right: BorderSide(color: AppColors.borderSubtle, width: 0.5),
                bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
              ),
            ),
            child: InkWell(
              onTap: () => context.push('/first-aid/ai-chat'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "AI EMERGENCY ASSISTANT",
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.infoBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Talk to Gemini AI — real answers for your emergency",
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: AppColors.infoBlue,
                      child: Text(
                        "OPEN CHAT",
                        style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // expandable safety tiles
          _buildGuideTile(
            title: "What to do after a crash",
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.emergencyAmber,
            children: [
              _buildBulletPoint("1. Secure the Scene", "Park your vehicle in a safe spot, turn on hazard lights, and wear high-visibility gear."),
              _buildBulletPoint("2. Assess Hazards", "Check for fuel leaks, smoke, fire, or exposed wiring before approaching the vehicle."),
              _buildBulletPoint("3. Check Responses", "Gently tap victims on the shoulders and ask loudly: 'Are you okay?' to assess consciousness."),
              _buildBulletPoint("4. Alert Responders", "Use RoadSOS to immediately notify the nearest hospital and police control rooms."),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuideTile(
            title: "CPR Basics (Cardiopulmonary Resuscitation)",
            icon: Icons.favorite_rounded,
            iconColor: AppColors.emergencyRed,
            children: [
              _buildBulletPoint("1. Check consciousness", "If victim is unresponsive and not breathing, start CPR immediately."),
              _buildBulletPoint("2. Chest Compressions", "Place both hands in the center of the chest. Push hard and fast at a rate of 100-120 compressions per minute (stay stay stayed at 2 inches deep)."),
              _buildBulletPoint("3. Deliver Breaths", "Pinch nose, tilt head back, and deliver 2 quick rescue breaths after every 30 compressions."),
              _buildBulletPoint("4. Continuous Ratio", "Maintain the 30 compressions to 2 breaths cycle continuously."),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuideTile(
            title: "Severe Bleeding & Hemorrhage Control",
            icon: Icons.opacity_rounded,
            iconColor: AppColors.emergencyRed,
            children: [
              _buildBulletPoint("1. Direct Pressure", "Apply firm, continuous direct pressure directly on the wound with a clean sterile dressing or cloth."),
              _buildBulletPoint("2. Elevate Limb", "Raise the injured limb above the level of the heart to slow arterial pressure."),
              _buildBulletPoint("3. Apply Tourniquet", "For catastrophic limb bleeding, apply a tourniquet 2 inches above the wound. Never place on joints."),
              _buildBulletPoint("4. Prevent Shock", "Keep the victim warm and lying flat with legs slightly elevated."),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuideTile(
            title: "Bone Fractures & Splints",
            icon: Icons.border_clear_rounded,
            iconColor: AppColors.towingOrange,
            children: [
              _buildBulletPoint("1. Do not move", "Immobilize the limb. Do not attempt to push or realign a broken bone back in."),
              _buildBulletPoint("2. Construct Splint", "Support the limb below and above the fracture using rigid cardboard, splint boards, or rolls bound loosely."),
              _buildBulletPoint("3. Cold Pack", "Apply an ice pack wrapped in a cloth to ease severe swelling and pain."),
              _buildBulletPoint("4. Bleeding skin", "If skin broke, cover gently with clean sterile dressings."),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuideTile(
            title: "Burns and Scald Treatment",
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.towingOrange,
            children: [
              _buildBulletPoint("1. Cool Water", "Immediately run cool gentle tap water over the burn for 10 to 20 minutes. Do not use ice."),
              _buildBulletPoint("2. Constrictions", "Take off rings, belts, or jewelry before swelling starts."),
              _buildBulletPoint("3. Loosely Cover", "Wrap loosely with sterile cling wrap or clean dressings to isolate bacteria."),
              _buildBulletPoint("4. Do not pierce", "Avoid popping any blisters or applying oils, toothpastes, or butter."),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuideTile(
            title: "Poisoning Emergencies",
            icon: Icons.warning_rounded,
            iconColor: AppColors.emergencyAmber,
            children: [
              _buildBulletPoint("1. Do not induce vomiting", "Do not force vomit unless explicitly instructed by a dispatch specialist."),
              _buildBulletPoint("2. Rinse Mouth", "If swallowed and conscious, rinse mouth with water. Do not give drinks."),
              _buildBulletPoint("3. Inhaled", "Carry the victim immediately to fresh air. Loosen tight collars."),
              _buildBulletPoint("4. Chemicals", "Flush affected eyes or skin with running water for 15-20 minutes."),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGuideTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Theme(
        data: ThemeData.light().copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: iconColor, size: 24),
          title: Text(
            title,
            style: AppTypography.headlineMedium.copyWith(fontSize: 15, color: AppColors.textPrimary),
          ),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textMuted,
          childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
          children: children,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String boldPart, String normalPart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle_rounded, size: 6, color: AppColors.emergencyRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                children: [
                  TextSpan(
                    text: "$boldPart: ",
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: normalPart),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
