import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/logger.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class AIChatScreen extends StatefulWidget {
  final String? initialQuestion;

  const AIChatScreen({super.key, this.initialQuestion});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Medically safe static emergency first aid database
  static const String _cprGuidance = 
      "🚨 **CPR & Choking Emergency Guidance**\n\n"
      "**For CPR (Adult not breathing):**\n"
      "1. Call 112 / Emergency services immediately.\n"
      "2. Place the person on their back on a firm, flat surface.\n"
      "3. Position your hands in the center of their chest (heel of one hand, other hand on top with interlocking fingers).\n"
      "4. Perform hard and fast chest compressions: push down 2 inches at a rate of 100 to 120 compressions per minute (e.g., to the beat of 'Stayin' Alive').\n"
      "5. If trained, give 2 rescue breaths after every 30 compressions.\n"
      "6. Continue compressions and breaths until professional responders arrive or an AED is ready.\n\n"
      "**For Choking (Conscious person):**\n"
      "1. Stand behind the person and lean them forward.\n"
      "2. Give 5 sharp back blows between the shoulder blades with the heel of your hand.\n"
      "3. If object is not cleared, perform 5 abdominal thrusts (Heimlich maneuver): make a fist, place it just above the navel, grasp your fist with the other hand, and press hard into the abdomen with a quick upward thrust.\n"
      "4. Alternate 5 back blows and 5 abdominal thrusts until the blockage is cleared or professional rescuers arrive.";

  static const String _bleedingGuidance = 
      "🚨 **Severe Bleeding Emergency Guidance**\n\n"
      "1. Ensure your own safety first (use gloves if available).\n"
      "2. Apply direct pressure to the wound using a clean cloth, sterile dressing, or your hand.\n"
      "3. Maintain firm, continuous pressure for at least 5 to 10 minutes without releasing to check the wound.\n"
      "4. If the bleeding does not stop, apply additional dressings over the first one (do not remove the soaked dressings) and apply firmer pressure.\n"
      "5. If the wound is on a limb and bleeding is life-threatening/uncontrolled, apply a tourniquet 2-3 inches above the wound (never over a joint) and write down the application time.\n"
      "6. Elevate the injured area above the heart if possible and lay the person flat to prevent shock.";

  static const String _fractureGuidance = 
      "🚨 **Fractures & Bone Injuries Emergency Guidance**\n\n"
      "1. Do not attempt to realign the bone or push a protruding bone back in.\n"
      "2. Keep the injured limb completely still. Immobilize the area above and below the injured joint.\n"
      "3. If possible, create a temporary splint using rolled-up magazines, cardboard, or wood, secured with bandages or cloth (do not tie too tightly to restrict circulation).\n"
      "4. Apply a cold compress or ice pack wrapped in a cloth to reduce swelling (do not apply ice directly to skin).\n"
      "5. If a spinal injury is suspected (neck/back pain, numbness, or severe collision impact): DO NOT move the person under any circumstances unless they are in immediate danger of fire/explosion. Keep their head, neck, and spine completely aligned.";

  static const String _burnGuidance = 
      "🚨 **Burns & Thermal Injuries Emergency Guidance**\n\n"
      "1. Stop the burning process immediately (cool water, smother flames).\n"
      "2. Cool the burn using cool, running water for 10 to 20 minutes. Do not use ice, ice water, butter, oils, or ointments as they trap heat and worsen tissue damage.\n"
      "3. Remove jewelry, tight clothing, or belts gently from the burned area before it starts to swell.\n"
      "4. Do not pop any blisters, as intact skin acts as a natural barrier against infection.\n"
      "5. Cover the burn loosely with a sterile, non-adherent dressing, clean cloth, or plastic cling wrap.\n"
      "6. Keep the person warm and seek medical attention for large, deep, or chemical/electrical burns.";

  static const String _unconsciousGuidance = 
      "🚨 **Unconscious & Unresponsive Person Guidance**\n\n"
      "1. Tap their shoulders and shout 'Are you okay?' to check for responsiveness.\n"
      "2. If unresponsive, check their breathing (look for chest rise and feel for breath for 5 to 10 seconds).\n"
      "3. If they are NOT breathing, initiate CPR immediately.\n"
      "4. If they ARE breathing normally, place them in the **Recovery Position**:\n"
      "   - Roll them onto their side.\n"
      "   - Tilt their head slightly backward to keep the airway open and clear.\n"
      "   - Bend their top knee at a 90-degree angle to stabilize their body.\n"
      "5. Keep them warm, do not leave them unattended, and do not try to feed them or give them fluids.";

  static const String _heartAttackGuidance = 
      "🚨 **Heart Attack Emergency Guidance**\n\n"
      "1. Call emergency services (112) immediately.\n"
      "2. Have the person sit down, rest, and remain calm. Sit them in a comfortable position (e.g., leaning against a wall on the floor).\n"
      "3. Loosen any tight clothing around their neck and chest.\n"
      "4. Ask if they carry emergency medication (e.g., Nitroglycerin or Aspirin). If prescribed, assist them in taking it.\n"
      "5. If they are fully conscious, have them chew and swallow a standard adult Aspirin (325mg) or low-dose Aspirins (81mg x 4) if they have no allergy or contraindications.\n"
      "6. Monitor their breathing closely. Prepare to perform CPR instantly if they lose consciousness and stop breathing normally.";

  static const String _strokeGuidance = 
      "🚨 **Stroke Emergency Guidance (FAST Protocol)**\n\n"
      "Identify stroke instantly using the **F.A.S.T.** method:\n"
      "1. **F - Face Drooping:** Ask the person to smile. Does one side of the face droop or feel numb?\n"
      "2. **A - Arm Weakness:** Ask the person to raise both arms. Does one arm drift downward or feel weak/numb?\n"
      "3. **S - Speech Difficulty:** Ask the person to repeat a simple sentence. Is their speech slurred, hard to understand, or are they unable to speak?\n"
      "4. **T - Time to Call 112:** If the person shows any of these symptoms, even if they go away, call emergency services immediately.\n\n"
      "**Rescuer steps while waiting:**\n"
      "- Note the exact time when symptoms first appeared.\n"
      "- Keep the person resting comfortably and do not give them any food, drinks, or medications (especially aspirin/blood thinners, as a stroke could be hemorrhagic).";

  static const String _accidentGuidance = 
      "🚨 **Road Accident Scene Handling Guidance**\n\n"
      "1. **Ensure Safety First:** Park your vehicle safely away from the crash site, turn on hazard lights, and wear high-visibility gear if available.\n"
      "2. **Assess the Scene:** Look for hazards like gas leaks, fires, downed power lines, or oncoming traffic before approaching.\n"
      "3. **Do Not Move Victims:** Never move an injured victim from a vehicle unless there is an immediate, life-threatening danger (e.g., vehicle fire or explosion risk) to prevent spinal paralysis.\n"
      "4. **Call Emergency Responders:** Call 112 immediately with precise details: exact location, number of vehicles, and approximate number/condition of casualties.\n"
      "5. **Triage and Basic Care:** Check for responsiveness and breathing. Control severe bleeding with direct pressure, keep unconscious breathing victims in the recovery position, and keep everyone calm and warm.";

  static const String _menuGuidance = 
      "🚨 **Offline Emergency First Aid Assistant**\n\n"
      "You are currently offline. Here is the structured medical emergency guidance available:\n\n"
      "- **CPR & Choking** (type: `cpr` or `choke`)\n"
      "- **Severe Bleeding** (type: `bleeding` or `blood`)\n"
      "- **Fractures & Spinal Injury** (type: `fracture` or `spinal`)\n"
      "- **Burns & Fire Injuries** (type: `burn`)\n"
      "- **Unconscious Persons** (type: `unconscious` or `recovery`)\n"
      "- **Heart Attack** (type: `heart attack` or `chest pain`)\n"
      "- **Stroke Detection** (type: `stroke` or `fast`)\n"
      "- **Road Accidents Scene Handling** (type: `accident` or `crash`)\n\n"
      "*Type any of the bolded keywords above to retrieve medically safe, structured step-by-step instructions.*";

  static const String _defaultGuidance = 
      "I am currently offline. I can only provide safe instructions for key emergency categories. Type **help** to see all available categories.\n\n"
      "Or type keywords like: **CPR, bleeding, burns, fracture, unconscious, stroke, heart attack, or accident**.";

  final GeminiService _geminiService = GeminiService();
  final List<Map<String, String>> _aiHistory = [];
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isStreaming = false;
  String? _userLocation;

  final List<String> _quickActions = [
    "Person not breathing",
    "Heavy bleeding",
    "Unconscious victim",
    "Possible fracture",
    "Spinal injury",
    "Person in shock",
    "Burns",
    "Child injured",
  ];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isOffline = offline;
        });
      }
    });
    _loadLocation();

    // Add welcome message
    _messages.add(ChatMessage(
      text: "I'm RoadSOS AI. Tell me what emergency you're dealing with. I'll give you step-by-step instructions.",
      isUser: false,
      timestamp: DateTime.now(),
      isError: false,
    ));

    if (widget.initialQuestion != null && widget.initialQuestion!.trim().isNotEmpty) {
      // Pre-send the initial question after 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _sendMessage(widget.initialQuestion!);
        }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      if (mounted) {
        setState(() {
          _userLocation = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      AppLogger.warning('Could not load location in AI Chat', e);
    }
  }

  String _formatErrorMessage(Object error) {
    if (error is NetworkException) {
      return '⚠️ **Connection problem**\n\n${error.message}\n\nCheck internet and tap Retry.';
    }
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 401 || code == 403) {
        return '⚠️ **API key invalid**\n\nConfigure a valid Gemini API key in Settings or .env, then tap Retry.';
      }
      if (code == 429) {
        return '⚠️ **Too many requests**\n\nWait a moment and tap Retry.';
      }
      return '⚠️ **AI unavailable**\n\n${error.message}\n\nTap Retry to try again.';
    }
    final msg = error.toString().replaceFirst('Exception: ', '');
    if (msg.toLowerCase().contains('api key') || msg.toLowerCase().contains('not configured')) {
      return '⚠️ **API key missing**\n\nAdd your Gemini API key in Settings, then tap Retry.';
    }
    return '⚠️ **Something went wrong**\n\n$msg\n\nTap Retry to try again.';
  }

  bool _isApiKeyError(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      return code == 401 || code == 403;
    }
    final s = error.toString().toLowerCase();
    return s.contains('api key') || s.contains('not configured');
  }

  void _showErrorSnackBar(Object error) {
    final isKey = _isApiKeyError(error);
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
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    AppLogger.info('AI chat: user message sent (${text.length} chars).');

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        isError: false,
      ));
      _isLoading = true;
      _isStreaming = false;
      _controller.clear();
    });

    _scrollToBottom();

    if (_isOffline) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        final response = _getOfflineGuidance(text);
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            isError: false,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      });
      return;
    }

    final historyForApi = List<Map<String, String>>.from(_aiHistory);
    var messageToSend = text;
    if (historyForApi.isEmpty && _userLocation != null) {
      messageToSend = 'User location (approx): $_userLocation. $text';
    }

    String streamedText = '';
    int? botMessageIndex;
    StreamSubscription<String>? subscription;

    final stream = _geminiService.streamEmergencyResponse(
      userMessage: messageToSend,
      chatHistory: historyForApi,
    );

    subscription = stream.listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _isStreaming = true;
          streamedText += chunk;
          if (botMessageIndex == null) {
            botMessageIndex = _messages.length;
            _messages.add(ChatMessage(
              text: streamedText,
              isUser: false,
              timestamp: DateTime.now(),
              isError: false,
            ));
          } else {
            _messages[botMessageIndex!] = ChatMessage(
              text: streamedText,
              isUser: false,
              timestamp: DateTime.now(),
              isError: false,
            );
          }
        });
        _scrollToBottom();
      },
      onError: (err) {
        if (!mounted) return;
        AppLogger.error('AI chat stream error', err);
        _showErrorSnackBar(err);

        final errorText = _formatErrorMessage(err);
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          if (botMessageIndex == null) {
            _messages.add(ChatMessage(
              text: errorText,
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ));
          } else {
            _messages[botMessageIndex!] = ChatMessage(
              text: errorText,
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            );
          }
        });
        _scrollToBottom();
        subscription?.cancel();
      },
      onDone: () {
        if (!mounted) return;
        if (streamedText.trim().isEmpty) {
          const emptyError = ApiException('Received an empty response from AI model.');
          AppLogger.error('AI chat: empty stream response');
          _showErrorSnackBar(emptyError);
          final errorText = _formatErrorMessage(emptyError);
          setState(() {
            _isLoading = false;
            _isStreaming = false;
            if (botMessageIndex == null) {
              _messages.add(ChatMessage(
                text: errorText,
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              ));
            } else {
              _messages[botMessageIndex!] = ChatMessage(
                text: errorText,
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              );
            }
          });
          _scrollToBottom();
          subscription?.cancel();
          return;
        }

        AppLogger.info('AI chat: response received (${streamedText.length} chars).');
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
        _scrollToBottom();

        _aiHistory.add({'role': 'user', 'text': text});
        _aiHistory.add({'role': 'model', 'text': streamedText});
        if (_aiHistory.length > 20) {
          _aiHistory.removeRange(0, _aiHistory.length - 20);
        }
        subscription?.cancel();
      },
      cancelOnError: true,
    );
  }

  String _getOfflineGuidance(String query) {
    final q = query.toLowerCase();
    
    if (q.contains('cpr') || q.contains('breath') || q.contains('chok') || q.contains('suffoc')) {
      return _cprGuidance;
    }
    if (q.contains('bleed') || q.contains('cut') || q.contains('blood') || q.contains('wound') || q.contains('hemorrhage')) {
      return _bleedingGuidance;
    }
    if (q.contains('fracture') || q.contains('bone') || q.contains('break') || q.contains('broken') || q.contains('spinal') || q.contains('neck') || q.contains('back')) {
      return _fractureGuidance;
    }
    if (q.contains('burn') || q.contains('fire') || q.contains('scald')) {
      return _burnGuidance;
    }
    if (q.contains('unconscious') || q.contains('faint') || q.contains('unresponsive') || q.contains('knocked') || q.contains('recovery')) {
      return _unconsciousGuidance;
    }
    if (q.contains('heart attack') || q.contains('chest pain') || q.contains('heart') || q.contains('cardiac')) {
      return _heartAttackGuidance;
    }
    if (q.contains('stroke') || q.contains('face') || q.contains('arm') || q.contains('speech') || q.contains('fast')) {
      return _strokeGuidance;
    }
    if (q.contains('accident') || q.contains('crash') || q.contains('collision') || q.contains('car') || q.contains('road') || q.contains('vehicle')) {
      return _accidentGuidance;
    }
    if (q.contains('help') || q.contains('assist') || q.contains('first aid') || q.contains('menu')) {
      return _menuGuidance;
    }
    
    return _defaultGuidance;
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

  Future<void> _makeEmergencyCall() async {
    final Uri url = Uri.parse('tel:112');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── EMERGENCY BAR ──
            Container(
              height: 44,
              color: AppColors.emergencyRed,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOffline 
                        ? "🚨 Offline Emergency Guidance"
                        : "🚨 RoadSOS AI — Emergency Assistant",
                    style: AppTypography.labelCaps.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _makeEmergencyCall,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "CALL 112",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: AppColors.emergencyAmber,
                child: Center(
                  child: Text(
                    "OFFLINE EMERGENCY ASSISTANT ACTIVE",
                    style: AppTypography.labelCaps.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

            // ── QUICK ACTION CHIPS (only shown before conversation starts) ──
            if (_messages.length <= 1)
              Container(
                height: 48,
                color: AppColors.surface,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _quickActions.length,
                  itemBuilder: (context, i) {
                    final label = _quickActions[i];
                    return GestureDetector(
                      onTap: () => _sendMessage(label),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          border: Border.all(color: AppColors.borderSubtle),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ── MESSAGES LIST ──
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading && !_isStreaming ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading && !_isStreaming) {
                    return const _TypingIndicator();
                  }

                  final msg = _messages[index];
                  return _MessageCard(
                    msg: msg,
                    onRetry: msg.isError
                        ? () {
                            final userMsgIndex = _messages.sublist(0, index).lastIndexWhere((m) => m.isUser);
                            if (userMsgIndex != -1) {
                              final userText = _messages[userMsgIndex].text;
                              setState(() {
                                _messages.removeRange(userMsgIndex + 1, _messages.length);
                              });
                              _sendMessage(userText);
                            }
                          }
                        : null,
                  );
                },
              ),
            ),

            // ── INPUT BAR ──
            Container(
              color: AppColors.surface,
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: "Describe the emergency...",
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: AppColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: AppColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: AppColors.emergencyRed),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_controller.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: _isLoading ? AppColors.textMuted : AppColors.emergencyRed,
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final ChatMessage msg;
  final VoidCallback? onRetry;

  const _MessageCard({required this.msg, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(
            color: msg.isUser ? AppColors.emergencyRed : AppColors.infoBlue,
            width: 3,
          ),
          top: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
          right: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
          bottom: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                msg.isUser ? "YOU" : "ROADSOS AI",
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 9,
                  color: msg.isUser ? AppColors.emergencyRed : AppColors.infoBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(msg.timestamp),
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMessageContent(msg.text),
          if (msg.isError && onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
              label: Text("RETRY", style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 10)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMessageContent(String text) {
    final lines = text.split('\n').where((l) => l.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final cleanLine = line.trim();
        final bool isStep = RegExp(r'^\d+\.').hasMatch(cleanLine);
        final bool isNext = cleanLine.startsWith('Next:');

        if (isNext) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: AppColors.safeGreen.withValues(alpha: 0.1),
            child: Text(
              line,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.safeGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (isStep) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
            ),
          );
        }

        return Text(
          line,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
        );
      }).toList(),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.infoBlue, width: 3),
          top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
          right: BorderSide(color: AppColors.borderSubtle, width: 0.5),
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "ROADSOS AI",
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 9,
                  color: AppColors.infoBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const _AnimatedDots(),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = (sin((_controller.value * 2 * pi) - (index * pi / 2)) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.infoBlue,
              ),
              transform: Matrix4.diagonal3Values(0.4 + 0.6 * value, 0.4 + 0.6 * value, 1.0),
            );
          },
        );
      }),
    );
  }
}
