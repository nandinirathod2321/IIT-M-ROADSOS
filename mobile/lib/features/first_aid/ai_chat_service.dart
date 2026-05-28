import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AIChatService {
  static const String _systemPrompt = """
You are RoadSOS AI — an emergency first aid assistant at a road accident scene.

YOUR RULES:
1. You are talking to a panicking bystander or injured person at a road accident
2. Every response must be under 80 words
3. Give NUMBERED steps — never paragraphs
4. Always end with: "Next: [what to do after this]"
5. Be calm, direct, zero hesitation
6. Never say "consult a doctor" or "I am not a medical professional"
7. Never give disclaimers — give actions
8. If asked in Hindi, respond in simple Hindi + English mix
9. You know emergency numbers: Ambulance 108, Police 100, National 112
10. If situation sounds life-threatening: ALWAYS say "Call 112 NOW" first

WHAT YOU KNOW:
- CPR technique for adults and children
- Bleeding control
- Fracture immobilization  
- Spinal injury protocol (do not move)
- Recovery position
- Shock management
- Burns treatment
- Choking response
- How to talk to 112 operator

TONE: Military medic — calm, fast, clear.
""";

  final List<Map<String, dynamic>> _conversationHistory = [];

  /// Streams emergency AI response in real-time.
  Stream<String> sendMessageStream(String userMessage, {
    String? userLocation,
  }) async* {
    final apiKey = ApiConstants.geminiApiKey;
    debugPrint("[AntiGravity] API Key loaded: ${apiKey.isNotEmpty}");

    if (apiKey.isEmpty) {
      debugPrint("[AntiGravity] Error caught during streaming: API Key is not configured.");
      throw Exception("Gemini API Key is not configured in .env file.");
    }

    // Build context-aware message
    String contextualMessage = userMessage;
    if (_conversationHistory.isEmpty && userLocation != null) {
      contextualMessage = "Location: $userLocation. $userMessage";
    }

    // Add to history
    _conversationHistory.add({
      "role": "user",
      "parts": [{"text": contextualMessage}]
    });

    // Build request body
    Map<String, dynamic> requestBody = {
      "system_instruction": {
        "parts": [{"text": _systemPrompt}]
      },
      "contents": _conversationHistory,
      "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 200,
        "topP": 0.8,
      },
      "safetySettings": [
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_HATE_SPEECH",
          "threshold": "BLOCK_NONE"
        }
      ]
    };

    final url = "${ApiConstants.geminiStreamUrl}?key=$apiKey";
    
    debugPrint("[AntiGravity] Request URL: $url");
    debugPrint("[AntiGravity] Request Headers: {Content-Type: application/json}");
    debugPrint("[AntiGravity] Request Body: ${jsonEncode(requestBody)}");

    final client = http.Client();
    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(requestBody);

    debugPrint("[AntiGravity] Streaming request sent.");

    bool isFirstChunk = true;
    final StringBuffer fullReplyBuffer = StringBuffer();

    try {
      final response = await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        throw Exception("Gemini stream failed with status ${response.statusCode}: $errBody");
      }

      final stream = response.stream.transform(utf8.decoder);
      String buffer = '';
      await for (final chunk in stream) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line == '[' || line == ']') continue;
          
          String jsonStr = line;
          if (jsonStr.startsWith(',')) {
            jsonStr = jsonStr.substring(1).trim();
          }
          if (jsonStr.endsWith(',')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          }
          if (jsonStr.isEmpty) continue;
          
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final chunkText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
            if (chunkText.isNotEmpty) {
              if (isFirstChunk) {
                debugPrint("[AntiGravity] First chunk received.");
                isFirstChunk = false;
              }
              fullReplyBuffer.write(chunkText);
              yield chunkText;
            }
          } catch (_) {
            buffer = '$line\n$buffer';
          }
        }
      }

      if (buffer.isNotEmpty) {
        final line = buffer.trim();
        if (line != ']' && line != '[' && line.isNotEmpty) {
          String jsonStr = line;
          if (jsonStr.startsWith(',')) jsonStr = jsonStr.substring(1).trim();
          if (jsonStr.endsWith(',')) jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final chunkText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
            if (chunkText.isNotEmpty) {
              if (isFirstChunk) {
                debugPrint("[AntiGravity] First chunk received.");
                isFirstChunk = false;
              }
              fullReplyBuffer.write(chunkText);
              yield chunkText;
            }
          } catch (_) {}
        }
      }

      debugPrint("[AntiGravity] Stream complete.");

      final String reply = fullReplyBuffer.toString().trim();
      if (reply.isNotEmpty) {
        _conversationHistory.add({
          "role": "model",
          "parts": [{"text": reply}]
        });
      }

    } catch (e) {
      debugPrint("[AntiGravity] Error caught during streaming: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Original synchronous method maintained as fallback.
  Future<String> sendMessage(String userMessage, {
    String? userLocation,
    String? injuryContext,
  }) async {
    final apiKey = ApiConstants.geminiApiKey;
    debugPrint("[AntiGravity] API Key loaded: ${apiKey.isNotEmpty}");

    if (apiKey.isEmpty) {
      debugPrint("[AntiGravity] Error caught in sendMessage: API Key is not configured.");
      return _getFallbackResponse(userMessage);
    }

    String contextualMessage = userMessage;
    if (_conversationHistory.isEmpty && userLocation != null) {
      contextualMessage = "Location: $userLocation. $userMessage";
    }

    _conversationHistory.add({
      "role": "user",
      "parts": [{"text": contextualMessage}]
    });

    Map<String, dynamic> requestBody = {
      "system_instruction": {
        "parts": [{"text": _systemPrompt}]
      },
      "contents": _conversationHistory,
      "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 200,
        "topP": 0.8,
      },
      "safetySettings": [
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_HATE_SPEECH",
          "threshold": "BLOCK_NONE"
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse("${ApiConstants.geminiUrl}?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String reply = data["candidates"][0]["content"]["parts"][0]["text"];

        _conversationHistory.add({
          "role": "model",
          "parts": [{"text": reply}]
        });

        return reply.trim();
      } else if (response.statusCode == 429) {
        return "⚡ Too many requests. Wait 10 seconds and try again.";
      } else {
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      debugPrint("[AntiGravity] Error caught in sendMessage: $e");
      return _getFallbackResponse(userMessage);
    }
  }

  String _getFallbackResponse(String message) {
    final String lower = message.toLowerCase();

    if (lower.contains("cpr") || lower.contains("not breathing") || lower.contains("heart")) {
      return """1. Lay person flat on back
2. Place hands center of chest  
3. Push hard and fast — 30 compressions
4. Give 2 rescue breaths
5. Repeat until ambulance arrives
Next: Call 108 if not done yet""";
    }

    if (lower.contains("bleed") || lower.contains("blood") || lower.contains("wound")) {
      return """1. Press hard on wound with cloth
2. Do NOT remove cloth — add more on top
3. Raise limb above heart level if possible
4. Keep pressing — do not stop
Next: Call 108, keep pressure until they arrive""";
    }

    if (lower.contains("unconscious") || lower.contains("faint")) {
      return """1. Check breathing — look, listen, feel
2. If breathing: recovery position (on side)
3. If not breathing: start CPR immediately
4. Do NOT give water or food
Next: Call 112 NOW if not done""";
    }

    return """Call 112 immediately. 
Tell them: your location, number of victims, and injuries you can see.
Stay on the line — operator will guide you.
Next: Do not move the victim until ambulance arrives.""";
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  bool get hasHistory => _conversationHistory.isNotEmpty;
}
