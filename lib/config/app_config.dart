import 'package:flutter/foundation.dart';

/// Centralized application configuration.
/// 
/// Non-sensitive build-time configurations are passed via `--dart-define`.
///
/// NOTE on DevSecOps & Security:
/// Any secret passed via `--dart-define` is compiled directly into the client
/// binary and can be extracted via reverse engineering. In production, sensitive
/// operations (e.g. Gemini AI, third-party API keys) should be routed through a
/// secure backend proxy (configured via [apiBaseUrl]), while `--dart-define` keys
/// are supported for local testing/fallback.
class AppConfig {
  /// Base URL of your backend API or Firebase Cloud Functions proxy.
  /// Example: flutter run --dart-define=API_BASE_URL=https://api.example.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Gemini API Key for direct client calls (fallback/local development only).
  /// Production should route requests through [apiBaseUrl].
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// RapidAPI Key for ExerciseDB queries (fallback/local development only).
  static const String rapidApiKey = String.fromEnvironment(
    'RAPIDAPI_KEY',
    defaultValue: '',
  );

  /// API Ninjas Key for nutrition queries (fallback/local development only).
  static const String apiNinjasKey = String.fromEnvironment(
    'API_NINJAS_KEY',
    defaultValue: '',
  );

  /// Check if backend proxy is active
  static bool get hasBackendProxy => apiBaseUrl.trim().isNotEmpty;

  /// Helper to warn in debug logs if a key or proxy is missing
  static void validateConfiguration() {
    if (kDebugMode) {
      if (!hasBackendProxy) {
        if (geminiApiKey.isEmpty) {
          debugPrint('⚠️ [Security/Config] No API_BASE_URL or GEMINI_API_KEY defined. Pass via --dart-define.');
        }
        if (rapidApiKey.isEmpty) {
          debugPrint('⚠️ [Security/Config] No RAPIDAPI_KEY defined for ExerciseDB.');
        }
        if (apiNinjasKey.isEmpty) {
          debugPrint('⚠️ [Security/Config] No API_NINJAS_KEY defined for Food search.');
        }
      }
    }
  }
}
