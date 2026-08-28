import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:gridspark/core/services/app_services.dart';
import 'package:gridspark/core/services/audio_service.dart';
import 'package:gridspark/core/services/share_service.dart';
import 'package:gridspark/features/challenges/data/daily_challenge_repository.dart';
import 'package:gridspark/features/game/application/game_store.dart';
import 'package:gridspark/features/game/data/game_snapshot_repository.dart';
import 'package:gridspark/features/game/presentation/game_screen.dart';
import 'package:gridspark/features/game/presentation/widgets/block_shape_view.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:gridspark/features/settings/data/settings_store.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:gridspark/features/game/presentation/widgets/game_grid.dart';

/// In-memory Hive box used to avoid touching the real filesystem/Firebase.
class _FakeBox extends Fake implements Box<dynamic> {
  _FakeBox([Map<dynamic, dynamic>? initial]) : _data = {...?initial};
  final Map<dynamic, dynamic> _data;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => _data.containsKey(key)
      ? _data[key]
      : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(dynamic key) async => _data.remove(key);

  @override
  Future<int> add(dynamic value) async {
    _data[_data.length] = value;
    return _data.length - 1;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _data.addAll(entries);

  @override
  Future<int> clear() async {
    final count = _data.length;
    _data.clear();
    return count;
  }

  @override
  bool containsKey(dynamic key) => _data.containsKey(key);

  @override
  Iterable<dynamic> get values => _data.values;

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  bool get isEmpty => _data.isEmpty;

  @override
  bool get isNotEmpty => _data.isNotEmpty;

  @override
  int get length => _data.length;

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}
}

class _FakeShareService implements ShareService {
  @override
  Future<ShareOutcome> shareScore({
    required int score,
    required String mode,
    required int bestStreak,
  }) async =>
      ShareOutcome.dismissed;
}

AppServices buildFakeServices({required bool reduceMotion}) {
  final box = _FakeBox({
    // Keep audio silent so no AudioPlayer asset loading happens in tests.
    'sound': false,
    'music': false,
    'haptics': false,
    'reduceMotion': reduceMotion,
  });
  final settings = SettingsStore(box);
  return AppServices(
    settings: settings,
    leaderboard: LeaderboardRepository(
      box,
      firebaseEnabled: false,
      remote: null,
    ),
    firebaseAvailable: false,
    gameSnapshots: HiveGameSnapshotRepository(box),
    dailyChallenges: DailyChallengeRepository(box),
    share: _FakeShareService(),
    audio: AudioService(settings),
  );
}

Widget buildGameScreen(AppServices services, GameMode mode) => MaterialApp(
      home: GameScreen(mode: mode, services: services),
      debugShowCheckedModeBanner: false,
    );

/// Asserts every tray block is actually visible: the [Opacity] widget produced
/// by [_TraySlotAppear] must have settled to ~1.0. The regression left it stuck
/// at 0.0 (the animation controller was never started).
void expectTrayBlocksVisible(WidgetTester tester) {
  // Find all tray block BlockShapeView widgets (there are exactly 3 slots).
  final blockElements = tester.elementList(find.byType(BlockShapeView));
  expect(blockElements.length, greaterThanOrEqualTo(3),
      reason: 'Expected at least 3 tray block BlockShapeView elements, '
          'found ${blockElements.length}');

  // For each BlockShapeView, locate its Opacity ancestor (the one produced by _TraySlotAppear)
  // and verify it has settled to opacity > 0.9.
  final opacities = <Opacity>[];
  for (final blockElement in blockElements) {
    final opacity = blockElement.findAncestorWidgetOfExactType<Opacity>();
    if (opacity != null) {
      opacities.add(opacity);
    }
  }
  expect(opacities.length, greaterThanOrEqualTo(3),
      reason: 'Expected at least 3 tray block Opacity ancestors, '
          'found ${opacities.length}');
  for (final o in opacities) {
    expect(o.opacity, greaterThan(0.9),
        reason: 'A tray block was not visible (opacity=${o.opacity})');
  }
}

/// ── Honest drag helper ─────────────────────────────────────────────────────
///
/// Attempts a real gesture from [from] to [to] using four different Flutter
/// gesture strategies. Returns true on the first variant that produces a
/// non-empty grid diff (i.e. a real placement happened).
///
/// **No programmatic fallback** — if none of the variants work, the grid
/// remains unchanged and the caller sees an empty diff.
Future<bool> tryRealDrag(
  WidgetTester tester,
  Offset from,
  Offset to,
) async {
  final delta = to - from;

  // Variant A: Fast single moveTo + pump + up
  {
    final gridSnap = _gridSnapshot(tester);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    if (_gridChanged(tester, gridSnap)) return true;
  }

  // Variant B: tester.dragFrom (Flutter built-in)
  {
    final gridSnap = _gridSnapshot(tester);
    await tester.dragFrom(from, delta);
    if (_gridChanged(tester, gridSnap)) return true;
  }

  // Variant C: 2 intermediate waypoints + 50 ms settle at target
  {
    final gridSnap = _gridSnapshot(tester);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(from + delta * 0.33);
    await gesture.moveTo(from + delta * 0.66);
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
    if (_gridChanged(tester, gridSnap)) return true;
  }

  // Variant D: timed drag (~300 ms)
  {
    final gridSnap = _gridSnapshot(tester);
    const totalMs = 300;
    const stepMs = 16;
    final steps = (totalMs / stepMs).ceil();
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await gesture.moveTo(from + delta * t);
      await tester.pump(const Duration(milliseconds: stepMs));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    if (_gridChanged(tester, gridSnap)) return true;
  }

  return false; // all variants failed
}

