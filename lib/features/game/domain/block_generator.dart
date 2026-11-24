import 'dart:math';

import 'game_models.dart';
import 'generation/generation_context.dart';
import 'generation/piece_generation_system.dart';

/// Backward-compatible facade over the independent generation system.
///
/// New code should depend on [PieceGenerationSystem] directly; this class
/// remains so existing callers/tests keep working unchanged.
class BlockGenerator {
  BlockGenerator({Random? random, PieceGenerationSystem? system})
      : _system = system ?? PieceGenerationSystem(random: random);

  final PieceGenerationSystem _system;

  static List<List<int>> _emptyBoard() => List.generate(
        snapshotGridSize,
        (_) => List<int>.filled(snapshotGridSize, -1),
      );

  GenerationContext _context(
    GameMode mode, {
    required int maxCells,
    Iterable<String> excludingIds = const [],
  }) =>
      GenerationContext(
        mode: mode,
        grid: _emptyBoard(),
        score: 0,
        moves: 0,
        maxCells: maxCells,
        excludingIds: excludingIds.toSet(),
      );

  /// Generates [snapshotTraySize] random block shapes for the given [mode].
  /// For [GameMode.rising], [maxCells] controls difficulty-based filtering.
  List<BlockShape> generateTray(GameMode mode, {int maxCells = 5}) =>
      _system.generateTray(_context(mode, maxCells: maxCells));

  /// Generates a single playable shape, excluding given IDs, respecting maxCells.
  BlockShape? generatePlayableShape(
    GameMode mode, {
    Iterable<String> excludingIds = const [],
    int maxCells = 5,
  }) =>
      _system.generateRefill(
        _context(
          mode,
          maxCells: maxCells,
          excludingIds: excludingIds,
        ),
        requirePlayable: true,
      );
}
