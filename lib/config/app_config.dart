import 'package:flutter/foundation.dart';

/// Centralized application configuration.
/// 
/// Non-sensitive runtime and build-time configurations are configured here.
/// 
/// Security Design:
/// Sensitive third-party API keys (Gemini, RapidAPI, API-Ninjas) MUST NEVER
/// be stored or defined in Flutter (even via `--dart-define`, as compiled strings
/// can be easily extracted from client binaries). All sensitive operations are
/// delegated to the backend API specified by [apiBaseUrl].
class AppConfig {
  /// Base URL of your backend API layer or Firebase Cloud Functions server.
  /// Android emulator uses 10.0.2.2; iOS simulator and web use localhost or remote host.
  /// Pass custom URL via: flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Application environment flag (e.g. 'development', 'staging', 'production')
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Request timeout in seconds
  static const int requestTimeoutSeconds = 30;

  /// Helper to log active non-sensitive environment configuration in debug mode
  static void logConfig() {
    if (kDebugMode) {
      debugPrint('🔧 [AppConfig] Active Backend URL: $apiBaseUrl (Env: $environment)');
    }
  }
}
