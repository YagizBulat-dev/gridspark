import 'package:flutter/material.dart';

// Stitch design system colors
class AppTheme {
  // Stitch design system colors
  static const Color darkBackground = Color(0xFF0e1225);
  static const Color darkSurface = Color(0xFF1b1e32);
  static const Color lightSurface = Color(0xFFebf0f7);
  static const Color primaryCyan = Color(0xFF00dbe9);
  static const Color accentAmber = Color(0xFFFFDEA8);
  static const Color surfacePurple = Color(0xFFdcb8ff);
  static const Color onSurface = Color(0xFFdee1fc);
  static const Color onSurfaceVariant = Color(0xFFb9cacb);

  static ThemeData get dark => _theme(Brightness.dark);
  static ThemeData get light => _theme(Brightness.light);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryCyan,
        brightness: brightness,
        // Override specific colors to match Stitch design
        primaryContainer: primaryCyan.withValues(alpha: 0.1),
        onPrimaryContainer: primaryCyan,
        secondaryContainer: surfacePurple.withValues(alpha: 0.1),
        onSecondaryContainer: surfacePurple,
        tertiaryContainer: accentAmber.withValues(alpha: 0.1),
        onTertiaryContainer: accentAmber,
        surface: isDark ? darkBackground : lightSurface,
        onSurface: onSurface,
        surfaceVariant: isDark ? Color(0xFF303448) : Color(0xFFF0F2F5),
        outline: onSurfaceVariant,
        inverseSurface: isDark ? Color(0xFFb3c0e7) : Color(0xFF1c212a),
        inversePrimary: primaryCyan.withValues(alpha: 0.2),
      ),
      scaffoldBackgroundColor: isDark ? darkBackground : lightSurface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? Color(0xFF25293d) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black87,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          foregroundColor: primaryCyan,
          side: BorderSide(color: primaryCyan.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}