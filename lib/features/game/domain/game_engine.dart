import 'dart:math';

import 'game_models.dart';
import 'block_generator.dart';

class GameEngine {
  GameEngine({this.size = 8, Random? random})
      : random = random ?? Random(),
        _blockGenerator = BlockGenerator(random: random) {
    grid = List.generate(size, (_) => List<int>.filled(size, -1));
  }

  final int size;
  final Random random;
  final BlockGenerator _blockGenerator;
  late List<List<int>> grid;
  int score = 0;
  int moves = 0;

  // Rising difficulty constants
  static const risingDifficultyThresholds = [1250, 3750];
  static const risingDifficultyMaxCells = [2, 4, 5];

  int difficultyLevelForScore(int score) {
    var level = 0;
    for (final threshold in risingDifficultyThresholds) {
      if (score >= threshold) level++;
    }
    return level.clamp(0, risingDifficultyMaxCells.length - 1);
  }

  int _maxCellsForMode(GameMode mode) {
    if (mode == GameMode.rising) return risingDifficultyMaxCells[difficultyLevelForScore(score)];
    // Use maxTrayCells constant for larger tray pieces (up to 7 cells)
    return maxTrayCells;
  }

  void reset() {
    grid = List.generate(size, (_) => List<int>.filled(size, -1));
    score = 0;
    moves = 0;
  }

  void restore({
    required List<List<int>> restoredGrid,
    required int restoredScore,
    required int restoredMoves,
  }) {
    if (!isValidGrid(restoredGrid, expectedSize: size)) {
      if (restoredGrid.length != size ||
          restoredGrid.any((row) => row.length != size)) {
        throw ArgumentError('Snapshot grid does not match engine size.');
      }
      throw ArgumentError('Snapshot grid contains an invalid cell value.');
    }
    if (!isValidScoreAndMoves(restoredScore, restoredMoves)) {
      throw ArgumentError('Snapshot score or move count is invalid.');
    }
    grid = restoredGrid.map(List<int>.from).toList();
    score = restoredScore;
    moves = restoredMoves;
  }

  static bool isValidGrid(
    List<List<int>> candidate, {
    int expectedSize = snapshotGridSize,
  }) {
    if (candidate.length != expectedSize ||
        candidate.any((row) => row.length != expectedSize)) {
      return false;
    }
    return candidate
        .expand((row) => row)
        .every((cell) => cell >= -1 && cell < blockColorCount);
  }

  static bool isValidScoreAndMoves(int score, int moves) {
    if (score < 0 || score > maxSnapshotScore) return false;
    if (moves < 0 || moves > maxSnapshotMoves) return false;
    return (moves == 0 && score == 0) || (moves > 0 && score >= moves * 10);
  }

  bool canPlaceBlock(BlockShape shape, int row, int col) =>
      shape.cells.every((cell) {
        final r = row + cell.row;
        final c = col + cell.col;
        return r >= 0 && c >= 0 && r < size && c < size && grid[r][c] == -1;
      });

  /// Backward-compatible alias for [canPlaceBlock].
  bool canPlace(BlockShape shape, int row, int col) =>
      canPlaceBlock(shape, row, col);

  /// Detects full rows and columns on the current grid and returns the set of
  /// cells that would be cleared. Pure read — does not mutate [grid].
  /// Shared by [place] and [clearLines] so the two clearing paths can never
  /// diverge (DRY).
  ({List<int> rows, List<int> cols, Set<CellOffset> cells}) _detectFullLines() {
    final rows = <int>[];
    final cols = <int>[];
    for (var i = 0; i < size; i++) {
      if (grid[i].every((cell) => cell >= 0)) rows.add(i);
      if (List.generate(size, (r) => grid[r][i]).every((cell) => cell >= 0)) {
        cols.add(i);
      }
    }
    final cells = <CellOffset>{};
    for (final rowIndex in rows) {
      for (var c = 0; c < size; c++) {
        cells.add(CellOffset(rowIndex, c));
      }
    }
    for (final colIndex in cols) {
      for (var r = 0; r < size; r++) {
        cells.add(CellOffset(r, colIndex));
      }
    }
    return (rows: rows, cols: cols, cells: cells);
  }

  int clearLines() {
    final (:rows, :cols, :cells) = _detectFullLines();
    if (rows.isEmpty && cols.isEmpty) return 0;

    for (final cell in cells) {
      grid[cell.row][cell.col] = -1;
    }
    final lines = rows.length + cols.length;
    // Mirror the line-clear portion of [place]'s scoring so a standalone clear
    // (e.g. via GameStore.clearLines) awards the same combo points.
    score += lines * lines * 250;
    return lines;
  }

  PlacementResult place(BlockShape shape, int row, int col) {
    if (!canPlaceBlock(shape, row, col)) {
      return const PlacementResult(placed: false, lines: 0, points: 0);
    }
    final placedCells = <CellOffset>[
      for (final cell in shape.cells) CellOffset(row + cell.row, col + cell.col),
    ];
    for (final cell in placedCells) {
      grid[cell.row][cell.col] = shape.colorIndex;
    }
    moves++;
    final (:rows, :cols, :cells) = _detectFullLines();
    for (final cell in cells) {
      grid[cell.row][cell.col] = -1;
    }
    final lines = rows.length + cols.length;
    final points = shape.cells.length * 25 + lines * lines * 250;
    score += points;
    return PlacementResult(
      placed: true,
      lines: lines,
      points: points,
      placedCells: List.unmodifiable(placedCells),
      clearedCells: List.unmodifiable(cells),
    );
  }

  void addScoreBonus(int points) {
    if (points < 0 || score + points > maxSnapshotScore) {
      throw ArgumentError.value(points, 'points', 'Invalid score bonus.');
    }
    score += points;
  }

  List<BlockShape> generateTray(GameMode mode) {
    return _blockGenerator.generateTray(mode, maxCells: _maxCellsForMode(mode));
  }

  /// Generates one random tray shape for [mode] without requiring that it
  /// fits on the current board. Tray refills use this so the board can fill
  /// up over time and the game can still end when nothing fits.
  BlockShape? generateTrayShape(
    GameMode mode, {
    Iterable<String> excludingIds = const [],
  }) {
    final excluded = excludingIds.toSet();
    final candidates = ShapeCatalog.all
        .where((shape) => !excluded.contains(shape.id))
        .where((shape) => ShapeCatalog.isAllowedInMode(shape, mode))
        .where((shape) => shape.cells.length <= _maxCellsForMode(mode))
        .toList()
      ..shuffle(random);
    return candidates.firstOrNull;
  }

  BlockShape? generatePlayableShape(
    GameMode mode, {
    Iterable<String> excludingIds = const [],
  }) {
    final candidates = ShapeCatalog.all
        .where(
          (shape) =>
              !excludingIds.toSet().contains(shape.id) &&
              ShapeCatalog.isAllowedInMode(shape, mode) &&
              shape.cells.length <= _maxCellsForMode(mode) &&
              hasAnyMove([shape]),
        )
        .toList()
      ..shuffle(random);
    return candidates.firstOrNull;
  }

  bool hasAnyMove(Iterable<BlockShape?> shapes) {
    for (final shape in shapes) {
      if (shape == null) continue;
      for (var row = 0; row < size; row++) {
        for (var col = 0; col < size; col++) {
          if (canPlaceBlock(shape, row, col)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
