import 'dart:math';

import '../game_models.dart';
import 'generation_context.dart';
import 'generation_strategies.dart';
import 'valid_move.dart';

/// Independent piece generator.
///
/// No MobX, no Flutter, no GameEngine: feed it a [GenerationContext] and get
/// shapes back. This makes it possible to simulate thousands of boards and
/// generation policies in plain Dart tests.
class PieceGenerationSystem {
  PieceGenerationSystem({
    Random? random,
    GenerationStrategy? strategy,
  })  : _random = random ?? Random(),
        _strategy = strategy ?? const RandomGenerationStrategy();

  final Random _random;
  final GenerationStrategy _strategy;

  /// Generates up to [snapshotTraySize] distinct shapes.
  ///
  /// When [requirePlayable] is true only shapes with at least one legal
  /// placement are returned. Board full detection deliberately uses false so
  /// an unplaceable tray can still end the game.
  List<BlockShape> generateTray(
    GenerationContext context, {
    bool requirePlayable = false,
  }) {
    final picked = <BlockShape>[];
    final used = <String>{...context.excludingIds};
    for (var i = 0; i < snapshotTraySize; i++) {
      final shape = _pick(context, used, requirePlayable: requirePlayable);
      if (shape == null) break;
      picked.add(shape);
      used.add(shape.id);
    }
    return List.unmodifiable(picked);
  }

  /// Generates a single refill shape. Used for tray replacement after a move.
  BlockShape? generateRefill(
    GenerationContext context, {
    bool requirePlayable = false,
  }) =>
      _pick(context, context.excludingIds, requirePlayable: requirePlayable);

  BlockShape? _pick(
    GenerationContext context,
    Set<String> excludingIds, {
    required bool requirePlayable,
  }) {
    final available = context.candidates
        .where((shape) => !excludingIds.contains(shape.id))
        .toList();
    if (available.isEmpty) return null;

    var pool = available;
    if (requirePlayable) {
      final playable = ValidMove.playable(pool, context.grid);
      if (playable.isEmpty) return null;
      pool = playable;
    }

    final attemptContext = GenerationContext(
      mode: context.mode,
      grid: context.grid,
      score: context.score,
      moves: context.moves,
      maxCells: context.maxCells,
      difficultyLevel: context.difficultyLevel,
      excludingIds: excludingIds,
      policy: context.policy,
      recipe: context.recipe,
    );

    // The strategy may still return a shape outside `pool` (e.g. recipe),
    // so verify the exclusion and playability contract here as well.
    for (var tries = 0; tries < 8; tries++) {
      final chosen = _strategy.next(attemptContext, _random) ??
          pool[_random.nextInt(pool.length)];
      if (excludingIds.contains(chosen.id)) continue;
      if (requirePlayable && !ValidMove.hasAnyMove(chosen, context.grid)) {
        continue;
      }
      return chosen;
    }
    return pool[_random.nextInt(pool.length)];
  }
}
