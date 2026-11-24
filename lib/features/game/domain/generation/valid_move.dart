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

  static List<BlockShape> playable(
    Iterable<BlockShape> shapes,
    List<List<int>> grid,
  ) =>
      shapes.where((shape) => hasAnyMove(shape, grid)).toList(growable: false);
}
