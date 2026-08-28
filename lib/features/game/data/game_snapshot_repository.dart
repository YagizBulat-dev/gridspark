import 'dart:async';

import 'package:hive/hive.dart';

import '../domain/game_engine.dart';
import '../domain/game_models.dart';

class GameSnapshot {
  const GameSnapshot({
    required this.mode,
    required this.grid,
    required this.score,
    required this.moves,
    required this.secondsLeft,
    required this.trayIds,
    this.streak = 0,
    this.bestStreak = 0,
  });

  final GameMode mode;
  final List<List<int>> grid;
  final int score;
  final int moves;
  final int secondsLeft;
  final List<String> trayIds;
  final int streak;
  final int bestStreak;

  bool get isValid {
    final validSeconds = switch (mode) {
      GameMode.timed => secondsLeft > 0 && secondsLeft <= maxTimedGameSeconds,
      GameMode.classic || GameMode.rising => secondsLeft == maxTimedGameSeconds,
    };
    final structurallyValid =
        GameEngine.isValidGrid(grid) &&
        GameEngine.isValidScoreAndMoves(score, moves) &&
        validSeconds &&
        trayIds.length == snapshotTraySize &&
        trayIds.where((id) => id.isNotEmpty).toSet().length ==
            trayIds.where((id) => id.isNotEmpty).length &&
        trayIds.every(
          (id) => id.isEmpty || ShapeCatalog.isValidSnapshotId(id, mode),
        ) &&
        streak >= 0 &&
        streak <= moves &&
        bestStreak >= streak &&
        bestStreak <= moves;
    if (!structurallyValid) return false;

    final shapes = trayIds
        .map((id) => id.isEmpty ? null : ShapeCatalog.byId(id))
        .whereType<BlockShape>()
        .toList();
    final validator = GameEngine();
    validator.restore(
      restoredGrid: grid,
      restoredScore: score,
      restoredMoves: moves,
    );
    return shapes.isNotEmpty && shapes.every((shape) => validator.hasAnyMove([shape]));
  }

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'grid': grid,
    'score': score,
    'moves': moves,
    'secondsLeft': secondsLeft,
    'trayIds': trayIds,
    'streak': streak,
    'bestStreak': bestStreak,
  };

  static GameSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final modeName = value['mode'];
      final mode = GameMode.values.where((item) => item.name == modeName).first;
      final rawGrid = value['grid'] as List;
      final grid = rawGrid
          .map((row) => (row as List).map((cell) => cell as int).toList())
          .toList();
      final snapshot = GameSnapshot(
        mode: mode,
        grid: grid,
        score: value['score'] as int,
        moves: value['moves'] as int,
        secondsLeft: value['secondsLeft'] as int,
        trayIds: (value['trayIds'] as List).cast<String>(),
        // Saves created before streaks existed intentionally restore at zero.
        streak: value['streak'] is int ? value['streak'] as int : 0,
        bestStreak: value['bestStreak'] is int ? value['bestStreak'] as int : 0,
      );
      return snapshot.isValid ? snapshot : null;
    } catch (_) {
      return null;
    }
  }
}

abstract interface class GameSnapshotRepository {
  GameSnapshot? load(GameMode mode);
  Future<void> save(GameSnapshot snapshot);
  Future<void> clear(GameMode mode);
}

class HiveGameSnapshotRepository implements GameSnapshotRepository {
  HiveGameSnapshotRepository(this._box);

  final Box<dynamic> _box;
  // Every public mutation for a mode goes through the same chain. In
  // particular, a game-over clear can never be overtaken by an older save
  // completing late, while operations for different modes remain independent.
  final Map<GameMode, Future<void>> _operationChains = {};

  @override
  GameSnapshot? load(GameMode mode) {
    final raw = _box.get(mode.name);
    if (raw == null) return null;
    final snapshot = GameSnapshot.fromJson(raw);
    if (snapshot == null) unawaited(clear(mode));
    return snapshot;
  }

  @override
  Future<void> save(GameSnapshot snapshot) => _enqueue(
    snapshot.mode,
    () => _box.put(snapshot.mode.name, snapshot.toJson()),
  );

  @override
  Future<void> clear(GameMode mode) =>
      _enqueue(mode, () => _box.delete(mode.name));

  Future<void> _enqueue(GameMode mode, Future<void> Function() write) {
    final previous = _operationChains[mode] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => write());
    _operationChains[mode] = next;
    return next;
  }
}
