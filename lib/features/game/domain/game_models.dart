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
const maxTrayCells = 9; // Max cells per tray shape (artı 5'ten 7'ye)

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
  const BlockShape(
    this.id,
    this.cells, {
    this.colorIndex = 0,
    this.weight = 1.0,
  });
  final String id;
  final List<CellOffset> cells;
  final int colorIndex;

  /// Relative spawn frequency (0 = never generated, 1 = common). Big and
  /// awkward pieces are rare so the board stays fluid and combos stay possible.
  final double weight;
  int get width => cells.map((e) => e.col).reduce(max) + 1;
  int get height => cells.map((e) => e.row).reduce(max) + 1;
}

abstract final class ShapeCatalog {
  /// Every shape, including all rotations/mirrors. The first entries keep their
  /// original order so older snapshots and tests stay valid.
  static final List<BlockShape> all = _buildAll();

  static const _base = <BlockShape>[
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
    // Larger rectangular shapes: 2x3, 3x2 and full 3x3 blocks.
    BlockShape('rect2x3', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(1, 2),
    ], colorIndex: 2),
    BlockShape('rect3x2', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(2, 0),
      CellOffset(2, 1),
    ], colorIndex: 4),
    BlockShape('square3x3', [
      CellOffset(0, 0),
      CellOffset(0, 1),
      CellOffset(0, 2),
      CellOffset(1, 0),
      CellOffset(1, 1),
      CellOffset(1, 2),
      CellOffset(2, 0),
      CellOffset(2, 1),
      CellOffset(2, 2),
    ], colorIndex: 5),
  ];

  /// Spawn weights per base shape id (orientations inherit the base weight).
  static const _weights = <String, double>{
    'single': 0.12,
    'h2': 0.9, 'v2': 0.9,
    'h3': 1.0, 'v3': 1.0,
    'h4': 0.75, 'v4': 0.75,
    'h5': 0.4, 'v5': 0.4,
    'square': 1.0,
    'l3': 1.0, 'j3': 1.0,
    'l4': 0.5, 't4': 0.6, 's4': 0.55,
    'corner5': 0.3,
    'bigL': 0.2, 'bigT': 0.2,
    'plus': 0.3,
    'cross': 0.0, 'bigPlus': 0.0, // identical to 'plus'; kept for old snapshots
    'rect2x3': 0.45, 'rect3x2': 0.45,
    'square3x3': 0.15,
  };

  /// Families that get every rotation (and mirror) added as extra shapes.
  static const _rotate = <String>['l3', 'l4', 't4', 's4', 'corner5'];
  static const _mirror = <String>['l3', 'l4', 's4'];

  static List<CellOffset> _normalize(Iterable<CellOffset> cells) {
    final minR = cells.map((c) => c.row).reduce(min);
    final minC = cells.map((c) => c.col).reduce(min);
    final out = [for (final c in cells) CellOffset(c.row - minR, c.col - minC)]
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    return out;
  }

  static String _key(List<CellOffset> cells) =>
      cells.map((c) => '${c.row},${c.col}').join(';');

  static List<BlockShape> _buildAll() {
    final result = <BlockShape>[];
    final seen = <String>{};
    for (final b in _base) {
      final w = _weights[b.id] ?? 1.0;
      result.add(
        BlockShape(b.id, b.cells, colorIndex: b.colorIndex, weight: w),
      );
      seen.add(_key(_normalize(b.cells)));
    }
    for (final b in _base) {
      if (!_rotate.contains(b.id)) continue;
      final w = _weights[b.id] ?? 1.0;
      var variants = <List<CellOffset>>[b.cells];
      if (_mirror.contains(b.id)) {
        variants.add([for (final c in b.cells) CellOffset(c.row, -c.col)]);
      }
      var n = 1;
      for (final v in variants) {
        var cur = v;
        for (var r = 0; r < 4; r++) {
          cur = [for (final c in cur) CellOffset(c.col, -c.row)]; // rotate 90°
          final norm = _normalize(cur);
          if (seen.add(_key(norm))) {
            result.add(
              BlockShape(
                '${b.id}_$n',
                norm,
                colorIndex: b.colorIndex,
                weight: w,
              ),
            );
            n++;
          }
        }
      }
    }
    return List.unmodifiable(result);
  }

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
