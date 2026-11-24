/// Pure, immutable analysis of a game board.
///
/// Lives outside the game engine so generation strategies can be exercised
/// against hundreds of synthetic boards without constructing a [GameEngine].
class BoardAnalysis {
  const BoardAnalysis({
    required this.size,
    required this.filledCells,
    required this.emptyCells,
    required this.occupancy,
    required this.widestOpenRun,
    required this.isolatedEmptyCells,
  });

  final int size;
  final int filledCells;
  final int emptyCells;

  /// 0.0 (empty) .. 1.0 (full).
  final double occupancy;

  /// Longest consecutive empty stretch in any row or column.
  final int widestOpenRun;

  /// Empty cells with no empty orthogonal neighbour (dead holes).
  final int isolatedEmptyCells;

  factory BoardAnalysis.of(List<List<int>> grid) {
    final size = grid.length;
    var filled = 0;
    var widest = 0;
    for (var r = 0; r < size; r++) {
      var run = 0;
      for (var c = 0; c < size; c++) {
        if (grid[r][c] >= 0) {
          filled++;
          run = 0;
        } else {
          run++;
          if (run > widest) widest = run;
        }
      }
    }
    for (var c = 0; c < size; c++) {
      var run = 0;
      for (var r = 0; r < size; r++) {
        if (grid[r][c] >= 0) {
          run = 0;
        } else {
          run++;
          if (run > widest) widest = run;
        }
      }
    }
    var isolated = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c] >= 0) continue;
        final neighbours = <List<int>>[
          if (r > 0) [r - 1, c],
          if (r + 1 < size) [r + 1, c],
          if (c > 0) [r, c - 1],
          if (c + 1 < size) [r, c + 1],
        ];
        if (neighbours.every((p) => grid[p[0]][p[1]] >= 0)) isolated++;
      }
    }
    final total = size * size;
    return BoardAnalysis(
      size: size,
      filledCells: filled,
      emptyCells: total - filled,
      occupancy: total == 0 ? 0 : filled / total,
      widestOpenRun: widest,
      isolatedEmptyCells: isolated,
    );
  }

  bool get isCrowded => occupancy >= 0.55;
  bool get isCritical => occupancy >= 0.72;

  @override
  String toString() =>
      'BoardAnalysis(occupancy: ${occupancy.toStringAsFixed(2)}, '
      'widestOpenRun: $widestOpenRun, isolated: $isolatedEmptyCells)';
}
