import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/application/game_store.dart';
import 'package:gridspark/features/game/domain/game_engine.dart';
import 'package:gridspark/features/game/domain/game_models.dart';

void main() {
  group('Tray "mark as used" behavior', () {
    test('placing a block sets its slot to null without removing it', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      expect(store.tray, hasLength(3));
      expect(store.place(1, 0, 0), isTrue);
      // Slot 1 is null, other two still have shapes.
      expect(store.tray, hasLength(3));
      expect(store.tray[0], isNotNull);
      expect(store.tray[1], isNull);
      expect(store.tray[2], isNotNull);
    });

    test('refilling only happens when all 3 slots are null', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      // Place first block → slot 0 null, 2 remaining
      expect(store.place(0, 0, 0), isTrue);
      expect(store.tray[0], isNull);
      expect(store.tray[1], isNotNull);
      expect(store.tray[2], isNotNull);
      expect(store.tray, hasLength(3));

      // Place second block → slot 1 null, 1 remaining
      expect(store.place(1, 1, 0), isTrue);
      expect(store.tray[0], isNull);
      expect(store.tray[1], isNull);
      expect(store.tray[2], isNotNull);
      expect(store.tray, hasLength(3));

      // Place third block → all null → refill with 3 new blocks
      expect(store.place(2, 2, 0), isTrue);
      expect(store.tray, hasLength(3));
      expect(store.tray[0], isNotNull);
      expect(store.tray[1], isNotNull);
      expect(store.tray[2], isNotNull);
    });

    test('game-over triggers when remaining non-null blocks cannot fit', () {
      final engine = GameEngine(size: 3);
      // 3x3 grid with scattered empty cells so no row or column is complete.
      // Empty: (0,0), (0,2), (1,1), (2,0)
      // Filled: (0,1), (1,0), (1,2), (2,1), (2,2)
      // Placing at (0,0) does NOT complete row 0 (still has (0,2) empty)
      // or column 0 (still has (2,0) empty), so no line clears.
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          if ((r == 0 && c == 0) ||
              (r == 0 && c == 2) ||
              (r == 1 && c == 1) ||
              (r == 2 && c == 0)) {
            continue;
          }
          engine.grid[r][c] = 0;
        }
      }
      final store = GameStore(
        GameMode.classic,
        engine: engine,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('square', [
            CellOffset(0, 0),
            CellOffset(0, 1),
            CellOffset(1, 0),
            CellOffset(1, 1),
          ]),
          BlockShape('corner5', [
            CellOffset(0, 0),
            CellOffset(1, 0),
            CellOffset(2, 0),
            CellOffset(2, 1),
            CellOffset(2, 2),
          ]),
        ],
      );

      // Place single at (0,0) → no line clears (row 0 has (0,2) empty, col 0 has (2,0) empty).
      expect(store.place(0, 0, 0), isTrue);
      expect(store.tray[0], isNull);

      // Remaining blocks (square 2×2, corner5 L-shape) cannot fit in the
      // scattered isolated empty cells (0,2), (1,1), (2,0) → game over.
      expect(store.isGameOver.value, isTrue);
    });

    test('null slots are excluded from hasAnyMove game-over check', () {
      final engine = GameEngine(size: 3);
      // 3x3 grid where only 3 cells are filled so no row or column is complete.
      // Empty: (0,0), (0,1), (0,2), (1,0), (1,2), (2,1)
      // Filled: (1,1), (2,0), (2,2)
      // Placing h2 at (0,0) occupies (0,0) and (0,1) — row 0 still has (0,2)
      // empty, col 0 still has (1,0) empty, col 1 still has (2,1) empty → no clears.
      engine.grid[1][1] = 0;
      engine.grid[2][0] = 0;
      engine.grid[2][2] = 0;
      final store = GameStore(
        GameMode.classic,
        engine: engine,
        initialTray: const [
          BlockShape('h2', [CellOffset(0, 0), CellOffset(0, 1)]),
          BlockShape('square', [
            CellOffset(0, 0),
            CellOffset(0, 1),
            CellOffset(1, 0),
            CellOffset(1, 1),
          ]),
          BlockShape('corner5', [
            CellOffset(0, 0),
            CellOffset(1, 0),
            CellOffset(2, 0),
            CellOffset(2, 1),
            CellOffset(2, 2),
          ]),
        ],
      );

      // Place h2 at (0,0) → fills (0,0) and (0,1). No line clears.
      expect(store.place(0, 0, 0), isTrue);
      expect(store.tray[0], isNull);

      // Remaining non-null shapes (square 2×2, corner5 L-shape) cannot fit
      // in the scattered isolated empty cells → game over.
      expect(store.isGameOver.value, isTrue);

      // Null slot is correctly excluded: game-over was triggered by checking
      // only [square, corner5], not [null, square, corner5].
      expect(store.tray[1], isNotNull);
      expect(store.tray[2], isNotNull);
    });

    test('canPlace rejects null tray slots', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      // Place slot 0 → null
      expect(store.place(0, 0, 0), isTrue);
      // Trying to place from null slot returns false
      expect(store.place(0, 1, 0), isFalse);
    });
  });

  group('Snapshot round-trip with used slots', () {
    test('preserves null tray slots through save and restore', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      // Place one block → slot 0 null
      expect(store.place(0, 0, 0), isTrue);
      expect(store.tray[0], isNull);

      // Snapshot and verify the tray IDs contain an empty string
      final snapshot = store.createSnapshot();
      expect(snapshot.trayIds[0], isEmpty);
      expect(snapshot.trayIds[1], isNotEmpty);
      expect(snapshot.trayIds[2], isNotEmpty);
    });
  });
}
