import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/domain/game_engine.dart';
import 'package:gridspark/features/game/domain/game_models.dart';

void main() {
  group('GameEngine', () {
    test('creates an empty 8x8 grid', () {
      final game = GameEngine();
      expect(game.grid.length, 8);
      expect(
        game.grid.expand((row) => row).every((cell) => cell == -1),
        isTrue,
      );
    });
    test('places a valid shape', () {
      final game = GameEngine();
      final result = game.place(ShapeCatalog.all[1], 0, 0);
      expect(result.placed, isTrue);
      expect(game.grid[0][0], isNot(-1));
      expect(game.grid[0][1], isNot(-1));
    });
    test('rejects out of bounds placement', () {
      expect(GameEngine().place(ShapeCatalog.all[3], 0, 7).placed, isFalse);
    });
    test('rejects overlap', () {
      final game = GameEngine();
      game.place(ShapeCatalog.all.first, 2, 2);
      expect(game.canPlaceBlock(ShapeCatalog.all.first, 2, 2), isFalse);
    });

    test('places a shape in the bottom-right corner cell (7,7)', () {
      final game = GameEngine();
      expect(game.canPlaceBlock(ShapeCatalog.all.first, 7, 7), isTrue);
      final result = game.place(ShapeCatalog.all.first, 7, 7);
      expect(result.placed, isTrue);
      expect(game.grid[7][7], isNot(-1));
    });

    test('places a 2x2 block flush against the bottom-right edge', () {
      final game = GameEngine();
      final square =
          ShapeCatalog.all.firstWhere((s) => s.id == 'square');
      expect(game.canPlaceBlock(square, 6, 6), isTrue);
      final result = game.place(square, 6, 6);
      expect(result.placed, isTrue);
      for (final r in [6, 7]) {
        for (final c in [6, 7]) {
          expect(game.grid[r][c], isNot(-1));
        }
      }
    });
    test('clears a completed row', () {
      final game = GameEngine();
      for (var col = 0; col < 7; col++) {
        game.grid[0][col] = 0;
      }
      final result = game.place(ShapeCatalog.all.first, 0, 7);
      expect(result.lines, 1);
      expect(game.grid[0].every((cell) => cell == -1), isTrue);
    });
    test('clears a completed column', () {
      final game = GameEngine();
      for (var row = 0; row < 7; row++) {
        game.grid[row][0] = 0;
      }
      expect(game.place(ShapeCatalog.all.first, 7, 0).lines, 1);
    });
    test('awards combo points for simultaneous row and column', () {
      final game = GameEngine();
      for (var i = 0; i < 7; i++) {
        game.grid[7][i] = 0;
        game.grid[i][7] = 0;
      }
      final result = game.place(ShapeCatalog.all.first, 7, 7);
      expect(result.lines, 2);
      expect(result.points, 1025); // 1 hücre *25 + 2²*250 = 1025
      expect(result.clearedCells, hasLength(15));
      expect(result.clearedCells, contains(const CellOffset(7, 7)));
    });

    test('populates placedCells with grid coordinates', () {
      final game = GameEngine();
      final h2 = ShapeCatalog.all.firstWhere((s) => s.id == 'h2');
      final result = game.place(h2, 3, 5);
      expect(result.placed, isTrue);
      expect(result.placedCells, [
        const CellOffset(3, 5),
        const CellOffset(3, 6),
      ]);
    });

    test('placedCells and clearedCells are disjoint after line clear', () {
      final game = GameEngine();
      for (var c = 0; c < 7; c++) {
        game.grid[0][c] = 0;
      }
      // Place single at (0,7) → completes row 0, which is cleared.
      final result = game.place(ShapeCatalog.all.first, 0, 7);
      expect(result.placed, isTrue);
      expect(result.placedCells, [const CellOffset(0, 7)]);
      expect(result.clearedCells, hasLength(8));
      expect(result.clearedCells, contains(const CellOffset(0, 7)));
      // placedCells intersection with clearedCells: the just-placed cell is
      // both placed and cleared (row completed), but the two lists can overlap.
    });
    test('detects game over when no shape fits', () {
      final game = GameEngine();
      for (final row in game.grid) {
        for (var i = 0; i < row.length; i++) {
          row[i] = 0;
        }
      }
      expect(game.hasAnyMove([ShapeCatalog.all.first]), isFalse);
    });
    test('generates three mode-aware shapes', () {
      final tray = GameEngine(random: Random(1)).generateTray(GameMode.rising);
      expect(tray, hasLength(3));
      // At score 0, difficulty level 0 → maxCells = 2
      expect(tray.every((shape) => shape.cells.length <= 2), isTrue);
      expect(tray.map((shape) => shape.id).toSet(), hasLength(3));
    });
    test('rejects invalid snapshot cell values without mutating state', () {
      final game = GameEngine();
      final grid = List.generate(8, (_) => List<int>.filled(8, -1));
      grid[0][0] = blockColorCount;

      expect(
        () => game.restore(
          restoredGrid: grid,
          restoredScore: 10,
          restoredMoves: 1,
        ),
        throwsArgumentError,
      );
      expect(
        game.grid.expand((row) => row).every((cell) => cell == -1),
        isTrue,
      );
      expect(game.score, 0);
      expect(game.moves, 0);
    });
    test(
      'catalog contains fifteen shapes',
      () => expect(ShapeCatalog.all, hasLength(15)),
    );
  });

  group('canPlaceBlock', () {
    test('returns true for valid placement', () {
      final game = GameEngine();
      expect(game.canPlaceBlock(ShapeCatalog.all.first, 0, 0), isTrue);
    });

    test('rejects out-of-bounds placement', () {
      final game = GameEngine();
      expect(game.canPlaceBlock(ShapeCatalog.all[3], 0, 7), isFalse);
    });

    test('rejects partial overlap (one cell of shape hits occupied cell)', () {
      final game = GameEngine();
      // Place a 2x2 square at (0,0) to occupy (0,0), (0,1), (1,0), (1,1)
      final square = ShapeCatalog.all.firstWhere((s) => s.id == 'square');
      expect(game.canPlaceBlock(square, 0, 0), isTrue);
      game.place(square, 0, 0);
      // Now try to place an L-shape that partially overlaps the square.
      // L-shape cells: (0,0), (0,1), (1,0) — the (0,0) cell is already occupied.
      final lShape = ShapeCatalog.all.firstWhere((s) => s.id == 'l3');
      // Try placing l3 at (0,0) — should fail because (0,0) is occupied
      expect(game.canPlaceBlock(lShape, 0, 0), isFalse);
      // Try placing l3 at (0,1) — should also fail because (0,1) is occupied
      expect(game.canPlaceBlock(lShape, 0, 1), isFalse);
      // Try placing l3 at (1,0) — should also fail because (1,0) is occupied
      expect(game.canPlaceBlock(lShape, 1, 0), isFalse);
      // Try a valid placement that doesn't overlap
      expect(game.canPlaceBlock(lShape, 2, 2), isTrue);
    });

    test('canPlace is an alias for canPlaceBlock', () {
      final game = GameEngine();
      final shape = ShapeCatalog.all.first;
      expect(game.canPlace(shape, 0, 0), game.canPlaceBlock(shape, 0, 0));
    });
  });

  group('clearLines', () {
    test('clears a full row', () {
      final game = GameEngine();
      for (var c = 0; c < 8; c++) {
        game.grid[0][c] = 0;
      }
      final cleared = game.clearLines();
      expect(cleared, 1);
      expect(game.grid[0].every((cell) => cell == -1), isTrue);
    });

    test('clears a full column', () {
      final game = GameEngine();
      for (var r = 0; r < 8; r++) {
        game.grid[r][0] = 0;
      }
      final cleared = game.clearLines();
      expect(cleared, 1);
      expect(game.grid.every((row) => row[0] == -1), isTrue);
    });

    test('clears simultaneous row and column (combo)', () {
      final game = GameEngine();
      for (var i = 0; i < 8; i++) {
        game.grid[0][i] = 0;
        game.grid[i][0] = 0;
      }
      final cleared = game.clearLines();
      expect(cleared, 2);
    });

    test('returns 0 when no lines are complete', () {
      final game = GameEngine();
      game.grid[0][0] = 0;
      expect(game.clearLines(), 0);
    });

    test('awards combo points consistent with place()', () {
      // Regression guard for the latent bug where engine.clearLines() cleared
      // lines but added no score, leaving GameStore.clearLines() (the only
      // caller) silently inconsistent with place().
      final game = GameEngine();
      for (var c = 0; c < 8; c++) {
        game.grid[0][c] = 0;
      }
      final cleared = game.clearLines();
      expect(cleared, 1);
      expect(game.score, 250); // 1*1*250
    });

    test('awards quadratic combo points for simultaneous row and column', () {
      final game = GameEngine();
      for (var i = 0; i < 8; i++) {
        game.grid[0][i] = 0;
        game.grid[i][0] = 0;
      }
      final cleared = game.clearLines();
      expect(cleared, 2);
      expect(game.score, 1000); // 2*2*250
    });
  });

  group('rising difficulty', () {
    test('difficultyLevelForScore returns correct levels', () {
      final game = GameEngine();
      expect(game.difficultyLevelForScore(0), 0);
      expect(game.difficultyLevelForScore(499), 0);
      expect(game.difficultyLevelForScore(1249), 0); // below new threshold 1250
      expect(game.difficultyLevelForScore(1250), 1); // reaches new threshold 1250
      expect(game.difficultyLevelForScore(3749), 1); // below new threshold 3750
      expect(game.difficultyLevelForScore(3750), 2); // reaches new threshold 3750
      expect(game.difficultyLevelForScore(10000), 2); // max level
    });

    test('rising mode at difficulty 0 generates only ≤2 cell shapes', () {
      final game = GameEngine(random: Random(1));
      game.score = 0;
      final tray = game.generateTray(GameMode.rising);
      expect(tray.every((s) => s.cells.length <= 2), isTrue);
    });

    test('rising mode at difficulty 1 generates ≤4 cell shapes', () {
      final game = GameEngine(random: Random(1));
      game.score = 1250; // new threshold for level 1
      final tray = game.generateTray(GameMode.rising);
      expect(tray.every((s) => s.cells.length <= 4), isTrue);
      expect(tray.map((shape) => shape.id).toSet(), hasLength(3));
    });

    test('rising mode at difficulty 2 generates all shapes', () {
      final game = GameEngine(random: Random(1));
      game.score = 3750; // new threshold for level 2
      final tray = game.generateTray(GameMode.rising);
      expect(tray, hasLength(3));
      // At max difficulty, shapes up to 5 cells are allowed
      expect(tray.every((s) => s.cells.length <= 5), isTrue);
    });
  });
}