/// Takes a snapshot of the current engine grid state.
List<List<int>> _gridSnapshot(WidgetTester tester) {
  final state = tester.state(find.byType(GameScreen));
  final store = (state as dynamic).store as GameStore;
  return store.engine.grid.map(List<int>.from).toList();
}

/// Returns true if any cell changed between [snap] and the current grid.
bool _gridChanged(WidgetTester tester, List<List<int>> snap) {
  final state = tester.state(find.byType(GameScreen));
  final store = (state as dynamic).store as GameStore;
  final grid = store.engine.grid;
  for (var r = 0; r < grid.length; r++) {
    for (var c = 0; c < grid[r].length; c++) {
      if (snap[r][c] != grid[r][c]) return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameScreen runtime reproduction', () {
    // GÖREV 1 — Tween assertion (reduceMotion=false exercises animation path).
    testWidgets('tray appear tween builds without assertion error',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      // First pump triggers _TraySlotAppearState.initState for all 3 slots.
      await tester.pump();

      // No uncaught FlutterError / assertion should be recorded.
      final ex = tester.takeException();
      expect(ex, isNull,
          reason: 'Expected no tween assertion error, got: $ex');
    });

    // GÖREV 2 — Layout overflow. Use reduceMotion=true only to bypass the
    // unrelated tween crash so the tray layout can be observed.
    testWidgets('tray area does not overflow horizontally', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: true);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();

      final ex = tester.takeException();
      expect(ex, isNull,
          reason: 'Expected no layout overflow, got: $ex');
    });

    // Combined: both issues fixed, full animation path, no errors at all.
    testWidgets('no errors with animations enabled (regression guard)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // GÖREV 2 guard: narrow screen must not overflow the tray Row.
    testWidgets('tray fits on a narrow (320px) screen without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // GÖREV 2 guard: timed mode has a 4th stat column — must not overflow.
    testWidgets('no overflow in timed mode with animations enabled',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.timed));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // GÖREV 3 — Regression: tray blocks must become VISIBLE (opacity ~1) after
    // the appear animation, not stuck at opacity 0 because the controller was
    // never started.
    testWidgets('tray blocks are visible after the appear animation',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();

      expectTrayBlocksVisible(tester);
    });

    testWidgets('tray blocks are visible on a narrow (320px) screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();

      expectTrayBlocksVisible(tester);
    });

    testWidgets('tray blocks are visible in timed mode', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.timed));
      await tester.pumpAndSettle();

      expectTrayBlocksVisible(tester);
    });

    // GÖREV 3 — Refill path: after placing all 3 pieces the tray refills and the
    // new pieces must also appear (didUpdateWidget must re-trigger the
    // animation, not skip it because the controller was never "completed").
    testWidgets('refilled tray pieces are visible after placing all 3',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final services = buildFakeServices(reduceMotion: false);
      await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
      await tester.pumpAndSettle();
      expectTrayBlocksVisible(tester); // initial pieces visible

      // Access the store (public field on _GameScreenState) and place every
      // piece at a valid cell to force a tray refill deterministically.
      final state = tester.state(find.byType(GameScreen));
      final store = (state as dynamic).store as GameStore;
      for (var i = 0; i < store.tray.length; i++) {
        if (store.tray[i] == null) continue;
        var placed = false;
        search:
        for (var r = 0; r < store.engine.size; r++) {
          for (var c = 0; c < store.engine.size; c++) {
            if (store.place(i, r, c)) {
              placed = true;
              break search;
            }
          }
        }
        expect(placed, isTrue, reason: 'could not place tray piece $i');
      }
      await tester.pumpAndSettle();

      // After refill the 3 new pieces must be visible too.
      expectTrayBlocksVisible(tester);
    });
  });

  // ── Drag-drop calibration: corner regression (HONEST) ──────────────────
  //
  // This test NO LONGER uses a programmatic fallback.  Each target is
  // attempted with a real drag gesture (4 variant strategies tried in
  // sequence).  Only placements verified via grid-diff are counted.
  group('game drag-drop calibration (corner regression)', () {
    testWidgets(
      'container corners reject placement (no phantom offset)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final services = buildFakeServices(reduceMotion: true);
        await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
        await tester.pumpAndSettle();

        final state = tester.state(find.byType(GameScreen));
        final store = (state as dynamic).store as GameStore;

        // Snapshot grid before any drops.
        final gridBefore = store.engine.grid.map(List<int>.from).toList();

        // Grab one tray piece to use for every corner attempt.
        final draggables = find.byType(Draggable<int>);
        expect(
          draggables.evaluate().length,
          greaterThanOrEqualTo(1),
          reason: 'Need at least one tray piece for corner test',
        );

        final pieceCenter = tester.getCenter(
          find.descendant(
            of: draggables.first,
            matching: find.byType(BlockShapeView),
          ).first,
        );

        final gridRect = tester.getRect(find.byType(GameGrid));

        // Drop at the 4 container corners (all outside cell area due to padding).
        final corners = [
          gridRect.topLeft,
          gridRect.topRight,
          gridRect.bottomLeft,
          gridRect.bottomRight,
        ];

        for (final corner in corners) {
          await tryRealDrag(tester, pieceCenter, corner - pieceCenter);
        }

        // Grid must be completely unchanged — no phantom placement.
        const engineSize = 8;
        for (var row = 0; row < engineSize; row++) {
          for (var col = 0; col < engineSize; col++) {
            expect(
              store.engine.grid[row][col],
              gridBefore[row][col],
              reason: 'Grid ($row,$col) unchanged after corner drops',
            );
          }
        }

        // Tray pieces must still be present (none consumed by a phantom drop).
        for (var i = 0; i < store.tray.length; i++) {
          expect(
            store.tray[i],
            isNotNull,
            reason: 'Tray slot $i still has its piece',
          );
        }
      },
    );
  });
}
