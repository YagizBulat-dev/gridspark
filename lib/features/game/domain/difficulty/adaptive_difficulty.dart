/// Performance-driven difficulty decisions.
///
/// Pure Dart: no MobX, no Flutter, no engine. The game store feeds it a
/// [PerformanceSnapshot] after each move and applies the returned cell cap.
class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.moves,
    required this.linesCleared,
    required this.bestStreak,
    required this.score,
    required this.averageScore,
    required this.recentLossRate,
    required this.secondsPlayed,
  });

  final int moves;
  final int linesCleared;
  final int bestStreak;
  final int score;
  final double averageScore;

  /// 0.0..1.0 from the player's history (first-ten loss rate).
  final double recentLossRate;
  final int secondsPlayed;

  double get clearRate => moves == 0 ? 0 : linesCleared / moves;
}

enum DifficultyTrend { steady, push, ease }

class DifficultyDecision {
  const DifficultyDecision({
    required this.level,
    required this.maxCells,
    required this.trend,
    required this.reason,
  });

  final int level;
  final int maxCells;
  final DifficultyTrend trend;
  final String reason;
}

/// Raises difficulty when the player is clearing efficiently and eases off
/// when they struggle. Unlike the old score-threshold logic this reacts to
/// clear rate, streaks, historical average score and loss rate.
class AdaptiveDifficultyManager {
  AdaptiveDifficultyManager({
    this.levels = const [2, 4, 5, 7],
    this.minMovesBetweenChanges = 6,
  });

  /// Cell caps per level. Index 0 is easiest.
  final List<int> levels;
  final int minMovesBetweenChanges;

  int _level = 0;
  int _lastChangeMove = 0;

  int get level => _level;

  DifficultyDecision decisionFor(PerformanceSnapshot p) {
    if (p.moves == 0) return _decision(DifficultyTrend.steady, 'Game start');

    // Signal combines live efficiency with historical context.
    var signal = 0.0;
    signal += p.clearRate * 3.0;
    if (p.bestStreak >= 3) signal += 1.0;
    if (p.averageScore > 0 && p.score > p.averageScore * 1.2) signal += 1.0;
    if (p.recentLossRate > 0.6) signal -= 1.5;
    if (p.secondsPlayed < 20 && p.moves < 4) {
      // Not enough data yet; avoid early swings.
      return _decision(DifficultyTrend.steady, 'Warming up');
    }

    final canChange = p.moves - _lastChangeMove >= minMovesBetweenChanges;
    var trend = DifficultyTrend.steady;
    if (canChange && signal >= 2.0 && _level < levels.length - 1) {
      _level++;
      _lastChangeMove = p.moves;
      trend = DifficultyTrend.push;
    } else if (canChange && signal < 0.5 && _level > 0) {
      _level--;
      _lastChangeMove = p.moves;
      trend = DifficultyTrend.ease;
    }

    final reason = switch (trend) {
      DifficultyTrend.push => 'Strong clear rate / streak',
      DifficultyTrend.ease => 'Board pressure high',
      DifficultyTrend.steady => 'Stable performance',
    };
    return _decision(trend, reason);
  }

  DifficultyDecision _decision(DifficultyTrend trend, String reason) =>
      DifficultyDecision(
        level: _level,
        maxCells: levels[_level.clamp(0, levels.length - 1)],
        trend: trend,
        reason: reason,
      );

  void reset() {
    _level = 0;
    _lastChangeMove = 0;
  }
}
