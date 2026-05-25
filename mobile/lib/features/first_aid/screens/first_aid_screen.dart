import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/gemini_service.dart';

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

  /// Sends a message and triggers the local AI medical engine
  Future<void> _handleSendMessage([String? forcedText]) async {
    final query = forcedText ?? _messageController.text.trim();
    if (query.isEmpty || query == "Listening...") return;

    _messageController.clear();
    _stopListening();

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    // Store turn in conversational memory
    _aiHistory.add({'role': 'user', 'text': query});
    if (_aiHistory.length > 10) {
      _aiHistory.removeRange(0, _aiHistory.length - 10);
    }

    String responseText = '';
    bool isOfflineFallback = false;

    try {
      // Direct live Gemini API call
      responseText = await _geminiService.generateEmergencyResponse(
        userMessage: query,
        chatHistory: _aiHistory,
      );
    } catch (e) {
      // Graceful fallback to offline local guide logic
      isOfflineFallback = true;
      final offlineResponse = _getResponseForQuery(query);
      responseText = "⚠️ **[Offline Fallback Mode]**\n\n$offlineResponse";
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: responseText, isUser: false, timestamp: DateTime.now()));
        _isTyping = false;
      });
      _scrollToBottom();

      // Only save success replies to active conversation memory
      if (!isOfflineFallback) {
        _aiHistory.add({'role': 'model', 'text': responseText});
        if (_aiHistory.length > 10) {
          _aiHistory.removeRange(0, _aiHistory.length - 10);
        }
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

  /// Direct offline medically accurate keyword-based NLP response selector
  String _getResponseForQuery(String query) {
    final q = query.toLowerCase();

    if (q.contains("cpr") || q.contains("cardiopulmonary") || q.contains("resuscitation")) {
      return "🚨 CPR BASICS (Cardiopulmonary Resuscitation)\n\n"
          "If the victim is unresponsive and not breathing, start CPR immediately:\n\n"
          "1. **POSITION**: Place the victim flat on their back on a firm surface. Kneel next to their shoulders.\n"
          "2. **HANDS**: Place the heel of one hand in the center of their chest (sternum). Interlock your other hand on top.\n"
          "3. **COMPRESSIONS**: Push hard and fast at a rate of 100 to 120 compressions per minute (e.g. to the beat of 'Staying Alive'). Push down 2 inches deep. Give 30 compressions.\n"
          "4. **BREATHS**: Pinch their nose, tilt their chin back, and give 2 quick rescue breaths. Make sure their chest rises.\n"
          "5. **RATIO**: Keep repeating the cycle of **30 compressions followed by 2 breaths** until help arrives.\n\n"
          "⚠️ **CRITICAL DIRECTIVE**: Call emergency services (112 or 100) immediately before starting chest compressions if possible!";
    }

    if (q.contains("bleed") || q.contains("bleeding") || q.contains("blood") || q.contains("hemorrhage")) {
      return "🩸 HEMORRHAGE & BLEEDING CONTROL\n\n"
          "Follow these steps immediately to prevent severe blood loss:\n\n"
          "1. **DIRECT PRESSURE**: Place a sterile gauze or clean cloth directly on the wound. Press down firmly and continuously.\n"
          "2. **ELEVATION**: Keep the pressure applied and raise the bleeding limb above heart level (if no bone break is suspected).\n"
          "3. **SECURE**: Tie the cloth securely with a bandage. If blood soaks through, add another layer on top instead of removing the first.\n"
          "4. **TOURNIQUET**: If bleeding is severe and life-threatening on an arm or leg, apply a tourniquet 2 inches above the wound (never on joints). Tighten until bleeding stops.\n\n"
          "⚠️ Keep the patient lying flat, warm, and quiet to prevent shock.";
    }

    if (q.contains("heart attack") || q.contains("cardiac") || q.contains("chest pain")) {
      return "🫀 HEART ATTACK GUIDELINES\n\n"
          "Signs include chest tightness, radiating arm or jaw pain, sweating, and difficulty breathing:\n\n"
          "1. **ALERT**: Call 108 or 112 instantly.\n"
          "2. **SIT & COMFORT**: Help them sit down on the floor leaning back against a wall. This reduces the strain on the heart.\n"
          "3. **LOOSEN**: Loosen collar buttons, belts, or tight clothes.\n"
          "4. **ASPIRIN**: If conscious and not allergic, have them chew 1 standard tablet of Aspirin (300mg) slowly.\n"
          "5. **MONITOR**: Stay beside them. Be prepared to start CPR immediately if they lose consciousness or stop breathing.";
    }

    if (q.contains("burn") || q.contains("burns") || q.contains("scald")) {
      return "🔥 EMERGENCY BURN TREATMENT\n\n"
          "Do NOT apply butter, toothpaste, grease, or ice:\n\n"
          "1. **COOL**: Run cool (lukewarm) tap water over the burn area for 10 to 20 minutes. Never use ice or freezing water.\n"
          "2. **REMOVE CONSTRUCTIONS**: Remove rings, watches, or tight clothes before the area swells.\n"
          "3. **COVER WOUND**: Wrap loosely with sterile plastic wrap, clean cling wrap, or non-stick dressings. Do not apply tight bandages.\n"
          "4. **AVOID BLISTERS**: Do not pop or pierce any blisters. Do not apply direct pressure.\n\n"
          "⚠️ **SAFETY BANNER**: For major chemical or high-degree burns, contact professional dispatchers immediately.";
    }

    if (q.contains("fracture") || q.contains("bone") || q.contains("break") || q.contains("splint")) {
      return "🦴 FRACTURE & SPLINT HANDLING\n\n"
          "Do NOT attempt to push or realign a broken bone back in:\n\n"
          "1. **IMMOBILIZE**: Keep the broken bone completely still. Do not let the patient move the limb.\n"
          "2. **SUPPORT**: Place wood, splints, or stiff cardboard underneath and bind it gently with bandages to prevent movement.\n"
          "3. **ICE PACK**: Apply a cold pack wrapped in a cloth to ease swelling and dull severe pain.\n"
          "4. **WOUNDS**: If bone has pierced the skin, cover gently with sterile wrap. Do not touch or wash the exposed bone.";
    }

    if (q.contains("snake") || q.contains("bite") || q.contains("snakebite")) {
      return "🐍 SNAKE BITE EMERGENCY FIRST-AID\n\n"
          "Do NOT suck out venom, cut the wound, or apply ice:\n\n"
          "1. **KEEP CALM**: Prevent movement. Agitation increases blood flow and spreads venom through the lymphatic stream.\n"
          "2. **BELOW HEART**: Position the bitten limb lower than or level with the heart.\n"
          "3. **REMOVE CONSTRICTIONS**: Take off tight jewelry, rings, and shoes because swelling will start rapidly.\n"
          "4. **CLEAN & DRESS**: Wash the bite gently with water. Wrap a loose bandage around the area.\n"
          "5. **ANTI-VENOM**: Transport immediately to an Ahmedabad trauma facility with anti-venom!";
    }

    if (q.contains("poison") || q.contains("poisoning") || q.contains("chemical")) {
      return "⚠️ POISONING FIRST AID\n\n"
          "Do NOT induce vomiting unless explicitly directed by clinical dispatchers:\n\n"
          "1. **SWALLOWED**: If they are conscious, rinse their mouth out. Do not give water or milk to drink.\n"
          "2. **INHALED**: Carry the victim into open fresh air immediately. Begin breathing assistance if they choke.\n"
          "3. **EYES/SKIN**: Flush affected skin or eyes with continuous running water for 15-20 minutes.\n"
          "4. **IDENTIFY**: Locate the container, pill bottles, or labels to show first responders. Call 112 immediately.";
    }

    if (q.contains("accident") || q.contains("crash") || q.contains("first aid")) {
      return "🚗 ROAD ACCIDENT SAFETY PROTOCOL\n\n"
          "Ensure your own safety first before attempting to help others:\n\n"
          "1. **SECURE SCENE**: Park safely, put on warning flashers, and look out for leaks or fire.\n"
          "2. **DO NOT MOVE VICTIMS**: Unless there is a fire threat, keep victims in their seats to prevent spinal injury.\n"
          "3. **STOP BLEEDING**: Apply firm pressure on bleeding wounds.\n"
          "4. **CALL RESPONDERS**: Trigger the RoadSOS SOS broadcast for Ahmedabad response support.";
    }

    if (q.contains("panic") || q.contains("anxiety") || q.contains("panic attack")) {
      return "🧘 PANIC ATTACK SOOTHING STEPS\n\n"
          "Follow these steps to help someone through a panic attack:\n\n"
          "1. **STAY CALM**: Do not panic. Speak in a quiet, low, reassuring tone.\n"
          "2. **BREATHING**: Guide them to take deep, slow breaths: breathe in for 4 seconds, hold for 4, breathe out for 4.\n"
          "3. **GROUNDING**: Ask them to name 5 things they see, 4 things they can touch, 3 things they hear, 2 they smell, and 1 they taste.\n"
          "4. **SAFE SPACE**: Move them away from crowds, bright lights, or noise to a quiet spot.\n"
          "5. **SUPPORT**: Reassure them that panic attacks are temporary and they are safe.";
    }

    if (q.contains("choking") || q.contains("choke") || q.contains("heimlich")) {
      return "💨 CHOKING EMERGENCY (Heimlich Maneuver)\n\n"
          "If the victim cannot speak, cough, or breathe, perform first aid instantly:\n\n"
          "1. **5 BACK BLOWS**: Stand behind them. Lean them forward. Give 5 firm blows between their shoulder blades with the heel of your hand.\n"
          "2. **5 ABDOMINAL THRUSTS**: Wrap your arms around their waist. Make a fist with one hand, place it just above their belly button, grasp it with your other hand, and pull in and up quickly.\n"
          "3. **REPEAT**: Alternate between **5 back blows and 5 abdominal thrusts** until the blockage is cleared.\n"
          "4. **UNCONSCIOUS**: If they pass out, lower them gently to the floor and start CPR compressions.";
    }

    return "🩺 RoadSOS Emergency AI Assistant\n\n"
        "I am currently operating fully offline to guarantee instant responses during critical situations.\n\n"
        "I didn't quite catch that. Try asking about these topics:\n"
        "• 'How to stop bleeding'\n"
        "• 'CPR chest compressions'\n"
        "• 'Cardiac / Heart attack'\n"
        "• 'Snake bite protocol'\n"
        "• 'First aid for burns'\n"
        "• 'Fractures & splinting'\n"
        "• 'Choking protocol'\n"
        "• 'Panic attack steps'\n\n"
        "⚠️ **SAFETY ALERT**: Always contact professional emergency services (112 or 100) immediately.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
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
          color: AppColors.emergencyRed.withOpacity(0.12),
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
            child: Row(
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
            color: message.isUser ? AppColors.borderSubtle : AppColors.emergencyRed.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTypography.bodyMedium.copyWith(
                color: message.isUser ? Colors.white : AppColors.textPrimary,
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
              color: AppColors.emergencyAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.emergencyAmber.withOpacity(0.3)),
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
        data: ThemeData.dark().copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: iconColor, size: 24),
          title: Text(
            title,
            style: AppTypography.headlineMedium.copyWith(fontSize: 15, color: Colors.white),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
