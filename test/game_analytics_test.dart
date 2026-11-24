import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/data/game_analytics_repository.dart';
import 'package:gridspark/features/game/domain/analytics/game_analytics.dart';
import 'package:gridspark/features/game/domain/analytics/game_session.dart';
import 'package:gridspark/features/game/domain/game_models.dart';

GameSession session({
  required DateTime startedAt,
  GameMode mode = GameMode.classic,
  int score = 100,
  int moves = 10,
  GameEndReason reason = GameEndReason.boardFull,
  String? fatalShapeId,
  bool wasReplay = false,
  int comboCount = 1,
}) =>
    GameSession(
      mode: mode,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 2)),
      score: score,
      moves: moves,
      linesCleared: comboCount * 2,
      comboCount: comboCount,
      maxStreak: comboCount,
      fatalShapeId: fatalShapeId,
      endReason: reason,
      wasReplay: wasReplay,
    );

void main() {
  final base = DateTime(2026, 1, 1);

  group('GameAnalyticsTracker', () {
    test('accumulates placements, clears and streaks', () {
      final tracker = GameAnalyticsTracker(
        mode: GameMode.classic,
        startedAt: base,
      );
      tracker
        ..recordPlacement(lines: 0, streak: 0)
        ..recordPlacement(lines: 2, streak: 1)
        ..recordPlacement(lines: 1, streak: 3)
        ..recordClear(1);
      final s = tracker.finish(
        score: 900,
        moves: 3,
        reason: GameEndReason.boardFull,
        fatalShapeId: 'square3x3',
        endedAt: base.add(const Duration(minutes: 1)),
      );
      expect(s.comboCount, 2);
      expect(s.linesCleared, 4);
      expect(s.maxStreak, 3);
      expect(s.duration, const Duration(minutes: 1));
      expect(s.isLoss, isTrue);
    });
  });

  group('GameAnalyticsEngine', () {
    test('computes all required metrics', () {
      final sessions = [
        for (var i = 0; i < 10; i++)
          session(
            startedAt: base.add(Duration(days: i)),
            score: 100 + i * 10,
            comboCount: i % 2,
            fatalShapeId: i == 0 ? 'rect2x3' : 'square3x3',
            wasReplay: i == 9,
            reason: i == 0 ? GameEndReason.timeUp : GameEndReason.boardFull,
          ),
        session(
          startedAt: base.add(const Duration(days: 20)),
          score: 500,
          reason: GameEndReason.abandoned,
          wasReplay: true,
        ),
      ];
      final stats = const GameAnalyticsEngine().summarize(sessions);
      expect(stats.totalGames, 11);
      expect(stats.averageGameDurationSeconds, closeTo(120, 0.001));
      expect(stats.averageScore, closeTo((1450 + 500) / 11, 0.001));
      // First 10 games: 1 timeUp (not a loss) => 9/10.
      expect(stats.firstTenLossRate, closeTo(0.9, 0.001));
      expect(stats.fatalShapeCounts['square3x3'], 9);
      expect(stats.fatalShapeCounts['rect2x3'], 1);
      expect(stats.combosPerGame, closeTo(6 / 11, 0.001));
      expect(stats.replayRate, closeTo(2 / 11, 0.001));
    });

    test('empty history yields zeroes', () {
      final stats = const GameAnalyticsEngine().summarize(const []);
      expect(stats.totalGames, 0);
      expect(stats.averageScore, 0);
      expect(stats.firstTenLossRate, 0);
      expect(stats.fatalShapeCounts, isEmpty);
    });

    test('treats fewer than 10 games correctly', () {
      final stats = const GameAnalyticsEngine().summarize([
        session(startedAt: base, reason: GameEndReason.timeUp),
        session(
          startedAt: base.add(const Duration(hours: 1)),
          reason: GameEndReason.boardFull,
        ),
      ]);
      expect(stats.firstTenLossRate, 0.5);
    });
  });

  group('GameAnalyticsRepository', () {
    test('serializes through JSON and computes stats', () async {
      final repo = InMemoryGameAnalyticsRepository();
      await repo.record(session(startedAt: base, fatalShapeId: 'h2'));
      await repo.record(
        session(
          startedAt: base.add(const Duration(days: 1)),
          reason: GameEndReason.timeUp,
          wasReplay: true,
        ),
      );
      expect(repo.loadAll().length, 2);
      final stats = await repo.stats();
      expect(stats.totalGames, 2);
      expect(stats.fatalShapeCounts['h2'], 1);
      expect(stats.replayRate, 0.5);
      await repo.clear();
      expect(repo.loadAll(), isEmpty);
    });

    test('GameSession JSON round trip', () {
      final original = session(
        startedAt: base,
        fatalShapeId: 'square3x3',
        wasReplay: true,
      );
      final restored = GameSession.fromJson(original.toJson());
      expect(restored.score, original.score);
      expect(restored.mode, original.mode);
      expect(restored.endReason, original.endReason);
      expect(restored.fatalShapeId, 'square3x3');
      expect(restored.wasReplay, isTrue);
      expect(restored.duration, original.duration);
    });
  });
}
