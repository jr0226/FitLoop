import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ThemeService.isDarkModeSupported = false; // Default for FYP release
    });

    test('Initializes with Light Mode locked for release even when saved in prefs', () async {
      SharedPreferences.setMockInitialValues({ThemeService.prefKey: true});
      await ThemeService.init();
      expect(ThemeService.isDarkMode, isFalse);
      expect(ThemeService.themeModeNotifier.value, equals(ThemeMode.light));
    });

    test('Persists choice to SharedPreferences while keeping UI in Light Mode during release', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService.init();

      await ThemeService.setDarkMode(true);
      expect(ThemeService.isDarkMode, isFalse);
      expect(ThemeService.themeModeNotifier.value, equals(ThemeMode.light));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ThemeService.prefKey), isTrue);
    });

    test('Underlying architecture enables Dark Mode when isDarkModeSupported is turned on', () async {
      ThemeService.isDarkModeSupported = true;
      SharedPreferences.setMockInitialValues({ThemeService.prefKey: true});
      await ThemeService.init();
      expect(ThemeService.isDarkMode, isTrue);
      expect(ThemeService.themeModeNotifier.value, equals(ThemeMode.dark));

      await ThemeService.setDarkMode(false);
      expect(ThemeService.isDarkMode, isFalse);
      expect(ThemeService.themeModeNotifier.value, equals(ThemeMode.light));

      ThemeService.isDarkModeSupported = false; // reset
    });
  });

  group('AppTheme Definitions Tests', () {
    test('LightTheme has correct brightness, primary teal, and light surface tokens', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.colorScheme.primary, equals(AppTheme.primaryTeal));
      expect(light.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(light.cardColor, equals(Colors.white));
    });

    test('DarkTheme has correct brightness, dark teal, and dark slate surface tokens', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.colorScheme.primary, equals(AppTheme.darkTealAccent));
      expect(dark.scaffoldBackgroundColor, equals(const Color(0xFF0F172A)));
      expect(dark.cardColor, equals(const Color(0xFF1E293B)));
    });
  });
}
