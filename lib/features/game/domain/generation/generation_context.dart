import '../game_models.dart';
import 'board_analysis.dart';

/// How a [PieceGenerationSystem] should choose its next shape.
enum GenerationPolicy {
  random,
  boardAware,
  difficultyAware,
  recipe,
  clearAssist,
}

/// Everything a strategy needs to make a decision. No engine, no MobX, no UI.
class GenerationContext {
  GenerationContext({
    required this.mode,
    required this.grid,
    required this.score,
    required this.moves,
    required this.maxCells,
    this.difficultyLevel = 0,
    this.excludingIds = const <String>{},
    this.policy = GenerationPolicy.random,
    this.recipe = const <String>[],
  }) : analysis = BoardAnalysis.of(grid);

  final GameMode mode;
  final List<List<int>> grid;
  final BoardAnalysis analysis;
  final int score;
  final int moves;
  final int maxCells;
  final int difficultyLevel;
  final Set<String> excludingIds;
  final GenerationPolicy policy;
  final List<String> recipe;

  /// Shapes allowed by the mode, size cap and exclusion set.
  Iterable<BlockShape> get candidates => ShapeCatalog.all.where(
    (shape) =>
        shape.weight > 0 &&
        shape.cells.length <= maxCells &&
        !excludingIds.contains(shape.id) &&
        ShapeCatalog.isAllowedInMode(shape, mode),
  );
}
