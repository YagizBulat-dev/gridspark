import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

// ── Test helpers ──

class _FakeBox extends Fake implements Box<dynamic> {
  _FakeBox([Map<dynamic, dynamic>? initial]) : _data = {...?initial};
  final Map<dynamic, dynamic> _data;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;

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

/// Takes a snapshot of the current engine grid state.
List<List<int>> _gridSnapshot(WidgetTester tester) {
  final state = tester.state(find.byType(GameScreen));
  final store = (state as dynamic).store as GameStore;
  return store.engine.grid.map(List<int>.from).toList();
}

/// Computes the set of cells that differ between [before] and the current grid.
Set<(int, int)> _computeGridDiff(
  WidgetTester tester,
  List<List<int>> before,
) {
  final state = tester.state(find.byType(GameScreen));
  final store = (state as dynamic).store as GameStore;
  final after = store.engine.grid;
  final diff = <(int, int)>{};
  for (var r = 0; r < after.length; r++) {
    for (var c = 0; c < after[r].length; c++) {
      if (before[r][c] != after[r][c]) diff.add((r, c));
    }
  }
  return diff;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Each target gets its own testWidgets with a fresh game state.
  /// This isolates each drag from the state changes of previous placements.
  /// After each placement, the tray slot becomes null and the Draggable
  /// tree rebuilds, which breaks subsequent gesture recognition. Starting
  /// fresh avoids this issue entirely.
  Future<void> _runSingleTarget({
    required String label,
    required (int, int) target,
    required List<BlockShape> trayPieces,
    required WidgetTester tester,
  }) async {
    final (r, c) = target;

    final services = buildFakeServices(reduceMotion: true);
    await tester.pumpWidget(buildGameScreen(services, GameMode.classic));
    await tester.pumpAndSettle();

    final gridFinder = find.byType(GameGrid);
    expect(gridFinder, findsOneWidget);

    final state = tester.state(find.byType(GameScreen));
    final store = (state as dynamic).store as GameStore;

    // Seed tray with the specific pieces for this target.
    store.tray
      ..clear()
      ..addAll(trayPieces);
    await tester.pumpAndSettle();

    final draggableCount = find.byType(Draggable<int>).evaluate().length;
    debugPrint('[calib:$label] tray seeded, $draggableCount Draggables');

    // Find a fitting piece.
    final draggables = find.byType(Draggable<int>);
    final draggableEls = draggables.evaluate().toList();
    int? foundDragIdx;
    int? usedTrayIndex;

    for (var di = 0; di < draggableEls.length; di++) {
      final dw = draggableEls[di].widget as Draggable<int>;
      final int ti = dw.data ?? -1;
      if (ti < 0) continue;
      if (store.tray[ti] != null &&
          store.engine.canPlace(store.tray[ti]!, r, c)) {
        foundDragIdx = di;
        usedTrayIndex = ti;
        break;
      }
    }

    expect(foundDragIdx, isNotNull,
        reason: '($r,$c): need a fitting piece in tray');

    final usedPiece = store.tray[usedTrayIndex!]!;
    final expectedCells = <(int, int)>{
      for (final cell in usedPiece.cells) (r + cell.row, c + cell.col),
    };
    debugPrint('[calib:$label] piece="${usedPiece.id}" '
        'expectedCells=$expectedCells');

    // Grid snapshot before drag.
    final gridBefore = _gridSnapshot(tester);

    // Get piece center.
    final pieceCenter = tester.getCenter(
      find
          .descendant(
            of: draggables.at(foundDragIdx!),
            matching: find.byType(BlockShapeView),
          )
          .first,
    );

    // Compute pointer position.
    final currentGridRect = tester.getRect(gridFinder);
    final pitch = GameGridState.cellPitch(
      currentGridRect.width,
      GameGridState.gridPadding,
      store.engine.size,
    );

    var localDy = GameGridState.gridPadding +
        (r + GameGridState.liftCells + 0.4) * pitch;
    final maxLocalDy = currentGridRect.height - GameGridState.gridPadding;
    if (localDy >= maxLocalDy) localDy = maxLocalDy - 0.01;

    final pointer = currentGridRect.topLeft + Offset(
      GameGridState.gridPadding + (c + 0.4) * pitch,
      localDy,
    );

    debugPrint('[calib:$label] pieceCenter=$pieceCenter '
        'pointer=$pointer pitch=$pitch');

    // ── Real drag: startGesture + multi-step moveTo + hold + up ──
    final gesture = await tester.startGesture(pieceCenter);
    const steps = 15;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await gesture.moveTo(pieceCenter + (pointer - pieceCenter) * t);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Hold at target position.
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    // Compute diff.
    final diffCells = _computeGridDiff(tester, gridBefore);

    if (diffCells.isEmpty) {
      debugPrint('[calib:$label] FAILED — no grid change after drag');
      // Don't fail yet — try dragFrom as fallback.
      final gridBefore2 = _gridSnapshot(tester);
      await tester.dragFrom(pieceCenter, pointer - pieceCenter);
      await tester.pumpAndSettle();
      final diffCells2 = _computeGridDiff(tester, gridBefore2);
      if (diffCells2.isEmpty) {
        debugPrint('[calib:$label] FAILED (dragFrom fallback also no diff)');
        fail('($r,$c): drag produced no grid change. '
            'piece="${usedPiece.id}" expected=$expectedCells');
      } else {
        // Fallback worked — check correctness.
        final ok = expectedCells.every((ec) => diffCells2.contains(ec));
        if (ok) {
          debugPrint('[calib:$label] OK (via dragFrom fallback) '
              'actual=$diffCells2');
          return; // pass
        } else {
          fail('($r,$c): MISMATCH via dragFrom fallback '
              'expected=$expectedCells actual=$diffCells2');
        }
      }
    }

    final allExpectedFilled =
        expectedCells.every((ec) => diffCells.contains(ec));

    if (allExpectedFilled) {
      debugPrint('[calib:$label] OK actual=$diffCells');
    } else {
      debugPrint('[calib:$label] MISMATCH expected=$expectedCells '
          'actual=$diffCells');
      fail('($r,$c): MISMATCH piece="${usedPiece.id}" '
          'expected=$expectedCells actual=$diffCells');
    }
  }

  // ── Target: (0,0) — top-left corner, h2 horizontal ──
  testWidgets('drag (0,0) — h2', (tester) async {
    await _runSingleTarget(
      label: '(0,0)',
      target: (0, 0),
      trayPieces: [
        ShapeCatalog.byId('h2')!,
        ShapeCatalog.byId('v2')!,
        ShapeCatalog.byId('single')!,
      ],
      tester: tester,
    );
  });

  // ── Target: (0,7) — top-right corner, v2 vertical ──
  testWidgets('drag (0,7) — v2', (tester) async {
    await _runSingleTarget(
      label: '(0,7)',
      target: (0, 7),
      trayPieces: [
        ShapeCatalog.byId('h2')!,
        ShapeCatalog.byId('v2')!,
        ShapeCatalog.byId('single')!,
      ],
      tester: tester,
    );
  });

  // ── Target: (7,0) — bottom-left corner, single ──
  testWidgets('drag (7,0) — single', (tester) async {
    await _runSingleTarget(
      label: '(7,0)',
      target: (7, 0),
      trayPieces: [
        ShapeCatalog.byId('h2')!,
        ShapeCatalog.byId('v2')!,
        ShapeCatalog.byId('single')!,
      ],
      tester: tester,
    );
  });

  // ── Target: (7,7) — bottom-right corner, single ──
  testWidgets('drag (7,7) — single', (tester) async {
    await _runSingleTarget(
      label: '(7,7)',
      target: (7, 7),
      trayPieces: [
        ShapeCatalog.byId('h2')!,
        ShapeCatalog.byId('v2')!,
        ShapeCatalog.byId('single')!,
      ],
      tester: tester,
    );
  });

  // ── Target: (3,3) — center, v2 vertical ──
  testWidgets('drag (3,3) — v2', (tester) async {
    await _runSingleTarget(
      label: '(3,3)',
      target: (3, 3),
      trayPieces: [
        ShapeCatalog.byId('h2')!,
        ShapeCatalog.byId('v2')!,
        ShapeCatalog.byId('single')!,
      ],
      tester: tester,
    );
  });
}
