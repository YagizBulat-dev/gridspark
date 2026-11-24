import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/data/experiment_repository.dart';
import 'package:gridspark/features/game/domain/analytics/game_session.dart';
import 'package:gridspark/features/game/domain/experiments/ab_testing.dart';
import 'package:gridspark/features/game/domain/game_engine.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:gridspark/features/game/domain/generation/generation_context.dart';

GameSession session({required int score, required bool loss, bool replay = false}) {
  final at = DateTime(2026, 2, 1);
  return GameSession(
    mode: GameMode.classic,
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 3)),
    score: score,
    moves: 20,
    linesCleared: 4,
    comboCount: 2,
    maxStreak: 2,
    endReason: loss ? GameEndReason.boardFull : GameEndReason.timeUp,
    wasReplay: replay,
  );
}

void main() {
  const engine = ABTestingEngine();
  final now = DateTime(2026, 2, 1);

  group('ABTestingEngine', () {
    test('assignment is deterministic and sticky per bucket key', () {
      final first = engine.assign(generationExperiment, 'player-42', now: now);
      final second = engine.assign(generationExperiment, 'player-42', now: now);
      expect(first.variantId, second.variantId);
      expect(first.experimentId, generationExperiment.id);
      expect(generationExperiment.variant(first.variantId), isNotNull);
    });

    test('all variants receive traffic across many buckets', () {
      final seen = <String>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(engine.assign(generationExperiment, 'bucket-$i').variantId);
      }
      expect(
        seen,
        containsAll(generationExperiment.variants.map((v) => v.id)),
      );
    });

    test('weights are respected', () {
      const weighted = ExperimentDefinition(
        id: 'weighted',
        name: 'Weighted',
        variants: [
          ExperimentVariant(
            id: 'a',
            name: 'A',
            weight: 3,
            generationPolicy: GenerationPolicy.random,
          ),
          ExperimentVariant(
            id: 'b',
            name: 'B',
            weight: 1,
            generationPolicy: GenerationPolicy.boardAware,
          ),
        ],
      );
      var a = 0;
      for (var i = 0; i < 1000; i++) {
        if (engine.assign(weighted, 'u$i').variantId == 'a') a++;
      }
      expect(a, greaterThanOrEqualTo(700));
      expect(a, lessThanOrEqualTo(800));
    });

    test('report aggregates per variant', () {
      final report = engine.summarize([
        ExperimentOutcome(
          experimentId: 'e',
          variantId: 'control',
          session: session(score: 100, loss: true),
        ),
        ExperimentOutcome(
          experimentId: 'e',
          variantId: 'control',
          session: session(score: 300, loss: false, replay: true),
        ),
        ExperimentOutcome(
          experimentId: 'e',
          variantId: 'board_aware',
          session: session(score: 500, loss: false),
        ),
      ]);
      final control = report['control']!;
      expect(control.games, 2);
      expect(control.averageScore, 200);
      expect(control.lossRate, 0.5);
      expect(control.replayRate, 0.5);
      expect(control.averageDurationSeconds, closeTo(180, 0.01));
      expect(report['board_aware']!.averageScore, 500);
    });
  });

  group('Experiment variants', () {
    test('recipe variant drives the engine generator', () {
      final recipe = generationExperiment
          .variant('recipe_mix')!
          .recipe;
      final game = GameEngine(
        generationPolicy: GenerationPolicy.recipe,
        generationRecipe: recipe,
      );
      expect(game.generateTrayShape(GameMode.classic)?.id, recipe.first);
    });

    test('each variant has a valid policy and cell caps', () {
      for (final variant in generationExperiment.variants) {
        expect(variant.adaptiveCellCaps, isNotEmpty);
        expect(variant.weight, greaterThan(0));
        expect(
          variant.generationPolicy,
          isA<GenerationPolicy>(),
        );
      }
    });
  });

  group('ExperimentRepository', () {
    test('persists assignments and outcomes', () async {
      final repo = InMemoryExperimentRepository();
      final bucket = repo.bucketKey;
      expect(bucket, isNotEmpty);
      expect(repo.bucketKey, bucket);

      final assignment = engine.assign(generationExperiment, bucket);
      await repo.saveAssignment(assignment);
      expect(repo.assignment(generationExperiment.id)!.variantId,
          assignment.variantId);

      await repo.recordOutcome(
        ExperimentOutcome(
          experimentId: assignment.experimentId,
          variantId: assignment.variantId,
          session: session(score: 900, loss: false),
        ),
      );
      expect(repo.outcomes(generationExperiment.id).length, 1);
      final stats = repo.report(generationExperiment.id)[assignment.variantId]!;
      expect(stats.games, 1);
      expect(stats.averageScore, 900);
    });
  });
}
