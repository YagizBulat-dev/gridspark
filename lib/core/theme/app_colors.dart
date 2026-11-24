import 'package:flutter/material.dart';

/// Obsidian Arcade design tokens (design/obsidian_arcade/DESIGN.md).
abstract final class AppColors {
  // Canvas / surfaces
  static const Color canvas = Color(0xFF0B0D17);
  static const Color deck = Color(0xFF13172A);
  static const Color well = Color(0xFF1A1F38);
  static const Color cellBorder = Color(0x14FFFFFF); // 8% white
  static const Color track = Color(0xFF323B5C);

  // Accents
  static const Color cyan = Color(0xFF00F0FF);
  static const Color cyanBevel = Color(0xFF00A8B3);
  static const Color violet = Color(0xFF8A2BE2);
  static const Color amber = Color(0xFFFFB800);
  static const Color magenta = Color(0xFFFF2A85);

  // Text
  static const Color onSurface = Color(0xFFDEE1FC);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color outline = Color(0xFF849495);
  static const Color outlineVariant = Color(0xFF3B494B);

  /// Block palette: cyan, violet, amber, magenta + supporting hues.
  static const List<Color> blocks = [
    Color(0xFF00F0FF), // cyan
    Color(0xFF8A2BE2), // violet
    Color(0xFFFFB800), // amber
    Color(0xFFFF2A85), // magenta
    Color(0xFF4D7CFF), // blue
    Color(0xFFC77DFF), // lilac
    Color(0xFF3DDC97), // mint
    Color(0xFFFF7A45), // orange
  ];
}
