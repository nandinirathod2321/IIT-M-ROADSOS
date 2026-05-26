import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Secure config helper for AI features, supporting compile-time defines
/// and runtime SharedPreferences overrides.
abstract final class AiConfig {
  static const String _defaultKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Key used in SharedPreferences for user-provided API key overrides.
  static const String sharedPrefsKey = 'gemini_api_key_override';

  /// Retrieves the active Gemini API key.
  /// Prioritizes the runtime SharedPreferences override, falling back to
  /// the environment variable or compile-time --dart-define value.
  static Future<String> getGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = prefs.getString(sharedPrefsKey);
      if (override != null && override.trim().isNotEmpty) {
        return override.trim();
      }
    } catch (_) {
      // Graceful fallback if SharedPreferences fails or is uninitialized
    }
    
    // Prioritize the dotenv key loaded from .env over compile-time define
    if (ApiConstants.geminiApiKey.isNotEmpty) {
      return ApiConstants.geminiApiKey;
    }
    return _defaultKey;
  }

  /// Sets a custom Gemini API key override in SharedPreferences.
  static Future<void> setGeminiApiKeyOverride(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(sharedPrefsKey);
    } else {
      await prefs.setString(sharedPrefsKey, key.trim());
    }
  }

  /// Clears any user override key.
  static Future<void> clearGeminiApiKeyOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sharedPrefsKey);
  }
}
