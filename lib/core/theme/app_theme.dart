import 'package:flutter/material.dart';

class AppTheme {
  // Theme state: true = Dark Mode, false = Light Mode
  static bool _isDark = true;
  static bool get isDark => _isDark;

  static void setBrightness(Brightness brightness) {
    _isDark = (brightness == Brightness.dark);
  }

  // Dynamic colors that all existing code accesses directly
  static Color get background => _isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
  static Color get surfaceCard => _isDark ? const Color(0xFF161E2E) : Colors.white;
  static Color get cardBorder => _isDark ? const Color(0xFF243046) : const Color(0xFFE2E8F0);

  // Accent Mind States (Universal)
  static const Color mint = Color(0xFF10B981);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color glitchCoral = Color(0xFFEF4444);

  // Dynamic text colors
  static Color get textPrimary => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Light ThemeData
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    primaryColor: mint,
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: mint,
      secondary: cyan,
      error: glitchCoral,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),
  );

  // Dark ThemeData
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B0F17),
    primaryColor: mint,
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF161E2E),
      primary: mint,
      secondary: cyan,
      error: glitchCoral,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF161E2E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF243046), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B0F17),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
    ),
  );
}
