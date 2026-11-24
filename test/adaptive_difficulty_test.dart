import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/domain/difficulty/adaptive_difficulty.dart';

PerformanceSnapshot snapshot({
  required int moves,
  required int lines,
  int bestStreak = 0,
  int score = 100,
  double averageScore = 0,
  double recentLossRate = 0,
  int secondsPlayed = 120,
}) =>
    PerformanceSnapshot(
      moves: moves,
      linesCleared: lines,
      bestStreak: bestStreak,
      score: score,
      averageScore: averageScore,
      recentLossRate: recentLossRate,
      secondsPlayed: secondsPlayed,
    );

void main() {
  group('AdaptiveDifficultyManager', () {
    test('starts easy and increases on strong performance', () {
      final manager = AdaptiveDifficultyManager();
      final start = manager.decisionFor(snapshot(moves: 0, lines: 0));
      expect(start.level, 0);
      expect(start.maxCells, 2);

      final push = manager.decisionFor(
        snapshot(moves: 10, lines: 9, bestStreak: 4, score: 2000),
      );
      expect(push.trend, DifficultyTrend.push);
      expect(push.level, 1);
      expect(push.maxCells, 4);
    });

    test('eases off when the player struggles', () {
      final manager = AdaptiveDifficultyManager();
      manager.decisionFor(snapshot(moves: 10, lines: 9, bestStreak: 4));
      final ease = manager.decisionFor(
        snapshot(
          moves: 20,
          lines: 9,
          score: 50,
          recentLossRate: 0.9,
        ),
      );
      expect(ease.trend, DifficultyTrend.ease);
      expect(ease.level, 0);
      expect(ease.maxCells, 2);
    });

    test('respects change cooldown', () {
      final manager = AdaptiveDifficultyManager();
      manager.decisionFor(snapshot(moves: 10, lines: 9, bestStreak: 4));
      final early = manager.decisionFor(
        snapshot(moves: 12, lines: 11, bestStreak: 5),
      );
      expect(early.trend, DifficultyTrend.steady);
      expect(early.level, 1);
    });

    test('does not swing during warm-up', () {
      final manager = AdaptiveDifficultyManager();
      final warm =
          manager.decisionFor(snapshot(moves: 2, lines: 2, secondsPlayed: 5));
      expect(warm.trend, DifficultyTrend.steady);
      expect(warm.level, 0);
    });

    test('reset returns to the easiest level', () {
      final manager = AdaptiveDifficultyManager();
      manager.decisionFor(snapshot(moves: 10, lines: 9, bestStreak: 4));
      manager.reset();
      expect(manager.level, 0);
    });
  });
}
