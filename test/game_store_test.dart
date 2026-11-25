import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/application/game_store.dart';
import 'package:gridspark/features/game/data/game_snapshot_repository.dart';
import 'package:gridspark/features/game/domain/game_engine.dart';
import 'package:gridspark/features/game/domain/game_models.dart';

void main() {
  group('GameStore timer and pause behavior', () {
    test('timed mode stops at zero and enters game over once', () {
      final timers = _TimerHarness();
      final store = GameStore(
        GameMode.timed,
        periodicTimer: timers.create,
        initialSeconds: 2,
      );

      timers.tick();
      expect(store.secondsLeft.value, 1);
      timers.tick();
      expect(store.secondsLeft.value, 0);
      expect(store.isGameOver.value, isTrue);
      expect(timers.latest.isActive, isFalse);

      timers.tick();
      expect(store.secondsLeft.value, 0);
    });

    test('clock ticks in every mode, not only after a placement', () {
      final timedTimers = _TimerHarness();
      final timed = GameStore(
        GameMode.timed,
        periodicTimer: timedTimers.create,
        initialSeconds: 30,
      );
      for (var i = 0; i < 3; i++) {
        timedTimers.tick();
      }
      expect(timed.secondsLeft.value, 27);
      expect(timed.elapsedSeconds.value, 3);

      final classicTimers = _TimerHarness();
      final classic = GameStore(
        GameMode.classic,
        periodicTimer: classicTimers.create,
      );
      for (var i = 0; i < 4; i++) {
        classicTimers.tick();
      }
      expect(classic.secondsLeft.value, 120);
      expect(classic.elapsedSeconds.value, 4);

      final risingTimers = _TimerHarness();
      final rising = GameStore(
        GameMode.rising,
        periodicTimer: risingTimers.create,
      );
      for (var i = 0; i < 2; i++) {
        risingTimers.tick();
      }
      expect(rising.secondsLeft.value, 120);
      expect(rising.elapsedSeconds.value, 2);
    });

    test('manual pause freezes the clock in untimed modes too', () {
      final timers = _TimerHarness();
      final store = GameStore(GameMode.classic, periodicTimer: timers.create);

      timers.tick();
      expect(store.elapsedSeconds.value, 1);

      store.toggleManualPause();
      timers.tick(); // cancelled timer must not advance the clock
      expect(store.elapsedSeconds.value, 1);

      store.toggleManualPause();
      timers.tick();
      expect(store.elapsedSeconds.value, 2);
    });

    test('manual pause cancels timer and resume creates one safe timer', () {
      final timers = _TimerHarness();
      final store = GameStore(
        GameMode.timed,
        periodicTimer: timers.create,
        initialSeconds: 10,
      );
      final original = timers.latest;

      store.toggleManualPause();
      expect(store.isPaused, isTrue);
      expect(original.isActive, isFalse);
      original.fireEvenIfCancelled();
      expect(store.secondsLeft.value, 10);

      store.toggleManualPause();
      expect(store.isPaused, isFalse);
      expect(timers.created, 2);
      timers.tick();
      expect(store.secondsLeft.value, 9);
    });

    test('lifecycle resume does not override a manual pause', () {
      final timers = _TimerHarness();
      final store = GameStore(GameMode.timed, periodicTimer: timers.create);

      store.toggleManualPause();
      store.setLifecycleActive(false);
      store.setLifecycleActive(true);

      expect(store.manuallyPaused.value, isTrue);
      expect(store.isPaused, isTrue);
      expect(timers.created, 1);
    });

    test('dispose invalidates racing callbacks and is idempotent', () {
      final timers = _TimerHarness();
      final store = GameStore(
        GameMode.timed,
        periodicTimer: timers.create,
        initialSeconds: 5,
      );
      final timer = timers.latest;

      store.dispose();
      store.dispose();
      timer.fireEvenIfCancelled();

      expect(store.secondsLeft.value, 5);
      expect(timer.isActive, isFalse);
    });

    test('pause writes a restorable snapshot', () async {
      final timers = _TimerHarness();
      GameSnapshot? snapshot;
      final store = GameStore(
        GameMode.timed,
        periodicTimer: timers.create,
        initialSeconds: 30,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
        ],
        onSnapshot: (value) => snapshot = value,
      );
      expect(store.place(0, 0, 0), isTrue);
      store.setLifecycleActive(false);
      await Future<void>.delayed(Duration.zero);

      expect(snapshot, isNotNull);
      expect(snapshot!.grid[0][0], 0);
      expect(snapshot!.score, 25);

      final restored = GameStore(
        GameMode.timed,
        periodicTimer: timers.create,
        snapshot: snapshot,
      );
      expect(restored.engine.grid[0][0], 0);
      expect(restored.score.value, 25);
      expect(restored.secondsLeft.value, 30);
      expect(restored.engine.moves, 1);
      expect(restored.tray.map((shape) => shape?.id ?? ''), snapshot!.trayIds);
    });

    test('serializes asynchronous snapshot writes in creation order', () async {
      final writes = <GameSnapshot>[];
      final firstWrite = Completer<void>();
      var writeCount = 0;
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
        ],
        onSnapshot: (snapshot) async {
          writeCount++;
          if (writeCount == 1) await firstWrite.future;
          writes.add(snapshot);
        },
      );

      expect(store.place(0, 0, 0), isTrue);
      expect(store.place(0, 1, 0), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(writes, isEmpty);

      firstWrite.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(writes.map((snapshot) => snapshot.moves), [1, 2]);
    });

    test(
      'game-over clear waits for saves and prevents stale rewrite',
      () async {
        final operations = <String>[];
        final saveGate = Completer<void>();
        final engine = GameEngine(size: 2);
        engine.grid[0][1] = 0;
        engine.grid[1][0] = 0;
        engine.grid[1][1] = 0;
        final store = GameStore(
          GameMode.classic,
          engine: engine,
          initialTray: [ShapeCatalog.all.first, ShapeCatalog.all.last],
          onSnapshot: (_) async {
            await saveGate.future;
            operations.add('save');
          },
          onClearSnapshot: () async => operations.add('clear'),
        );

        store.saveSnapshot();
        await Future<void>.delayed(Duration.zero);
        expect(store.place(0, 0, 0), isTrue);
        expect(store.isGameOver.value, isTrue);
        store.saveSnapshot();
        expect(operations, isEmpty);

        saveGate.complete();
        await store.clearSnapshot();
        await store.dispose();

        expect(operations, ['save', 'clear']);
      },
    );
  });

  group('GameStore snapshot validation', () {
    test('rejects corrupt grid cells and starts clean', () {
      final grid = _emptyGrid()..[0][0] = blockColorCount;
      final store = GameStore(
        GameMode.classic,
        snapshot: _snapshot(grid: grid),
      );

      _expectCleanPlayableStore(store);
    });

    test('rejects wrong grid dimensions and starts clean', () {
      final store = GameStore(
        GameMode.classic,
        snapshot: _snapshot(grid: [List<int>.filled(8, -1)]),
      );

      _expectCleanPlayableStore(store);
    });

    test(
      'rejects short, empty, long, duplicate, unknown and mode-invalid trays',
      () {
        final invalidTrays = <List<String>>[
          [],
          ['single', 'h2'],
          ['single', 'h2', 'v2', 'h3'],
          ['single', 'single', 'h2'],
          ['single', 'h2', 'unknown'],
        ];

        for (final trayIds in invalidTrays) {
          final store = GameStore(
            GameMode.classic,
            snapshot: _snapshot(trayIds: trayIds),
          );
          _expectCleanPlayableStore(store);
        }

        final timedWithSingle = GameStore(
          GameMode.timed,
          periodicTimer: _TimerHarness().create,
          snapshot: _snapshot(
            mode: GameMode.timed,
            secondsLeft: 30,
            trayIds: const ['single', 'h2', 'v2'],
          ),
        );
        _expectCleanPlayableStore(timedWithSingle);

        final risingWithLargeShape = GameStore(
          GameMode.rising,
          snapshot: _snapshot(
            mode: GameMode.rising,
            trayIds: const ['corner5', 'h2', 'v2'],
          ),
        );
        _expectCleanPlayableStore(risingWithLargeShape);
      },
    );

    test('rejects invalid score, moves, seconds and mode', () {
      final invalidSnapshots = [
        _snapshot(score: -1),
        _snapshot(score: 10, moves: -1),
        _snapshot(score: 0, moves: 1),
        _snapshot(secondsLeft: 119),
      ];
      for (final snapshot in invalidSnapshots) {
        final store = GameStore(GameMode.classic, snapshot: snapshot);
        _expectCleanPlayableStore(store);
      }

      final wrongMode = GameStore(
        GameMode.classic,
        snapshot: _snapshot(mode: GameMode.rising),
      );
      _expectCleanPlayableStore(wrongMode);

      final expiredTimed = GameStore(
        GameMode.timed,
        periodicTimer: _TimerHarness().create,
        snapshot: _snapshot(mode: GameMode.timed, secondsLeft: 0),
      );
      _expectCleanPlayableStore(expiredTimed, expectedSeconds: 120);
    });

    test('rejects and deletes a completed or unplayable snapshot', () async {
      var cleared = false;
      final fullGrid = List.generate(8, (_) => List<int>.filled(8, 0));
      final store = GameStore(
        GameMode.classic,
        snapshot: _snapshot(
          grid: fullGrid,
          score: 100,
          moves: 1,
          trayIds: const ['h2', 'v2', 'h3'],
        ),
        onInvalidSnapshot: () => cleared = true,
      );

      await Future<void>.delayed(Duration.zero);
      _expectCleanPlayableStore(store);
      expect(store.isGameOver.value, isFalse);
      expect(cleared, isTrue);
    });

    test('restores a complete valid snapshot', () {
      final grid = _emptyGrid()..[2][3] = 4;
      final snapshot = _snapshot(
        grid: grid,
        score: 40,
        moves: 2,
        trayIds: const ['single', 'h2', 'v2'],
      );

      final store = GameStore(GameMode.classic, snapshot: snapshot);

      expect(store.engine.grid, grid);
      expect(store.score.value, 40);
      expect(store.engine.moves, 2);
      expect(store.secondsLeft.value, 120);
      expect(store.tray.map((shape) => shape?.id ?? ''), snapshot.trayIds);
      expect(
        store.engine.hasAnyMove(store.tray),
        isTrue,
      );
    });

    test('rejects a partially consumed tray and starts fresh', () {
      final snapshot = _snapshot(
        score: 20,
        moves: 1,
        trayIds: const ['h2', 'v2'],
      );

      final store = GameStore(GameMode.classic, snapshot: snapshot);

      _expectCleanPlayableStore(store);
    });
  });

  group('GameStore placement edge cases', () {
    test(
      'line clears build streak, add deterministic bonus, and misses reset it '
      'after the combo window',
      () {
        final engine = GameEngine();
        for (var col = 0; col < 7; col++) {
          engine.grid[0][col] = 0;
          engine.grid[1][col] = 0;
        }
        final store = GameStore(
          GameMode.classic,
          engine: engine,
          initialTray: const [
            BlockShape('single', [CellOffset(0, 0)]),
            BlockShape('single', [CellOffset(0, 0)]),
            BlockShape('single', [CellOffset(0, 0)]),
            BlockShape('single', [CellOffset(0, 0)]),
            BlockShape('single', [CellOffset(0, 0)]),
          ],
        );

        expect(store.place(0, 0, 7), isTrue);
        expect(store.streak.value, 1);
        expect(store.score.value, 275); // 25 + 250
        expect(store.place(1, 1, 7), isTrue);
        expect(store.streak.value, 2);
        expect(store.bestStreak.value, 2);
        expect(store.lastPlacementPoints.value, 425); // 275 + 1*150 streak bonus
        expect(store.score.value, 700); // 275 + 425

        // The streak survives setup moves until the combo window expires.
        expect(store.place(2, 3, 3), isTrue);
        expect(store.streak.value, 2);
        expect(store.lastMoveFeedback.value, contains('keep'));
        expect(store.place(3, 4, 4), isTrue);
        expect(store.streak.value, 2);
        expect(store.place(4, 5, 5), isTrue);
        expect(store.streak.value, 0);
        expect(store.bestStreak.value, 2);
        expect(store.lastMoveFeedback.value, contains('reset'));
      },
    );

    test('rejects placement while paused or after game over', () {
      final engine = GameEngine(size: 2);
      engine.grid[0][1] = 0;
      engine.grid[1][0] = 0;
      engine.grid[1][1] = 0;
      final store = GameStore(
        GameMode.classic,
        engine: engine,
        initialTray: [ShapeCatalog.all.first, ShapeCatalog.all.last],
      );

      store.toggleManualPause();
      expect(store.place(0, 0, 0), isFalse);
      store.toggleManualPause();
      expect(store.place(0, 0, 0), isTrue);
      expect(store.isGameOver.value, isTrue);
      expect(store.place(0, 0, 0), isFalse);
    });

    test('invalid tray indexes never mutate state', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: [ShapeCatalog.all.first],
      );
      expect(store.place(-1, 0, 0), isFalse);
      expect(store.place(1, 0, 0), isFalse);
      expect(store.score.value, 0);
      expect(store.tray, hasLength(1));
    });

    test('clearLines awards score consistent with place()', () {
      // Guard against the latent inconsistency where engine.clearLines() (the
      // only implementation behind GameStore.clearLines) cleared lines without
      // ever updating the score, silently diverging from place().
      final engine = GameEngine();
      for (var c = 0; c < 8; c++) {
        engine.grid[0][c] = 0;
      }
      final store = GameStore(GameMode.classic, engine: engine);
      expect(store.clearLines(), 1);
      expect(store.score.value, 250);
      expect(store.engine.grid[0].every((cell) => cell == -1), isTrue);
    });

    test('comboPopupTrigger increments on line clears', () {
      final engine = GameEngine();
      for (var col = 0; col < 7; col++) {
        engine.grid[0][col] = 0;
      }
      final store = GameStore(
        GameMode.classic,
        engine: engine,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      expect(store.comboPopupTrigger.value, 0);
      // Place at (0,7) → completes row 0 → 1 line cleared → trigger increments.
      expect(store.place(0, 0, 7), isTrue);
      expect(store.comboPopupTrigger.value, 1);
      // Place a non-clearing block → trigger stays the same.
      expect(store.place(1, 3, 3), isTrue);
      expect(store.comboPopupTrigger.value, 1);
    });

    test('trayRefillCount increments when all tray slots are used', () {
      final store = GameStore(
        GameMode.classic,
        initialTray: const [
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
          BlockShape('single', [CellOffset(0, 0)]),
        ],
      );

      expect(store.trayRefillCount.value, 0);
      // Use all 3 blocks → refill.
      expect(store.place(0, 0, 0), isTrue);
      expect(store.place(1, 1, 0), isTrue);
      expect(store.trayRefillCount.value, 0); // not yet
      expect(store.place(2, 2, 0), isTrue);
      expect(store.trayRefillCount.value, 1); // all 3 used → refill
      expect(store.tray, hasLength(3));
    });

    test('lastPlacedCells is populated on placement', () {
      final engine = GameEngine();
      final store = GameStore(
        GameMode.classic,
        engine: engine,
        initialTray: const [
          BlockShape('h2', [
            CellOffset(0, 0),
            CellOffset(0, 1),
          ]),
        ],
      );

      expect(store.lastPlacedCells, isEmpty);
      expect(store.place(0, 3, 5), isTrue);
      expect(store.lastPlacedCells, [
        const CellOffset(3, 5),
        const CellOffset(3, 6),
      ]);
    });
  });
}

