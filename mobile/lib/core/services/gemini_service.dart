import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../errors/app_exceptions.dart';
import '../utils/logger.dart';

/// Communicates with the Google Gemini REST API for emergency first-aid chat.
class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';
  static const String _endpointUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent';
  static const String _streamEndpointUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:streamGenerateContent';

  static const int _maxRetries = 2;
  static const Duration _initialBackoff = Duration(seconds: 1);
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _streamTimeout = Duration(seconds: 60);

  static const String _systemInstruction =
      'You are RoadSOS, a calm emergency first-aid assistant for road accidents and medical emergencies. '
      'Give practical, numbered step-by-step actions the user can do right now. '
      'Be concise and easy to read under stress. Use short bullets or numbered lists. '
      'Do not diagnose conditions; focus on immediate first-aid and safety. '
      'If life-threatening (not breathing, severe bleeding, unconscious, chest pain, etc.), '
      'tell them to call emergency services (112 or 100) first. '
      'Never replace professional care — guide until help arrives.';

  static const List<Map<String, String>> _safetySettings = [
    {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
  ];

  Future<void> _ensureConnectivity() async {
    if (kIsWeb) return;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw const NetworkException('No active internet connection.');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.warning('Connectivity check failed; proceeding with API call.', e);
    }
  }

  Future<T> _requestWithRetry<T>(
    Future<T> Function() request, {
    required Duration timeout,
  }) async {
    Duration backoff = _initialBackoff;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await request().timeout(timeout);
      } on TimeoutException {
        if (attempt == _maxRetries - 1) rethrow;
      } catch (e) {
        if (e is ApiException || e is NetworkException) rethrow;
        if (attempt == _maxRetries - 1) rethrow;
      }
      AppLogger.warning('Gemini request attempt ${attempt + 1} failed; retrying in ${backoff.inSeconds}s.');
      await Future.delayed(backoff);
      backoff *= 2;
    }
    throw const NetworkException('Request failed after retries.');
  }

  List<Map<String, dynamic>> _buildContents({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) {
    final contents = <Map<String, dynamic>>[];

    for (final turn in chatHistory) {
      final role = turn['role'] ?? 'user';
      final text = (turn['text'] ?? '').trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': role == 'model' ? 'model' : 'user',
        'parts': [
          {'text': text}
        ],
      });
    }

    final last = chatHistory.isNotEmpty ? chatHistory.last : null;
    final lastIsSameUser = last != null &&
        last['role'] == 'user' &&
        (last['text'] ?? '').trim() == userMessage.trim();

    if (!lastIsSameUser) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage.trim()}
        ],
      });
    }

    return contents;
  }

  Map<String, dynamic> _buildRequestBody({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) {
    return {
      'contents': _buildContents(userMessage: userMessage, chatHistory: chatHistory),
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ],
      },
      'generationConfig': {
        'temperature': 0.25,
        'maxOutputTokens': 800,
      },
      'safetySettings': _safetySettings,
    };
  }

  Never _throwApiError(http.Response response) {
    String errMsg = 'API responded with status ${response.statusCode}';
    try {
      final errorData = json.decode(response.body) as Map<String, dynamic>;
      errMsg = errorData['error']?['message']?.toString() ?? errMsg;
    } catch (_) {}

    AppLogger.error('Gemini API error (${response.statusCode}): $errMsg');

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiException(
        'Invalid or unauthorized Gemini API key. Check Settings or .env.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw const ApiException('Too many requests. Please wait and try again.', statusCode: 429);
    }
    throw ApiException('Gemini API error: $errMsg', statusCode: response.statusCode);
  }

  String? _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final candidate = candidates.first as Map<String, dynamic>;
    final parts = candidate['content']?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    final text = parts.first['text']?.toString();
    return text?.trim();
  }

  /// Non-streaming emergency response (fallback path).
  Future<String> generateEmergencyResponse({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) async {
    await _ensureConnectivity();

    final apiKey = await AiConfig.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw const ApiException('Gemini API key is not configured.');
    }

    final url = Uri.parse('$_endpointUrl?key=$apiKey');
    final requestBody = _buildRequestBody(
      userMessage: userMessage,
      chatHistory: chatHistory,
    );

    AppLogger.info('Gemini request sent (generateContent, ${chatHistory.length} history turns).');

    try {
      final response = await _requestWithRetry(() async {
        return http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );
      }, timeout: _requestTimeout);

      if (response.statusCode != 200) {
        _throwApiError(response);
      }

      final responseJson = json.decode(response.body) as Map<String, dynamic>;
      final result = _extractText(responseJson);

      if (result == null || result.isEmpty) {
        final finishReason =
            (responseJson['candidates'] as List?)?.first?['finishReason']?.toString();
        throw ApiException(
          finishReason != null
              ? 'No response from AI (reason: $finishReason).'
              : 'Received an empty response from AI model.',
        );
      }

      AppLogger.info('Gemini response received (${result.length} chars).');
      return result;
    } on TimeoutException {
      AppLogger.error('Gemini generateContent timed out.');
      throw const NetworkException('Request timed out. Check your connection and try again.');
    } catch (e) {
      AppLogger.error('Gemini generateContent failed', e);
      rethrow;
    }
  }

  /// Streams tokens from Gemini via Server-Sent Events.
  Stream<String> streamEmergencyResponse({
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) async* {
    await _ensureConnectivity();

    final apiKey = await AiConfig.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw const ApiException('Gemini API key is not configured.');
    }

    final url = Uri.parse('$_streamEndpointUrl?key=$apiKey&alt=sse');
    final requestBody = _buildRequestBody(
      userMessage: userMessage,
      chatHistory: chatHistory,
    );

    AppLogger.info('Gemini request sent (streamGenerateContent, ${chatHistory.length} history turns).');

    final client = http.Client();
    var receivedAnyText = false;

    try {
      final streamedResponse = await _requestWithRetry(() async {
        final request = http.Request('POST', url);
        request.headers['Content-Type'] = 'application/json';
        request.body = json.encode(requestBody);
        return client.send(request);
      }, timeout: _streamTimeout);

      if (streamedResponse.statusCode != 200) {
        final errBody = await streamedResponse.stream.bytesToString();
        AppLogger.error('Gemini stream HTTP ${streamedResponse.statusCode}: $errBody');
        _throwApiError(http.Response(errBody, streamedResponse.statusCode));
      }

      final byteStream = streamedResponse.stream.transform(utf8.decoder);
      var buffer = '';

      await for (final chunk in byteStream) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line == '[' || line == ']') continue;

          var jsonStr = line;
          if (jsonStr.startsWith('data: ')) {
            jsonStr = jsonStr.substring(6).trim();
          }
          if (jsonStr.startsWith(',')) jsonStr = jsonStr.substring(1).trim();
          if (jsonStr.endsWith(',')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          }
          if (jsonStr.isEmpty) continue;

          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final chunkText = _extractText(data);
            if (chunkText != null && chunkText.isNotEmpty) {
              if (!receivedAnyText) {
                AppLogger.info('Gemini stream: first chunk received.');
              }
              receivedAnyText = true;
              yield chunkText;
            }
          } catch (_) {
            // Incomplete JSON line; carry over for next chunk
            buffer = '$rawLine\n$buffer';
          }
        }
      }

      // Flush remaining buffer
      final tail = buffer.trim();
      if (tail.isNotEmpty && tail != '[' && tail != ']') {
        var jsonStr = tail;
        if (jsonStr.startsWith('data: ')) jsonStr = jsonStr.substring(6).trim();
        if (jsonStr.startsWith(',')) jsonStr = jsonStr.substring(1).trim();
        if (jsonStr.endsWith(',')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
        }
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final chunkText = _extractText(data);
          if (chunkText != null && chunkText.isNotEmpty) {
            receivedAnyText = true;
            yield chunkText;
          }
        } catch (_) {}
      }

      if (!receivedAnyText) {
        throw const ApiException('Received an empty response from AI model.');
      }

      AppLogger.info('Gemini stream complete.');
    } on TimeoutException {
      AppLogger.error('Gemini stream timed out.');
      throw const NetworkException('Request timed out. Check your connection and try again.');
    } catch (e) {
      AppLogger.error('Gemini stream failed', e);
      rethrow;
    } finally {
      client.close();
    }
  }
}
