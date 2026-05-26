import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/ai_config.dart';
import '../errors/app_exceptions.dart';
import '../utils/logger.dart';

/// Service class to communicate with the Google Gemini 1.5 Flash REST API.
/// Incorporates strict timeouts, connectivity checks, and clean error bounds.
class GeminiService {
  static const String _modelName = 'gemini-1.5-flash';
  static const String _endpointUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent';
  static const String _streamEndpointUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:streamGenerateContent';

  static const String _systemInstruction =
      'You are RoadSOS, a professional, extremely calm, and highly experienced emergency medical first-aid assistant. '
      'Your instructions must be practical, step-by-step, emergency-focused, and highly readable. '
      'Format your responses with clean bold headers, simple bullet points, and numbered lists. '
      'Keep explanations concise, short, but highly informative so they are easy to read under stress. '
      'Always direct the user to call emergency services (112 or 100) immediately if the situation is severe or life-threatening. '
      'Do not give diagnoses; focus entirely on active first-aid procedures and immediate rescue steps.';

  /// Sends a chat message to Gemini, sending along the prior multi-turn dialogue context.
  /// Enforces a strict 4-second timeout.
  Future<String> generateEmergencyResponse({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) async {
    AppLogger.info('Generating emergency AI response...');

    // 1. Check internet connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const NetworkException('No active internet connection.');
    }

    // 2. Fetch the Gemini API Key
    final apiKey = await AiConfig.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw const ApiException('Gemini API Key is not configured.');
    }

    final url = Uri.parse('$_endpointUrl?key=$apiKey');

    // 3. Format contents with multi-turn history
    final List<Map<String, dynamic>> contents = [];

    // Map historical elements (expected format: {'role': 'user'|'model', 'text': 'content'})
    for (final turn in chatHistory) {
      final role = turn['role'] ?? 'user';
      final text = turn['text'] ?? '';
      if (text.isNotEmpty) {
        contents.add({
          'role': role == 'model' ? 'model' : 'user',
          'parts': [
            {'text': text}
          ]
        });
      }
    }

    // Append the current message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final Map<String, dynamic> requestBody = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.25,
        'maxOutputTokens': 650,
      }
    };

    // 4. Send REST Request
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errMsg = errorData['error']?['message'] ?? 'API responded with status code ${response.statusCode}';
        throw ApiException('Gemini API Error: $errMsg', statusCode: response.statusCode);
      }

      // 5. Parse response content
      final Map<String, dynamic> responseJson = json.decode(response.body);
      final String? result = responseJson['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      if (result == null || result.trim().isEmpty) {
        throw const ApiException('Received an empty response from AI model.');
      }

      return result.trim();
    } on TimeoutException {
      AppLogger.error('Gemini API call timed out.');
      throw const NetworkException('Gemini API request timed out after 4 seconds.');
    } catch (e) {
      AppLogger.error('Gemini API call failed', e);
      rethrow;
    }
  }

  /// Sends a chat message to Gemini for real-time text token streaming.
  /// Yields parts of the generated response in chunks.
  Stream<String> streamEmergencyResponse({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) async* {
    AppLogger.info('Streaming emergency AI response...');

    // 1. Check internet connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const NetworkException('No active internet connection.');
    }

    // 2. Fetch the Gemini API Key
    final apiKey = await AiConfig.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw const ApiException('Gemini API Key is not configured.');
    }

    final url = Uri.parse('$_streamEndpointUrl?key=$apiKey');

    // 3. Format contents with multi-turn history
    final List<Map<String, dynamic>> contents = [];
    for (final turn in chatHistory) {
      final role = turn['role'] ?? 'user';
      final text = turn['text'] ?? '';
      if (text.isNotEmpty) {
        contents.add({
          'role': role == 'model' ? 'model' : 'user',
          'parts': [
            {'text': text}
          ]
        });
      }
    }

    // Append current message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final Map<String, dynamic> requestBody = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.25,
        'maxOutputTokens': 650,
      }
    };

    // 4. Send REST streaming request
    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode(requestBody);

    try {
      final response = await client.send(request).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw ApiException('Gemini API Streaming failed (Status: ${response.statusCode})', statusCode: response.statusCode);
      }

      // 5. Yield parsed chunks reactively
      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        final cleanLine = line.trim();
        if (cleanLine.isEmpty || cleanLine == '[' || cleanLine == ']') continue;
        
        String jsonStr = cleanLine;
        if (jsonStr.startsWith(',')) {
          jsonStr = jsonStr.substring(1).trim();
        }
        if (jsonStr.endsWith(',')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
        }
        
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final chunkText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          if (chunkText.isNotEmpty) {
            yield chunkText;
          }
        } catch (_) {
          // Gracefully suppress partial line parsing issues
        }
      }
    } on TimeoutException {
      AppLogger.error('Gemini API streaming timed out.');
      throw const NetworkException('Gemini streaming request timed out.');
    } catch (e) {
      AppLogger.error('Gemini API streaming error', e);
      rethrow;
    } finally {
      client.close();
    }
  }
}
