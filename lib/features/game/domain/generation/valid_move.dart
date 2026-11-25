import '../game_models.dart';

/// Board/placement rules used by the generation system.
///
/// Intentionally independent from `GameEngine` so strategies can be tested
/// against arbitrary boards. The engine delegates its `canPlaceBlock` check
/// here to guarantee both paths use identical rules.
abstract final class ValidMove {
  static bool canPlace(
    BlockShape shape,
    int row,
    int col,
    List<List<int>> grid,
  ) {
    final size = grid.length;
    for (final cell in shape.cells) {
      final r = row + cell.row;
      final c = col + cell.col;
      if (r < 0 || c < 0 || r >= size || c >= size) return false;
      if (grid[r][c] >= 0) return false;
    }
    return true;
  }

  static bool hasAnyMove(BlockShape shape, List<List<int>> grid) {
    final size = grid.length;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (canPlace(shape, row, col, grid)) return true;
      }
    }
    return false;
  }

  /// Most rows + columns a single legal placement of [shape] would complete
  /// (0 when it cannot clear anything). Used to feed the player pieces that
  /// can keep a combo chain going.
  static int maxLinesCleared(BlockShape shape, List<List<int>> grid) {
    final size = grid.length;
    var best = 0;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (!canPlace(shape, row, col, grid)) continue;
        final touchedRows = <int>{};
        final touchedCols = <int>{};
        final placed = <int>{};
        for (final cell in shape.cells) {
          touchedRows.add(row + cell.row);
          touchedCols.add(col + cell.col);
          placed.add((row + cell.row) * size + (col + cell.col));
        }
        bool filled(int r, int c) =>
            grid[r][c] >= 0 || placed.contains(r * size + c);
        var lines = 0;
        for (final r in touchedRows) {
          var full = true;
          for (var c = 0; c < size && full; c++) {
            full = filled(r, c);
          }
          if (full) lines++;
        }
        for (final c in touchedCols) {
          var full = true;
          for (var r = 0; r < size && full; r++) {
            full = filled(r, c);
          }
          if (full) lines++;
        }
        if (lines > best) best = lines;
      }
    }
    return best;
  }

  /// True when at least one legal placement of [shape] completes a row or
  /// column.
  static bool canClearLine(BlockShape shape, List<List<int>> grid) =>
      maxLinesCleared(shape, grid) > 0;

  static List<BlockShape> playable(
    Iterable<BlockShape> shapes,
    List<List<int>> grid,
  ) => shapes.where((shape) => hasAnyMove(shape, grid)).toList(growable: false);
}
