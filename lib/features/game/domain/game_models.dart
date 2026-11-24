import 'dart:math';

enum GameMode { classic, timed, rising }

extension GameModeDisplayName on GameMode {
  String get displayName => switch (this) {
        GameMode.classic => 'Classic',
        GameMode.timed => 'Time Attack',
        GameMode.rising => 'Rising Difficulty',
      };
}

const blockColorCount = 8;
const snapshotGridSize = 8;
const snapshotTraySize = 3;
const maxSnapshotScore = 10000000;
const maxSnapshotMoves = 1000000;
const maxTimedGameSeconds = 120;
const maxTrayCells = 7; // Max cells per tray shape (artı 5'ten 7'ye)

class CellOffset {
  const CellOffset(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is CellOffset && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
}

class BlockShape {
  const BlockShape(this.id, this.cells, {this.colorIndex = 0});
  final String id;
  final List<CellOffset> cells;
  final int colorIndex;
  int get width => cells.map((e) => e.col).reduce(max) + 1;
  int get height => cells.map((e) => e.row).reduce(max) + 1;
}

abstract final class ShapeCatalog {
  static const all = <BlockShape>[
    BlockShape('single', [CellOffset(0, 0)], colorIndex: 0),
    BlockShape('h2', [CellOffset(0, 0), CellOffset(0, 1)], colorIndex: 1),
    BlockShape('v2', [CellOffset(0, 0), CellOffset(1, 0)], colorIndex: 1),
    BlockShape('h3', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
    ], colorIndex: 2),
    BlockShape('v3', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
    ], colorIndex: 2),
    BlockShape('h4', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(0, 3),
    ], colorIndex: 3),
    BlockShape('v4', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(3, 0),
    ], colorIndex: 3),
    BlockShape('square', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
    ], colorIndex: 4),
    BlockShape('l3', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(1, 1),
    ], colorIndex: 5),
    BlockShape('j3', [
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
    ], colorIndex: 5),
    BlockShape('l4', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(2, 1),
    ], colorIndex: 6),
    BlockShape('t4', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 1),
    ], colorIndex: 6),
    BlockShape('s4', [
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 0),
      CellOffset(1, 1),
    ], colorIndex: 7),
    BlockShape('plus', [
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(1, 2),
      CellOffset(2, 1),
    ], colorIndex: 7),
    BlockShape('corner5', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(2, 1),
      CellOffset(2, 2),
    ], colorIndex: 0),
    // Bigger shapes for enhanced gameplay
    BlockShape('h5', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(0, 3),
      CellOffset(0, 4),
    ], colorIndex: 3),
    BlockShape('v5', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(3, 0),
      CellOffset(4, 0),
    ], colorIndex: 3),
    BlockShape('cross', [
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(1, 2),
      CellOffset(2, 1),
    ], colorIndex: 7),
    BlockShape('bigL', [
      CellOffset(0, 0),
      CellOffset(1, 0),
      CellOffset(2, 0),
      CellOffset(2, 1),
      CellOffset(3, 1),
    ], colorIndex: 6),
    BlockShape('bigT', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 1),
      CellOffset(2, 1),
    ], colorIndex: 6),
    BlockShape('bigPlus', [
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(1, 2),
      CellOffset(2, 1),
    ], colorIndex: 7),
  ];

  static BlockShape? byId(String id) {
    for (final shape in all) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  static bool isAllowedInMode(BlockShape shape, GameMode mode) =>
      switch (mode) {
        GameMode.classic => true,
        GameMode.timed => shape.cells.length >= 2,
        GameMode.rising => true, // difficulty filtering is dynamic
      };

  static bool isValidSnapshotId(String id, GameMode mode) {
    final shape = byId(id);
    return shape != null && isAllowedInMode(shape, mode);
  }
}

class PlacementResult {
  const PlacementResult({
    required this.placed,
    required this.lines,
    required this.points,
    this.placedCells = const [],
    this.clearedCells = const [],
  });
  final bool placed;
  final int lines;
  final int points;
  final List<CellOffset> placedCells;
  final List<CellOffset> clearedCells;
}