List<List<int>> _emptyGrid() =>
    List.generate(8, (_) => List<int>.filled(8, -1));

GameSnapshot _snapshot({
  GameMode mode = GameMode.classic,
  List<List<int>>? grid,
  int score = 0,
  int moves = 0,
  int secondsLeft = 120,
  List<String> trayIds = const ['single', 'h2', 'v2'],
}) => GameSnapshot(
  mode: mode,
  grid: grid ?? _emptyGrid(),
  score: score,
  moves: moves,
  secondsLeft: secondsLeft,
  trayIds: trayIds,
);

void _expectCleanPlayableStore(GameStore store, {int expectedSeconds = 120}) {
  expect(
    store.engine.grid.expand((row) => row).every((cell) => cell == -1),
    isTrue,
  );
  expect(store.score.value, 0);
  expect(store.engine.moves, 0);
  expect(store.secondsLeft.value, expectedSeconds);
  expect(store.tray, hasLength(snapshotTraySize));
  expect(
    store.tray.map((shape) => shape?.id ?? '').toSet(),
    hasLength(snapshotTraySize),
  );
  expect(store.engine.hasAnyMove(store.tray), isTrue);
}

class _TimerHarness {
  final timers = <_ManualTimer>[];

  Timer create(Duration duration, void Function(Timer timer) callback) {
    final timer = _ManualTimer(callback);
    timers.add(timer);
    return timer;
  }

  int get created => timers.length;
  _ManualTimer get latest => timers.last;
  void tick() => latest.fire();
}

class _ManualTimer implements Timer {
  _ManualTimer(this.callback);

  final void Function(Timer timer) callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    callback(this);
  }

  void fireEvenIfCancelled() => callback(this);

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}
