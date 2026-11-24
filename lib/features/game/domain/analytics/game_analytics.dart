import 'game_session.dart';
import '../game_models.dart';

/// Aggregated player metrics. All rates are 0.0..1.0.
class PlayerAnalytics {
  const PlayerAnalytics({
    required this.totalGames,
    required this.averageGameDurationSeconds,
    required this.averageScore,
    required this.firstTenLossRate,
    required this.fatalShapeCounts,
    required this.combosPerGame,
    required this.combosPerMove,
    required this.replayRate,
  });

  final int totalGames;
  final double averageGameDurationSeconds;
  final double averageScore;

  /// Loss = board filled with no legal move, within the first 10 games.
  final double firstTenLossRate;

  /// Shape id -> how often it was the piece that ended a game.
  final Map<String, int> fatalShapeCounts;

  final double combosPerGame;
  final double combosPerMove;
  final double replayRate;
}

/// Pure Dart analytics: no Hive, no Flutter, no MobX.
class GameAnalyticsEngine {
  const GameAnalyticsEngine();

  PlayerAnalytics summarize(Iterable<GameSession> sessions) {
    final games = sessions.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (games.isEmpty) {
      return const PlayerAnalytics(
        totalGames: 0,
        averageGameDurationSeconds: 0,
        averageScore: 0,
        firstTenLossRate: 0,
        fatalShapeCounts: <String, int>{},
        combosPerGame: 0,
        combosPerMove: 0,
        replayRate: 0,
      );
    }

    final total = games.length;
    final totalSeconds = games.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMilliseconds,
    );
    final totalScore = games.fold<int>(0, (sum, s) => sum + s.score);
    final firstTen = games.take(10).toList();
    final losses = firstTen.where((s) => s.isLoss).length;
    final fatal = <String, int>{};
    for (final s in games) {
      final id = s.fatalShapeId;
      if (id != null && id.isNotEmpty) fatal[id] = (fatal[id] ?? 0) + 1;
    }
    final sortedFatal = <String, int>{
      for (final entry in fatal.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      entry.key: entry.value,
    };
    final combos = games.fold<int>(0, (sum, s) => sum + s.comboCount);
    final moves = games.fold<int>(0, (sum, s) => sum + s.moves);
    final replays = games.where((s) => s.wasReplay).length;

    return PlayerAnalytics(
      totalGames: total,
      averageGameDurationSeconds: totalSeconds / total / 1000.0,
      averageScore: totalScore / total,
      firstTenLossRate: losses / firstTen.length,
      fatalShapeCounts: Map.unmodifiable(sortedFatal),
      combosPerGame: combos / total,
      combosPerMove: moves == 0 ? 0 : combos / moves,
      replayRate: replays / total,
    );
  }
}

/// Accumulates one live session from game events, then emits a [GameSession].
/// Kept separate from persistence so it can be unit tested in isolation.
class GameAnalyticsTracker {
  GameAnalyticsTracker({
    required this.mode,
    this.wasReplay = false,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  final GameMode mode;
  final bool wasReplay;
  final DateTime startedAt;

  int _linesCleared = 0;
  int _comboCount = 0;
  int _maxStreak = 0;

  void recordPlacement({required int lines, required int streak}) {
    if (lines > 0) {
      _linesCleared += lines;
      _comboCount++;
    }
    if (streak > _maxStreak) _maxStreak = streak;
  }

  void recordClear(int lines) {
    if (lines > 0) _linesCleared += lines;
  }

  GameSession finish({
    required int score,
    required int moves,
    required GameEndReason reason,
    String? fatalShapeId,
    DateTime? endedAt,
  }) {
    final end = endedAt ?? DateTime.now();
    return GameSession(
      mode: mode,
      startedAt: startedAt,
      endedAt: end.isBefore(startedAt) ? startedAt : end,
      score: score,
      moves: moves,
      linesCleared: _linesCleared,
      comboCount: _comboCount,
      maxStreak: _maxStreak,
      fatalShapeId: fatalShapeId,
      endReason: reason,
      wasReplay: wasReplay,
    );
  }
}
