import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central state and persistence service for FitLoop's global ThemeMode.
///
/// Ensures:
/// 1. Zero lag on startup by reading local SharedPreferences immediately.
/// 2. Instant real-time UI switching via ValueNotifier.
/// 3. Synchronization to Firestore `users/{uid}.settings.isDarkMode`.
class ThemeService {
  ThemeService._();

  static const String prefKey = 'fitloop_theme_is_dark';

  /// Feature toggle: locked to Light Mode for the FYP release.
  /// Set to true to re-enable Dark Mode in future versions.
  static bool isDarkModeSupported = false;

  /// Root notifier consumed by MaterialApp(themeMode: ...).
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Helper getter for current mode.
  static bool get isDarkMode =>
      isDarkModeSupported && (themeModeNotifier.value == ThemeMode.dark);

  /// Initializes the theme from persistent local storage.
  static Future<void> init({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final bool? savedIsDark = p.getBool(prefKey);
      if (isDarkModeSupported && savedIsDark == true) {
        themeModeNotifier.value = ThemeMode.dark;
      } else {
        themeModeNotifier.value = ThemeMode.light;
      }
    } catch (e) {
      debugPrint('[ThemeService] Failed to read local theme preference: $e');
    }
  }

  /// Sets dark mode, updates UI immediately, and persists choice.
  static Future<void> setDarkMode(
    bool isDark, {
    String? uid,
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
  }) async {
    // 1. Update UI notifier only if Dark Mode feature is active; otherwise hold Light Mode
    if (isDarkModeSupported) {
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.light;
    }

    // 2. Persist to on-device SharedPreferences
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setBool(prefKey, isDark);
    } catch (e) {
      debugPrint('[ThemeService] Failed to save local theme: $e');
    }

    // 3. Persist to Firestore if user is authenticated (preserves existing user data)
    if (uid != null && uid.isNotEmpty) {
      try {
        final db = firestore ?? FirebaseFirestore.instance;
        await db.collection('users').doc(uid).update({
          'settings.isDarkMode': isDark,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[ThemeService] Failed to sync theme to Firestore: $e');
      }
    }
  }

  /// Syncs Firestore settings to local theme state when profile is loaded.
  static void syncFromFirestore(Map<String, dynamic>? data, {String? uid}) {
    if (data == null || !isDarkModeSupported) return;
    final settings = data['settings'];
    if (settings is Map && settings['isDarkMode'] is bool) {
      final bool remoteIsDark = settings['isDarkMode'] as bool;
      if (remoteIsDark != isDarkMode) {
        setDarkMode(remoteIsDark, uid: null);
      }
    }
  }
}
