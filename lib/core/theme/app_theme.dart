import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Obsidian Arcade theme. The design is dark-only, so [light] and [dark]
/// resolve to the same theme.
class AppTheme {
  static ThemeData get dark => _build();
  static ThemeData get light => _build();

  // Typography helpers (Sora = headlines/scores, Plus Jakarta Sans = body,
  // Space Grotesk = labels/counters).
  static TextStyle sora(
    double size, {
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.sora(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w700,
    color: color ?? AppColors.onSurface,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle jakarta(
    double size, {
    FontWeight? weight,
    Color? color,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w400,
    color: color ?? AppColors.onSurface,
    height: height,
  );

  static TextStyle grotesk(
    double size, {
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w700,
    color: color ?? AppColors.onSurfaceVariant,
    letterSpacing: letterSpacing ?? 0.6,
  );

  static ThemeData _build() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.cyan,
      onPrimary: AppColors.canvas,
      primaryContainer: Color(0xFF00363A),
      onPrimaryContainer: AppColors.cyan,
      secondary: AppColors.violet,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF3A0F66),
      onSecondaryContainer: Color(0xFFDCB8FF),
      tertiary: AppColors.amber,
      onTertiary: Color(0xFF271900),
      tertiaryContainer: Color(0xFF5E4200),
      onTertiaryContainer: Color(0xFFFFDEA8),
      error: AppColors.magenta,
      onError: Colors.white,
      surface: AppColors.canvas,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: Color(0xFF090D20),
      surfaceContainerLow: Color(0xFF0F1224),
      surfaceContainer: AppColors.deck,
      surfaceContainerHigh: AppColors.well,
      surfaceContainerHighest: Color(0xFF232846),
      inverseSurface: AppColors.onSurface,
      onInverseSurface: AppColors.canvas,
      inversePrimary: AppColors.cyanBevel,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
    );

    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: sora(48, weight: FontWeight.w800, letterSpacing: -0.96),
      displayMedium: sora(36, weight: FontWeight.w800, letterSpacing: -0.72),
      headlineLarge: sora(32, letterSpacing: -0.32),
      headlineMedium: sora(26, letterSpacing: -0.26),
      headlineSmall: sora(22, weight: FontWeight.w600),
      titleLarge: sora(18, weight: FontWeight.w600),
      titleMedium: jakarta(16, weight: FontWeight.w600),
      bodyLarge: jakarta(16, weight: FontWeight.w500, height: 1.5),
      bodyMedium: jakarta(14, height: 1.43),
      bodySmall: jakarta(12, color: AppColors.onSurfaceVariant),
      labelLarge: grotesk(14, letterSpacing: 0.56),
      labelMedium: grotesk(12, letterSpacing: 0.9),
      labelSmall: grotesk(11, letterSpacing: 0.9),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: sora(18, weight: FontWeight.w600),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.deck.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.deck,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.35)),
        ),
        titleTextStyle: sora(20, weight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        hintStyle: jakarta(14, color: AppColors.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.canvas
              : AppColors.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.cyan
              : AppColors.track,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.well,
        contentTextStyle: jakarta(14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.cyan,
          foregroundColor: AppColors.canvas,
          textStyle: sora(16, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
          textStyle: jakarta(14, weight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        space: 1,
      ),
    );
  }
}
