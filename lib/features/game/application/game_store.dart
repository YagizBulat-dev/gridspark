import 'dart:async';

import 'package:mobx/mobx.dart';

import '../data/game_snapshot_repository.dart';
import '../domain/game_engine.dart';
import '../domain/game_models.dart';

typedef PeriodicTimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

class GameStore {
  GameStore(
    this.mode, {
    GameEngine? engine,
    PeriodicTimerFactory? periodicTimer,
    int initialSeconds = 120,
    List<BlockShape>? initialTray,
    GameSnapshot? snapshot,
    this.onSnapshot,
    this.onClearSnapshot,
    this.onInvalidSnapshot,
    this.onProgress,
  }) : engine = engine ?? GameEngine(),
       _periodicTimer = periodicTimer ?? Timer.periodic {
    secondsLeft.value = initialSeconds;
    if (snapshot != null && snapshot.mode == mode && snapshot.isValid) {
      if (!_restore(snapshot)) {
        _discardInvalidSnapshot();
        _startFresh();
      }
    } else {
      if (snapshot != null) _discardInvalidSnapshot();
      _startFresh(initialTray: initialTray, resetEngine: snapshot != null);
    }
    if (mode == GameMode.timed) _ensureTimer();
  }

  final GameMode mode;
  final GameEngine engine;
  final PeriodicTimerFactory _periodicTimer;
  final FutureOr<void> Function(GameSnapshot snapshot)? onSnapshot;
  final FutureOr<void> Function()? onClearSnapshot;
  final FutureOr<void> Function()? onInvalidSnapshot;
  final FutureOr<void> Function(GameProgressEvent event)? onProgress;
  final gridVersion = Observable(0);
  final score = Observable(0);
  final secondsLeft = Observable(120);
  final isGameOver = Observable(false);
  final manuallyPaused = Observable(false);
  final lifecyclePaused = Observable(false);
  final lastPlacementPoints = Observable(0);
  final lastClearedLines = Observable(0);
  final streak = Observable(0);
  final bestStreak = Observable(0);
  final difficultyLevel = Observable(0);
  final lastMoveFeedback = Observable('Place a piece to begin');
  final lastClearedCells = ObservableList<CellOffset>();
  final lastPlacedCells = ObservableList<CellOffset>();
  final lastPlacedColorIndex = Observable(-1);
  final comboPopupTrigger = Observable(0);
  final trayRefillCount = Observable(0);
  final trayRefillSlot = Observable(-1);
  final tray = ObservableList<BlockShape?>();

  Timer? _timer;
  int _timerGeneration = 0;
  bool _disposed = false;
  bool _snapshotCleared = false;
  Future<void> _snapshotWriteChain = Future<void>.value();

  bool get isPaused => manuallyPaused.value || lifecyclePaused.value;

  void _startFresh({List<BlockShape>? initialTray, bool resetEngine = true}) {
    if (resetEngine) engine.reset();
    tray
      ..clear()
      ..addAll(initialTray ?? engine.generateTray(mode));
    score.value = 0;
    streak.value = 0;
    bestStreak.value = 0;
    difficultyLevel.value = mode == GameMode.rising ? 0 : -1;
    lastMoveFeedback.value = 'Place a piece to begin';
    lastClearedCells.clear();
    lastPlacedCells.clear();
    lastPlacedColorIndex.value = -1;
    trayRefillSlot.value = -1;
    gridVersion.value++;
  }

  void _discardInvalidSnapshot() {
    final discard = onInvalidSnapshot ?? onClearSnapshot;
    if (discard == null) return;
    _snapshotWriteChain = _snapshotWriteChain.then((_) async {
      try {
        await discard();
      } catch (_) {
        // A corrupt save must never prevent a clean game from starting.
      }
    });
  }

