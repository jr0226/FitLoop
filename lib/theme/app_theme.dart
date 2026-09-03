import 'package:flutter/material.dart';

/// Centralized Theme configuration for FitLoop.
///
/// Implements Material 3 Light and Dark themes with calibrated brand tokens:
/// - FitLoop Primary Teal brand color
/// - Light: Slate-50 background, pure white surfaces, high contrast slate text
/// - Dark: Slate-900 charcoal background, Slate-800 surfaces, high contrast off-white text
class AppTheme {
  AppTheme._();

  // Primary Brand Colors
  static const Color primaryTeal = Color(0xFF009688);
  static const Color primaryTealLight = Color(0xFF26A69A);
  static const Color darkTealAccent = Color(0xFF2DD4BF); // Vibrant teal for dark mode

  // =========================================================================
  // LIGHT THEME
  // =========================================================================
  static ThemeData get lightTheme {
    const background = Color(0xFFF8FAFC); // Slate-50
    const surface = Colors.white;
    const onSurface = Color(0xFF0F172A);  // Slate-900
    const onSurfaceVariant = Color(0xFF64748B); // Slate-500
    const outline = Color(0xFFE2E8F0);    // Slate-200
    const surfaceContainer = Color(0xFFF1F5F9); // Slate-100

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      canvasColor: surface,

      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        onPrimary: Colors.white,
        secondary: Color(0xFF00796B),
        onSecondary: Colors.white,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outlineVariant: outline,
        surfaceContainerHighest: surfaceContainer,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryTeal,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: primaryTeal.withValues(alpha: 0.15),
        secondarySelectedColor: primaryTeal,
        labelStyle: const TextStyle(fontSize: 12, color: onSurface),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: primaryTeal, fontWeight: FontWeight.bold),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        hintStyle: const TextStyle(color: onSurfaceVariant, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
      ),
    );
  }

  // =========================================================================
  // DARK THEME
  // =========================================================================
  static ThemeData get darkTheme {
    const background = Color(0xFF0F172A); // Slate-900 charcoal
    const surface = Color(0xFF1E293B);    // Slate-800 card surface
    const onSurface = Color(0xFFF8FAFC);  // Slate-50 high contrast off-white
    const onSurfaceVariant = Color(0xFF94A3B8); // Slate-400 muted text
    const outline = Color(0xFF334155);    // Slate-700 subtle borders
    const surfaceContainer = Color(0xFF334155); // Slate-700 input & container

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkTealAccent,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      canvasColor: surface,

      colorScheme: const ColorScheme.dark(
        primary: darkTealAccent,
        onPrimary: Color(0xFF0F172A),
        secondary: Color(0xFF5EEAD4),
        onSecondary: Color(0xFF0F172A),
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outlineVariant: outline,
        surfaceContainerHighest: surfaceContainer,
        error: Color(0xFFF87171),
        onError: Color(0xFF0F172A),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: darkTealAccent,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: darkTealAccent.withValues(alpha: 0.2),
        secondarySelectedColor: darkTealAccent,
        labelStyle: const TextStyle(fontSize: 12, color: onSurface),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: darkTealAccent, fontWeight: FontWeight.bold),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        hintStyle: const TextStyle(color: onSurfaceVariant, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkTealAccent, width: 1.5),
        ),
      ),
    );
  }
}
