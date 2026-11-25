import 'dart:math';

import '../game_models.dart';
import 'generation_context.dart';
import 'valid_move.dart';

abstract class GenerationStrategy {
  const GenerationStrategy();

  /// Picks one shape from [context.candidates]. Must return null when empty.
  BlockShape? next(GenerationContext context, Random random);
}

BlockShape? _weightedPick(
  Iterable<BlockShape> candidates,
  double Function(BlockShape) weight,
  Random random,
) {
  final items = candidates.toList();
  if (items.isEmpty) return null;
  final weights = <double>[for (final s in items) weight(s).clamp(0.0, 1.0)];
  var total = weights.fold<double>(0, (sum, w) => sum + w);
  if (total <= 0) return items[random.nextInt(items.length)];
  var roll = random.nextDouble() * total;
  for (var i = 0; i < items.length; i++) {
    roll -= weights[i];
    if (roll <= 0) return items[i];
  }
  return items.last;
}

/// Current behaviour: uniform random from all allowed shapes.
class RandomGenerationStrategy extends GenerationStrategy {
  const RandomGenerationStrategy();

  @override
  BlockShape? next(GenerationContext context, Random random) {
    final items = context.candidates.toList()..shuffle(random);
    return items.firstOrNull;
  }
}

/// Uses board occupancy and open space to bias shape size:
/// crowded boards get smaller, placeable pieces; open boards get more variety.
class BoardAwareGenerationStrategy extends GenerationStrategy {
  const BoardAwareGenerationStrategy();

  @override
  BlockShape? next(GenerationContext context, Random random) {
    final a = context.analysis;
    final sizes = context.candidates.map((s) => s.cells.length);
    final largest = sizes.isEmpty ? 0 : sizes.reduce(max);
    final crowded = a.isCrowded;
    return _weightedPick(context.candidates, (shape) {
      final cells = shape.cells.length;
      // Prefer shapes that actually fit somewhere.
      var weight = ValidMove.hasAnyMove(shape, context.grid) ? 1.0 : 0.25;
      if (crowded) {
        weight *= 1.0 + (largest - cells) / max(1, largest);
      } else {
        // Open board: mild preference for mid-sized pieces to keep play varied.
        weight *= 1.0 - (cells - 2).abs() / max(1, largest + 2);
      }
      // Dead holes make big shapes especially unattractive.
      if (a.isolatedEmptyCells > 2 && cells > 4) weight *= 0.5;
      return weight;
    }, random);
  }
}

/// Block-Blast style "flow" generator: strongly favours pieces that can
/// finish a row/column so the player can chain clears, still hands out the
/// odd awkward piece so the board can fill up and the game can end.
class ClearAssistGenerationStrategy extends GenerationStrategy {
  const ClearAssistGenerationStrategy();

  @override
  BlockShape? next(GenerationContext context, Random random) {
    final crowded = context.analysis.isCrowded;
    return _weightedPick(context.candidates, (shape) {
      if (!ValidMove.hasAnyMove(shape, context.grid)) {
        return 0.02 * shape.weight;
      }
      final lines = ValidMove.maxLinesCleared(shape, context.grid);
      final double fit;
      if (lines >= 2) {
        fit = 1.0; // multi-line clears are the jackpot: hand them out freely
      } else if (lines == 1) {
        fit = 0.85;
      } else {
        // No clear available: a crowded board needs an exit, an open board
        // just needs a fair piece.
        fit = crowded ? 0.15 : 0.3;
      }
      return fit * shape.weight;
    }, random);
  }
}

/// Scales preferred shape complexity with the difficulty level instead of
/// relying on score thresholds alone.
class DifficultyAwareGenerationStrategy extends GenerationStrategy {
  const DifficultyAwareGenerationStrategy();

  @override
  BlockShape? next(GenerationContext context, Random random) {
    final level = context.difficultyLevel.clamp(0, 2);
    const targetCells = [2, 4, 6];
    final target = targetCells[level];
    return _weightedPick(context.candidates, (shape) {
      final distance = (shape.cells.length - target).abs();
      return 1.0 / (1.0 + distance);
    }, random);
  }
}

/// Deterministic shape sequence: chooses from a recipe list by move index,
/// falling back to uniform random when the entry is unavailable.
class RecipeGenerationStrategy extends GenerationStrategy {
  const RecipeGenerationStrategy(this.recipe);

  final List<String> recipe;

  @override
  BlockShape? next(GenerationContext context, Random random) {
    if (recipe.isEmpty) {
      return const RandomGenerationStrategy().next(context, random);
    }
    final id = recipe[context.moves % recipe.length];
    final prescribed = context.candidates.where((s) => s.id == id).firstOrNull;
    if (prescribed != null) return prescribed;
    return const RandomGenerationStrategy().next(context, random);
  }
}

GenerationStrategy strategyFor(
  GenerationPolicy policy, {
  List<String> recipe = const [],
}) => switch (policy) {
  GenerationPolicy.random => const RandomGenerationStrategy(),
  GenerationPolicy.boardAware => const BoardAwareGenerationStrategy(),
  GenerationPolicy.difficultyAware => const DifficultyAwareGenerationStrategy(),
  GenerationPolicy.recipe => RecipeGenerationStrategy(recipe),
  GenerationPolicy.clearAssist => const ClearAssistGenerationStrategy(),
};
