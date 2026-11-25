import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/domain/block_generator.dart';
import 'package:gridspark/features/game/domain/game_engine.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:gridspark/features/game/domain/generation/board_analysis.dart';
import 'package:gridspark/features/game/domain/generation/generation_context.dart';
import 'package:gridspark/features/game/domain/generation/generation_strategies.dart';
import 'package:gridspark/features/game/domain/generation/piece_generation_system.dart';
import 'package:gridspark/features/game/domain/generation/valid_move.dart';

List<List<int>> emptyBoard([int size = 8]) => List.generate(
      size,
      (_) => List<int>.filled(size, -1),
    );

GenerationContext contextFor(
  List<List<int>> grid, {
  GameMode mode = GameMode.classic,
  int maxCells = maxTrayCells,
  int moves = 0,
  int difficultyLevel = 0,
  Set<String> excludingIds = const <String>{},
  GenerationPolicy policy = GenerationPolicy.random,
  List<String> recipe = const <String>[],
}) =>
    GenerationContext(
      mode: mode,
      grid: grid,
      score: 0,
      moves: moves,
      maxCells: maxCells,
      difficultyLevel: difficultyLevel,
      excludingIds: excludingIds,
      policy: policy,
      recipe: recipe,
    );

void main() {
  group('BoardAnalysis', () {
    test('empty and full boards', () {
      final empty = BoardAnalysis.of(emptyBoard(4));
      expect(empty.filledCells, 0);
      expect(empty.occupancy, 0);
      expect(empty.widestOpenRun, 4);
      expect(empty.isCrowded, isFalse);

      final full = List.generate(4, (_) => List<int>.filled(4, 2));
      final analysis = BoardAnalysis.of(full);
      expect(analysis.filledCells, 16);
      expect(analysis.occupancy, 1);
      expect(analysis.widestOpenRun, 0);
      expect(analysis.isCritical, isTrue);
    });

    test('detects isolated empty cells', () {
      final grid = List.generate(3, (_) => List<int>.filled(3, 0));
      grid[1][1] = -1;
      expect(BoardAnalysis.of(grid).isolatedEmptyCells, 1);
    });
  });

  group('ValidMove', () {
    test('respects bounds, occupancy and shape offsets', () {
      final grid = emptyBoard(3);
      grid[0][0] = 1;
      final shape = ShapeCatalog.byId('h2')!;
      expect(ValidMove.canPlace(shape, 0, 0, grid), isFalse);
      expect(ValidMove.canPlace(shape, 0, 1, grid), isTrue);
      expect(ValidMove.canPlace(shape, 0, 2, grid), isFalse);
      expect(ValidMove.canPlace(shape, 2, 2, grid), isFalse);
      expect(ValidMove.hasAnyMove(shape, grid), isTrue);
    });

    test('rejects a shape when board is full', () {
      final full = List.generate(3, (_) => List<int>.filled(3, 1));
      expect(ValidMove.hasAnyMove(ShapeCatalog.byId('single')!, full), isFalse);
      expect(
        ValidMove.playable([ShapeCatalog.byId('single')!], full),
        isEmpty,
      );
    });

    test('canClearLine detects placements that complete a row or column', () {
      final grid = emptyBoard(4);
      for (var col = 0; col < 3; col++) {
        grid[0][col] = 1;
      }
      for (var row = 0; row < 3; row++) {
        grid[row][1] = 1;
      }

      expect(ValidMove.canClearLine(ShapeCatalog.byId('single')!, grid), isTrue);
      expect(ValidMove.canClearLine(ShapeCatalog.byId('v2')!, grid), isTrue);
      // On an empty board a small piece cannot finish a line by itself.
      expect(
        ValidMove.canClearLine(ShapeCatalog.byId('single')!, emptyBoard(4)),
        isFalse,
      );
    });
  });

  group('PieceGenerationSystem', () {
    test('generates distinct tray shapes and honours exclusions', () {
      final system = PieceGenerationSystem(random: Random(7));
      final tray = system.generateTray(
        contextFor(emptyBoard(), excludingIds: {'single', 'h2'}),
      );
      expect(tray.length, snapshotTraySize);
      expect(tray.map((s) => s.id).toSet().length, tray.length);
      expect(tray.map((s) => s.id), isNot(contains('single')));
      expect(tray.map((s) => s.id), isNot(contains('h2')));
      expect(tray.every((s) => s.cells.length <= maxTrayCells), isTrue);
    });

    test('respects maxCells cap', () {
      final system = PieceGenerationSystem(random: Random(3));
      for (var i = 0; i < 200; i++) {
        final tray = system.generateTray(contextFor(emptyBoard(), maxCells: 2));
        expect(tray.every((s) => s.cells.length <= 2), isTrue);
      }
    });

    test('requirePlayable filters to shapes that fit the board', () {
      final grid = emptyBoard(3);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          if ((r + c) % 2 == 0) grid[r][c] = 1;
        }
      }
      final system = PieceGenerationSystem(random: Random(11));
      final shape = system.generateRefill(
        contextFor(grid, maxCells: 4),
        requirePlayable: true,
      );
      expect(shape, isNotNull);
      expect(ValidMove.hasAnyMove(shape!, grid), isTrue);
    });

    test('returns null when no playable shape exists', () {
      final full = List.generate(3, (_) => List<int>.filled(3, 1));
      final system = PieceGenerationSystem(random: Random(1));
      expect(
        system.generateRefill(contextFor(full), requirePlayable: true),
        isNull,
      );
    });

    test('all four policies produce valid candidates', () {
      final grid = emptyBoard();
      grid[3][3] = 1;
      for (final policy in GenerationPolicy.values) {
        final system = PieceGenerationSystem(
          random: Random(5),
          strategy: strategyFor(
            policy,
            recipe: ['square3x3', 'rect2x3', 'single'],
          ),
        );
        final tray = system.generateTray(
          contextFor(
            grid,
            policy: policy,
            recipe: ['square3x3', 'rect2x3', 'single'],
            difficultyLevel: 2,
            moves: 4,
          ),
        );
        expect(tray, isNotEmpty, reason: '$policy');
        expect(tray.every((s) => s.cells.length <= maxTrayCells), isTrue);
      }
    });

    test('recipe strategy follows the prescribed sequence', () {
      final system = PieceGenerationSystem(
        random: Random(2),
        strategy: const RecipeGenerationStrategy([
          'square3x3',
          'rect2x3',
          'single',
        ]),
      );
      expect(
        system.generateRefill(contextFor(emptyBoard(), moves: 0))?.id,
        'square3x3',
      );
      expect(
        system.generateRefill(contextFor(emptyBoard(), moves: 1))?.id,
        'rect2x3',
      );
      expect(
        system.generateRefill(contextFor(emptyBoard(), moves: 2))?.id,
        'single',
      );
    });
  });

  group('engine integration', () {
    test('engine delegates placement and generation to the new system', () {
      final engine = GameEngine(random: Random(9));
      final tray = engine.generateTray(GameMode.classic);
      expect(tray.length, snapshotTraySize);
      for (final shape in tray) {
        expect(
          engine.canPlaceBlock(shape, 0, 0),
          ValidMove.canPlace(shape, 0, 0, engine.grid),
        );
      }
      final refill = engine.generateTrayShape(
        GameMode.classic,
        excludingIds: tray.map((s) => s.id),
      );
      expect(refill, isNotNull);
      expect(tray.map((s) => s.id), isNot(contains(refill!.id)));
    });

    test('BlockGenerator facade keeps working', () {
      final generator = BlockGenerator(random: Random(42));
      expect(generator.generateTray(GameMode.classic).length, snapshotTraySize);
      expect(generator.generatePlayableShape(GameMode.classic), isNotNull);
      expect(
        generator.generateTray(GameMode.rising, maxCells: 2).every(
          (s) => s.cells.length <= 2,
        ),
        isTrue,
      );
    });
  });
}
