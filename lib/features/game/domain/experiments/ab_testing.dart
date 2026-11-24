import '../analytics/game_session.dart';
import '../generation/generation_context.dart';

class ExperimentVariant {
  const ExperimentVariant({
    required this.id,
    required this.name,
    required this.generationPolicy,
    this.recipe = const <String>[],
    this.adaptiveCellCaps = const [2, 4, 5, 7],
    this.weight = 1,
  });

  final String id;
  final String name;
  final GenerationPolicy generationPolicy;
  final List<String> recipe;
  final List<int> adaptiveCellCaps;
  final int weight;
}

class ExperimentDefinition {
  const ExperimentDefinition({
    required this.id,
    required this.name,
    required this.variants,
    this.enabled = true,
  });

  final String id;
  final String name;
  final List<ExperimentVariant> variants;
  final bool enabled;

  ExperimentVariant? variant(String id) =>
      variants.where((v) => v.id == id).firstOrNull;
}

/// Furnishes distinct generation/difficulty configurations to test on real
/// players while keeping the control group on current behaviour.
const generationExperiment = ExperimentDefinition(
  id: 'piece_generation_v1',
  name: 'Parça Üretim Algoritması',
  variants: [
    ExperimentVariant(
      id: 'control',
      name: 'Kontrol (rastgele)',
      generationPolicy: GenerationPolicy.random,
    ),
    ExperimentVariant(
      id: 'board_aware',
      name: 'Tahtaya Duyarlı',
      generationPolicy: GenerationPolicy.boardAware,
    ),
    ExperimentVariant(
      id: 'recipe_mix',
      name: 'Tarif Karışımı',
      generationPolicy: GenerationPolicy.recipe,
      recipe: ['square3x3', 'rect2x3', 'h4', 'single', 'l3', 'corner5'],
      adaptiveCellCaps: [2, 3, 5, 7],
    ),
    ExperimentVariant(
      id: 'difficulty_scaled',
      name: 'Zorluk Odaklı',
      generationPolicy: GenerationPolicy.difficultyAware,
      adaptiveCellCaps: [2, 4, 6, 9],
    ),
  ],
);

class ExperimentAssignment {
  const ExperimentAssignment({
    required this.experimentId,
    required this.variantId,
    required this.assignedAt,
  });

  final String experimentId;
  final String variantId;
  final DateTime assignedAt;

  Map<String, Object?> toJson() => {
    'experimentId': experimentId,
    'variantId': variantId,
    'assignedAt': assignedAt.toIso8601String(),
  };

  factory ExperimentAssignment.fromJson(Map<String, Object?> json) =>
      ExperimentAssignment(
        experimentId: json['experimentId'] as String? ?? '',
        variantId: json['variantId'] as String? ?? 'control',
        assignedAt:
            DateTime.tryParse(json['assignedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class ExperimentOutcome {
  const ExperimentOutcome({
    required this.experimentId,
    required this.variantId,
    required this.session,
  });

  final String experimentId;
  final String variantId;
  final GameSession session;

  Map<String, Object?> toJson() => {
    'experimentId': experimentId,
    'variantId': variantId,
    'session': session.toJson(),
  };

  factory ExperimentOutcome.fromJson(Map<String, Object?> json) =>
      ExperimentOutcome(
        experimentId: json['experimentId'] as String? ?? '',
        variantId: json['variantId'] as String? ?? 'control',
        session: GameSession.fromJson(
          Map<String, Object?>.from(json['session'] as Map? ?? const {}),
        ),
      );
}

class VariantStats {
  const VariantStats({
    required this.variantId,
    required this.games,
    required this.averageScore,
    required this.averageDurationSeconds,
    required this.lossRate,
    required this.replayRate,
  });

  final String variantId;
  final int games;
  final double averageScore;
  final double averageDurationSeconds;
  final double lossRate;
  final double replayRate;
}

class ExperimentReport {
  const ExperimentReport({required this.variants});

  final List<VariantStats> variants;

  VariantStats? operator [](String variantId) =>
      variants.where((v) => v.variantId == variantId).firstOrNull;
}

/// Pure assignment + aggregation. No Hive, no Flutter.
class ABTestingEngine {
  const ABTestingEngine();

  /// Stable FNV-1a hash makes the same bucket key always get the same variant,
  /// even across reinstalls when the key is persisted.
  ExperimentAssignment assign(
    ExperimentDefinition definition,
    String bucketKey, {
    DateTime? now,
  }) {
    final totalWeight = definition.variants.fold<int>(
      0,
      (sum, v) => sum + (v.weight > 0 ? v.weight : 0),
    );
    final bucket = _hash('${definition.id}:$bucketKey') % totalWeight;
    var cursor = 0;
    for (final variant in definition.variants) {
      cursor += variant.weight;
      if (bucket < cursor) {
        return ExperimentAssignment(
          experimentId: definition.id,
          variantId: variant.id,
          assignedAt: now ?? DateTime.now(),
        );
      }
    }
    final fallback = definition.variants.first;
    return ExperimentAssignment(
      experimentId: definition.id,
      variantId: fallback.id,
      assignedAt: now ?? DateTime.now(),
    );
  }

  ExperimentReport summarize(Iterable<ExperimentOutcome> outcomes) {
    final byVariant = <String, List<GameSession>>{};
    for (final outcome in outcomes) {
      byVariant
          .putIfAbsent(outcome.variantId, () => <GameSession>[])
          .add(outcome.session);
    }
    final stats = <VariantStats>[];
    for (final entry in byVariant.entries) {
      final games = entry.value;
      stats.add(
        VariantStats(
          variantId: entry.key,
          games: games.length,
          averageScore: games.fold<int>(0, (s, g) => s + g.score) / games.length,
          averageDurationSeconds:
              games.fold<int>(0, (s, g) => s + g.duration.inMilliseconds) /
              games.length /
              1000.0,
          lossRate: games.where((g) => g.isLoss).length / games.length,
          replayRate: games.where((g) => g.wasReplay).length / games.length,
        ),
      );
    }
    stats.sort((a, b) => b.games.compareTo(a.games));
    return ExperimentReport(variants: List.unmodifiable(stats));
  }

  int _hash(String value) {
    var hash = 2166136261;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  }
}
