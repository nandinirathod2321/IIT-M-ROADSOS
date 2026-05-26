import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../ai_chat_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class AIChatScreen extends StatefulWidget {
  final String? initialQuestion; // pre-fill from quick action buttons

  const AIChatScreen({super.key, this.initialQuestion});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIChatService _service = AIChatService();
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _userLocation; // from Geolocator

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
    _loadLocation();

    // Add welcome message
    _messages.add(ChatMessage(
      text: "I'm RoadSOS AI. Tell me what emergency you're dealing with. I'll give you step-by-step instructions.",
      isUser: false,
      timestamp: DateTime.now(),
    ));

    if (widget.initialQuestion != null) {
      // Pre-send the initial question after 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.initialQuestion!.isNotEmpty) {
          _sendMessage(widget.initialQuestion!);
        }
      });
    }
  }

  Future<void> _loadLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _userLocation = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to load location: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userText = text.trim();

    setState(() {
      _messages.add(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    // Call service
    final reply = await _service.sendMessage(userText, userLocation: _userLocation);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
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

  Future<void> _callEmergency() async {
    final Uri url = Uri.parse('tel:112');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint("Failed to call 112: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── EMERGENCY BAR (always visible, top) ──
            Container(
              height: 44,
              color: AppColors.emergencyRed,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "🚨 RoadSOS AI — Emergency Assistant",
                    style: AppTypography.labelCaps.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _callEmergency,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
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

            // ── QUICK ACTION CHIPS ──
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
                          style: AppTypography.bodySmall.copyWith(color: Colors.white),
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
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return const _TypingIndicator();
                  }

                  final msg = _messages[index];
                  return _MessageCard(msg: msg);
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
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: "Describe the emergency...",
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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

  const _MessageCard({required this.msg});

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
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(msg.timestamp),
                style: AppTypography.monoMedium.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMessageContent(msg.text),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String text) {
    List<String> lines = text.split('\n').where((l) => l.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        bool isStep = RegExp(r'^\d+\.').hasMatch(line.trim());
        bool isNext = line.trim().startsWith('Next:');

        if (isNext) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: AppColors.safeGreen.withOpacity(0.1),
            width: double.infinity,
            child: Text(
              line,
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFF34D399),
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
              style: AppTypography.bodyMedium.copyWith(color: Colors.white, height: 1.5),
            ),
          );
        }

        return Text(
          line,
          style: AppTypography.bodyMedium.copyWith(color: Colors.white, height: 1.5),
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
          left: BorderSide(
            color: AppColors.infoBlue,
            width: 3,
          ),
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

class _AnimatedDotsState extends State<_AnimatedDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      _controllers[i].repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return ScaleTransition(
          scale: _animations[index],
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.infoBlue,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
