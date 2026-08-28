import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF7C5CFF);

  static ThemeData get dark => _theme(Brightness.dark);
  static ThemeData get light => _theme(Brightness.light);

  static ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF10111A)
          : const Color(0xFFF6F5FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
