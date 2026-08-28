import 'dart:math';

import 'game_models.dart';

class BlockGenerator {
  BlockGenerator({Random? random}) : _random = random ?? Random();
  final Random _random;

  /// Generates [snapshotTraySize] random block shapes for the given [mode].
  /// For [GameMode.rising], [maxCells] controls difficulty-based filtering.
  List<BlockShape> generateTray(GameMode mode, {int maxCells = 5}) {
    final pool = ShapeCatalog.all
        .where((s) => ShapeCatalog.isAllowedInMode(s, mode))
        .where((s) => s.cells.length <= maxCells)
        .toList()
      ..shuffle(_random);
    return pool.take(snapshotTraySize).toList();
  }

  /// Generates a single playable shape, excluding given IDs, respecting maxCells.
  BlockShape? generatePlayableShape(
    GameMode mode, {
    Iterable<String> excludingIds = const [],
    int maxCells = 5,
  }) {
    final excluded = excludingIds.toSet();
    final candidates = ShapeCatalog.all
        .where((s) => !excluded.contains(s.id))
        .where((s) => ShapeCatalog.isAllowedInMode(s, mode))
        .where((s) => s.cells.length <= maxCells)
        .toList()
      ..shuffle(_random);
    return candidates.firstOrNull;
  }
}
