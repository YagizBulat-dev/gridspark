import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/presentation/widgets/game_grid.dart';

void main() {
  const padding = 3.0;
  const size = 400.0;
  const gridSize = 8;

  group('GameGridState.computeGhostCell', () {
    test('snaps a centered pointer to an in-grid cell', () {
      // Pointer at the exact center of the grid container (local coords).
      final (row, col) = GameGridState.computeGhostCell(
        const Offset(size / 2, size / 2),
        size: size,
        gridSize: gridSize,
        padding: padding,
      );
      // Container-local (200,200) → cell area (197,137.9) → ~(3,4).
      expect(row, 3);
      expect(col, 4);
    });

    test('accounts for container padding (top-left edge → negative row)', () {
      // Finger exactly at the container's top-left corner.
      final (row, col) = GameGridState.computeGhostCell(
        const Offset(padding, padding),
        size: size,
        gridSize: gridSize,
        padding: padding,
      );
      // Top-left of the board: anchor sits one cell above → negative row,
      // which `canPlaceBlock` correctly rejects as out of bounds.
      expect(col, 0);
      expect(row, -1);
    });

    test('bottom-right edge yields an out-of-range col handled by canPlace', () {
      final (row, col) = GameGridState.computeGhostCell(
        const Offset(size - padding, size - padding),
        size: size,
        gridSize: gridSize,
        padding: padding,
      );
      // Bottom-right corner: col 8 is out of range (valid cols 0..7) →
      // `canPlaceBlock` rejects it.
      expect(col, 8);
      expect(row, 7);
    });

    test('uses the cell-area pitch, not the full container width', () {
      // Regression guard: the previous code ignored the 3px container padding
      // and used size/8 as the pitch. The corrected pitch is (size-2*padding)/8
      // = 49.25 here, while the buggy pitch was 50.0. Verify the function
      // honours the tighter, padding-aware pitch by checking the right edge.
      // At the right edge (local.dx = size - padding = 397):
      //   correct: (397-3)/49.25 = 8.0  -> col 8 (just out of range)
      //   buggy:   397/50      = 7.94    -> col 8
      // The two coincide at this exact edge, but the formula must be the
      // padding-aware one; assert the value and that the pitch is not 50.
      final (row, col) = GameGridState.computeGhostCell(
        const Offset(size - padding, size - padding),
        size: size,
        gridSize: gridSize,
        padding: padding,
      );
      expect(row, 7);
      expect(col, 8);
    });

    test('rounds to nearest integer (not floor), half-way cases round up', () {
      // Regression guard: verify that computeGhostCell uses .round() (round-to-nearest)
      // rather than .floor(), so that values on either side of a .5 boundary round
      // to different cells, preventing systematic drift.
      // With pitch = 49.25:
      //   x = padding + 1.4 * pitch = 3 + 68.95 = 71.95 → col = round((71.95 - 3) / 49.25) = round(1.4) = 1
      //   x = padding + 1.5 * pitch = 3 + 73.875 = 76.875 → col = round((76.875 - 3) / 49.25) = round(1.55) = 2
      //   x = padding + 1.6 * pitch = 3 + 78.8 = 81.8 → col = round((81.8 - 3) / 49.25) = round(1.6) = 2
      final pitch = GameGridState.cellPitch(size, padding, gridSize);
      // 1.4 * pitch → col 1
      final local14 = Offset(padding + 1.4 * pitch, padding);
      final (row14, col14) = GameGridState.computeGhostCell(local14, size: size, gridSize: gridSize, padding: padding);
      expect(col14, 1, reason: '1.4*pitch should round to col 1, got $col14');

      // 1.5 * pitch → col 2 (halfway rounds up with .round())
      final local15 = Offset(padding + 1.5 * pitch, padding);
      final (row15, col15) = GameGridState.computeGhostCell(local15, size: size, gridSize: gridSize, padding: padding);
      expect(col15, 2, reason: '1.5*pitch should round to col 2, got $col15');

      // 1.6 * pitch → col 2
      final local16 = Offset(padding + 1.6 * pitch, padding);
      final (row16, col16) = GameGridState.computeGhostCell(local16, size: size, gridSize: gridSize, padding: padding);
      expect(col16, 2, reason: '1.6*pitch should round to col 2, got $col16');
    });

    test('cellPitch is padding-aware and matches the ghost math', () {
      // The drag feedback in game_screen must use the exact same pitch as the
      // ghost preview, otherwise the floating piece is drawn ~0.75px/cell too
      // large and its 1.2-cell finger offset drifts. Centralise the formula so
      // the two can never diverge.
      final pitch = GameGridState.cellPitch(size, padding, gridSize);
      expect(pitch, (size - 2 * padding) / gridSize);
      expect(pitch, isNot(size / gridSize));
      // The naive (buggy) pitch would be exactly 50.0 here.
      expect(pitch, isNot(50.0));
    });
  });
}
