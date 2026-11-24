import '../game_models.dart';

enum GameEndReason { boardFull, timeUp, abandoned }

/// One finished game. Pure data: Hive serialisation lives in the data layer.
class GameSession {
  const GameSession({
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    required this.moves,
    required this.linesCleared,
    required this.comboCount,
    required this.maxStreak,
    required this.endReason,
    required this.wasReplay,
    this.fatalShapeId,
  });

  final GameMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final int score;
  final int moves;
  final int linesCleared;

  /// Number of placements that cleared at least one line.
  final int comboCount;
  final int maxStreak;

  /// Shape that had no legal move when the game ended (if identifiable).
  final String? fatalShapeId;
  final GameEndReason endReason;
  final bool wasReplay;

  Duration get duration => endedAt.difference(startedAt);

  bool get isLoss => endReason == GameEndReason.boardFull;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'score': score,
    'moves': moves,
    'linesCleared': linesCleared,
    'comboCount': comboCount,
    'maxStreak': maxStreak,
    'fatalShapeId': fatalShapeId,
    'endReason': endReason.name,
    'wasReplay': wasReplay,
  };

  factory GameSession.fromJson(Map<String, Object?> json) => GameSession(
    mode: GameMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => GameMode.classic,
    ),
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    score: (json['score'] as num?)?.toInt() ?? 0,
    moves: (json['moves'] as num?)?.toInt() ?? 0,
    linesCleared: (json['linesCleared'] as num?)?.toInt() ?? 0,
    comboCount: (json['comboCount'] as num?)?.toInt() ?? 0,
    maxStreak: (json['maxStreak'] as num?)?.toInt() ?? 0,
    fatalShapeId: json['fatalShapeId'] as String?,
    endReason: GameEndReason.values.firstWhere(
      (r) => r.name == json['endReason'],
      orElse: () => GameEndReason.abandoned,
    ),
    wasReplay: json['wasReplay'] == true,
  );
}
