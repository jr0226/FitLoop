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
    defaultValue: 'https://fitloop-malaysian-food-api-v1.onrender.com',
  );

  /// Application environment flag (e.g. 'development', 'staging', 'production')
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Request timeout in seconds (accommodates Render cold starts + Gemini multimodal processing)
  static const int requestTimeoutSeconds = 90;

  /// Public URL for the FitLoop Privacy Policy (Google Play & Health Connect compliant)
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://diet-workout-app.web.app/privacy.html',
  );

  /// Public URL for the Account & Data Deletion request portal (Google Play compliant)
  static const String dataDeletionUrl = String.fromEnvironment(
    'DATA_DELETION_URL',
    defaultValue: 'https://diet-workout-app.web.app/delete-account.html',
  );

  /// Official support contact email
  static const String supportEmail = 'chaijierong8@gmail.com';

  /// Helper to log active non-sensitive environment configuration in debug mode
  static void logConfig() {
    if (kDebugMode) {
      debugPrint(
        '🔧 [AppConfig] Active Backend URL: $apiBaseUrl (Env: $environment, Privacy: $privacyPolicyUrl)',
      );
    }
  }
}