  bool _restore(GameSnapshot snapshot) {
    final restoredTray = snapshot.trayIds
        .map<BlockShape?>((id) => id.isEmpty ? null : ShapeCatalog.byId(id))
        .toList();
    final nonEmptyIds = snapshot.trayIds.where((id) => id.isNotEmpty).toList();
    final nonNullShapes = restoredTray.whereType<BlockShape>().toList();
    final hasValidTray =
        snapshot.trayIds.length == snapshotTraySize &&
        nonNullShapes.length == nonEmptyIds.length &&
        nonEmptyIds.toSet().length == nonEmptyIds.length &&
        nonEmptyIds.every(
          (id) => ShapeCatalog.isValidSnapshotId(id, mode),
        ) &&
        nonNullShapes.every(
          (shape) => ShapeCatalog.isAllowedInMode(shape, mode),
        );
    final hasValidSeconds = switch (mode) {
      GameMode.timed =>
        snapshot.secondsLeft > 0 && snapshot.secondsLeft <= maxTimedGameSeconds,
      GameMode.classic ||
      GameMode.rising => snapshot.secondsLeft == maxTimedGameSeconds,
    };
    if (!hasValidTray || !hasValidSeconds) {
      return false;
    }
    try {
      engine.restore(
        restoredGrid: snapshot.grid,
        restoredScore: snapshot.score,
        restoredMoves: snapshot.moves,
      );
      if (!nonNullShapes.every((shape) => engine.hasAnyMove([shape]))) {
        engine.reset();
        return false;
      }
      tray.addAll(restoredTray);
      // Heal legacy saves that stored empty slots after a placement: every
      // slot must hold a piece now that refills are immediate.
      for (var i = 0; i < tray.length; i++) {
        if (tray[i] != null) continue;
        tray[i] =
            engine.generateTrayShape(
              mode,
              excludingIds: tray.whereType<BlockShape>().map((s) => s.id),
            ) ??
            engine.generateTray(mode).first;
      }
      score.value = snapshot.score;
      streak.value = snapshot.streak;
      bestStreak.value = snapshot.bestStreak;
      secondsLeft.value = snapshot.secondsLeft;
      if (mode == GameMode.rising) {
        difficultyLevel.value =
            engine.difficultyLevelForScore(snapshot.score);
      }
      if (!engine.hasAnyMove(tray.whereType<BlockShape>())) {
        _endGame();
      }
      gridVersion.value++;
      return true;
    } on ArgumentError {
      engine.reset();
      return false;
    }
  }

  void _ensureTimer() {
    if (_disposed ||
        mode != GameMode.timed ||
        isPaused ||
        isGameOver.value ||
        _timer?.isActive == true) {
      return;
    }
    final generation = ++_timerGeneration;
    _timer = _periodicTimer(const Duration(seconds: 1), (_) {
      if (_disposed || generation != _timerGeneration || isPaused) return;
      runInAction(() {
        if (secondsLeft.value > 0) secondsLeft.value--;
        if (secondsLeft.value <= 0) _endGame();
      });
    });
  }

