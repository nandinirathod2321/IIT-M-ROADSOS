import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import 'ai_chat_service.dart';

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
  final AIChatService _service = AIChatService();
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
      print("Could not load location in AI Chat: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    debugPrint("[AntiGravity] User message sent: $text");

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

    String streamedText = '';
    int? botMessageIndex;
    StreamSubscription<String>? subscription;

    subscription = _service.sendMessageStream(text, userLocation: _userLocation).listen(
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
        debugPrint("[AntiGravity] Error caught during streaming: $err");
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          if (botMessageIndex == null) {
            _messages.add(ChatMessage(
              text: "Failed to generate response. Tap to retry.",
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ));
          } else {
            _messages[botMessageIndex!] = ChatMessage(
              text: "Failed to generate response. Tap to retry.",
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
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
        _scrollToBottom();
        subscription?.cancel();
      },
      cancelOnError: true,
    );
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
      backgroundColor: AppColors.primary,
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
                    "🚨 RoadSOS AI — Emergency Assistant",
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
                        color: Colors.white.withOpacity(0.2),
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
                            color: Colors.white,
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
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
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
            color: AppColors.safeGreen.withOpacity(0.1),
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