  void _cancelTimer() {
    _timerGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  void toggleManualPause() {
    if (_disposed || isGameOver.value) return;
    runInAction(() => manuallyPaused.value = !manuallyPaused.value);
    if (isPaused) {
      _cancelTimer();
      saveSnapshot();
    } else {
      _ensureTimer();
    }
  }

  void setLifecycleActive(bool active) {
    if (_disposed || lifecyclePaused.value == !active) return;
    runInAction(() => lifecyclePaused.value = !active);
    if (!active) {
      _cancelTimer();
      saveSnapshot();
    } else if (!manuallyPaused.value) {
      _ensureTimer();
    }
  }

  bool place(int trayIndex, int row, int col) {
    if (trayIndex < 0 ||
        trayIndex >= tray.length ||
        isGameOver.value ||
        isPaused) {
      return false;
    }
    final shape = tray[trayIndex];
    if (shape == null) return false;
    final result = engine.place(shape, row, col);
    if (!result.placed) return false;
    runInAction(() {
      final previousStreak = streak.value;
      if (result.lines > 0) {
        streak.value++;
        if (streak.value > bestStreak.value) bestStreak.value = streak.value;
      } else {
        streak.value = 0;
      }
      final streakBonus = result.lines > 0 ? previousStreak * 150 : 0;
      if (streakBonus > 0) engine.addScoreBonus(streakBonus);
      lastPlacedColorIndex.value = shape.colorIndex;
      // Replace the placed piece immediately so a new block arrives at once.
      // The refill is random (not guaranteed to fit) so the board can fill up
      // and the game can still end when none of the three pieces fit.
      final otherIds = tray.whereType<BlockShape>().map((s) => s.id);
      final newPiece =
          engine.generateTrayShape(mode, excludingIds: otherIds) ??
          engine.generateTrayShape(mode) ??
          engine.generateTray(mode).first;
      tray[trayIndex] = newPiece;
      trayRefillSlot.value = trayIndex;
      trayRefillCount.value++;

      score.value = engine.score;
      if (mode == GameMode.rising) {
        final newLevel = engine.difficultyLevelForScore(engine.score);
        if (newLevel != difficultyLevel.value) {
          difficultyLevel.value = newLevel;
        }
      }
      lastPlacementPoints.value = result.points + streakBonus;
      lastClearedLines.value = result.lines;
      lastClearedCells
        ..clear()
        ..addAll(result.clearedCells);
      lastPlacedCells
        ..clear()
        ..addAll(result.placedCells);
      if (result.lines > 0) comboPopupTrigger.value++;
      lastMoveFeedback.value = result.lines > 0
          ? '${result.lines} line${result.lines == 1 ? '' : 's'} cleared • '
                '${streak.value}x streak${streakBonus > 0 ? ' • +$streakBonus bonus' : ''}'
          : 'No clear • streak reset';
      gridVersion.value++;
      if (!engine.hasAnyMove(tray.whereType<BlockShape>())) {
        _endGame();
      }
    });
    final progress = onProgress;
    if (progress != null) {
      unawaited(
        Future<void>.sync(
          () => progress(
            GameProgressEvent(
              mode: mode,
              linesCleared: result.lines,
              score: score.value,
              moves: engine.moves,
            ),
          ),
        ).catchError((_) {}),
      );
    }
    saveSnapshot();
    return true;
  }

  int clearLines() {
    final linesCleared = engine.clearLines();
    if (linesCleared > 0) {
      runInAction(() {
        score.value = engine.score;
        if (mode == GameMode.rising) {
          final newLevel = engine.difficultyLevelForScore(engine.score);
          if (newLevel != difficultyLevel.value) {
            difficultyLevel.value = newLevel;
          }
        }
        gridVersion.value++;
      });
      saveSnapshot();
    }
    return linesCleared;
  }

  void _endGame() {
    if (isGameOver.value) return;
    isGameOver.value = true;
    _cancelTimer();
    unawaited(clearSnapshot());
  }

  GameSnapshot createSnapshot() => GameSnapshot(
    mode: mode,
    grid: engine.grid.map(List<int>.from).toList(),
    score: score.value,
    moves: engine.moves,
    secondsLeft: secondsLeft.value,
    trayIds: tray.map((shape) => shape?.id ?? '').toList(),
    streak: streak.value,
    bestStreak: bestStreak.value,
  );

  void saveSnapshot() {
    if (_disposed || _snapshotCleared || isGameOver.value) return;
    final writer = onSnapshot;
    if (writer == null) return;
    final snapshot = createSnapshot();
    _snapshotWriteChain = _snapshotWriteChain.then(
      (_) => _writeSnapshot(writer, snapshot),
    );
  }

  Future<void> _writeSnapshot(
    FutureOr<void> Function(GameSnapshot snapshot) writer,
    GameSnapshot snapshot,
  ) async {
    try {
      await writer(snapshot);
    } catch (_) {
      // Autosave is best-effort and must never interrupt gameplay or disposal.
    }
  }

  /// Permanently clears this session's save after all older saves finish.
  /// Once requested, this store can never enqueue another save.
  Future<void> clearSnapshot() {
    if (_snapshotCleared) return _snapshotWriteChain;
    _snapshotCleared = true;
    final clear = onClearSnapshot ?? onInvalidSnapshot;
    if (clear == null) return _snapshotWriteChain;
    _snapshotWriteChain = _snapshotWriteChain.then((_) async {
      try {
        await clear();
      } catch (_) {
        // Snapshot cleanup must not interrupt game-over/navigation flows.
      }
    });
    return _snapshotWriteChain;
  }

  Future<void> dispose() {
    if (_disposed) return _snapshotWriteChain;
    if (!isGameOver.value && !_snapshotCleared) saveSnapshot();
    _disposed = true;
    _cancelTimer();
    return _snapshotWriteChain;
  }
}

class GameProgressEvent {
  const GameProgressEvent({
    required this.mode,
    required this.linesCleared,
    required this.score,
    required this.moves,
  });

  final GameMode mode;
  final int linesCleared;
  final int score;
  final int moves;
}
