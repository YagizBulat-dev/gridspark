import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/data/game_snapshot_repository.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:hive/hive.dart';

void main() {
  group('GameSnapshot.fromJson', () {
    test('accepts a valid snapshot', () {
      expect(GameSnapshot.fromJson(_json()), isNotNull);
    });

    test('old snapshots default streak fields to zero', () {
      final snapshot = GameSnapshot.fromJson(_json());
      expect(snapshot!.streak, 0);
      expect(snapshot.bestStreak, 0);
    });

    test('round-trips valid streak fields and rejects impossible ones', () {
      final json = _json(score: 20, moves: 2)
        ..['streak'] = 1
        ..['bestStreak'] = 2;
      final snapshot = GameSnapshot.fromJson(json);
      expect(snapshot!.streak, 1);
      expect(snapshot.bestStreak, 2);
      json['bestStreak'] = 0;
      expect(GameSnapshot.fromJson(json), isNull);
    });

    test('rejects corrupt grid cells before they can reach the UI', () {
      final json = _json();
      (json['grid'] as List<List<int>>)[0][0] = 8;
      expect(GameSnapshot.fromJson(json), isNull);
    });

    test('rejects invalid tray lengths and shape ids', () {
      expect(GameSnapshot.fromJson(_json(trayIds: <String>[])), isNull);
      expect(GameSnapshot.fromJson(_json(trayIds: ['single', 'h2'])), isNull);
      expect(
        GameSnapshot.fromJson(_json(trayIds: ['single', 'h2', 'v2', 'h3'])),
        isNull,
      );
      expect(
        GameSnapshot.fromJson(_json(trayIds: ['single', 'h2', 'bad'])),
        isNull,
      );
    });

    test('accepts snapshots with empty string tray ids (used slots)', () {
      final json = _json(trayIds: const ['single', '', '']);
      expect(GameSnapshot.fromJson(json), isNotNull);
    });

    test('rejects duplicate non-empty tray ids even with empty slots', () {
      final json = _json(trayIds: const ['single', 'single', '']);
      expect(GameSnapshot.fromJson(json), isNull);
    });

    test('rejects tray with all empty ids (nothing playable)', () {
      final json = _json(trayIds: const ['', '', '']);
      expect(GameSnapshot.fromJson(json), isNull);
    });

    test('rejects a tray containing pieces that cannot be played', () {
      final blockedGrid = List.generate(8, (_) => List<int>.filled(8, 0));
      blockedGrid[0][0] = -1;
      final json = _json(trayIds: ['single', 'h2', 'v2']);
      json['grid'] = blockedGrid;
      json['score'] = 10;
      json['moves'] = 1;

      expect(GameSnapshot.fromJson(json), isNull);
    });

    test('rejects invalid score, moves, seconds and mode', () {
      expect(GameSnapshot.fromJson(_json(score: -1)), isNull);
      expect(GameSnapshot.fromJson(_json(score: 0, moves: 1)), isNull);
      expect(GameSnapshot.fromJson(_json(secondsLeft: 119)), isNull);
      expect(GameSnapshot.fromJson(_json(mode: 'invalid')), isNull);
    });
  });

  group('HiveGameSnapshotRepository operation queue', () {
    test(
      'clear waits for an older save and remains the final operation',
      () async {
        final box = _BlockingSnapshotBox();
        final repository = HiveGameSnapshotRepository(box);

        final save = repository.save(GameSnapshot.fromJson(_json())!);
        final clear = repository.clear(GameMode.classic);
        await Future<void>.delayed(Duration.zero);

        expect(box.operations, ['save-start']);
        box.releaseSave.complete();
        await Future.wait([save, clear]);

        expect(box.operations, ['save-start', 'save-end', 'clear']);
        expect(repository.load(GameMode.classic), isNull);
      },
    );

    test('a failed mutation does not poison later operations', () async {
      final box = _FailOnceSnapshotBox();
      final repository = HiveGameSnapshotRepository(box);
      final snapshot = GameSnapshot.fromJson(_json())!;

      await expectLater(repository.save(snapshot), throwsStateError);
      await repository.save(snapshot);

      expect(repository.load(GameMode.classic), isNotNull);
    });
  });
}

Map<String, Object> _json({
  String mode = 'classic',
  int score = 0,
  int moves = 0,
  int secondsLeft = 120,
  List<String> trayIds = const ['single', 'h2', 'v2'],
}) => <String, Object>{
  'mode': mode,
  'grid': List.generate(8, (_) => List<int>.filled(8, -1)),
  'score': score,
  'moves': moves,
  'secondsLeft': secondsLeft,
  'trayIds': trayIds,
};

class _SnapshotBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> data = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    data.remove(key);
  }
}

class _BlockingSnapshotBox extends _SnapshotBox {
  final releaseSave = Completer<void>();
  final operations = <String>[];

  @override
  Future<void> put(dynamic key, dynamic value) async {
    operations.add('save-start');
    await releaseSave.future;
    await super.put(key, value);
    operations.add('save-end');
  }

  @override
  Future<void> delete(dynamic key) async {
    operations.add('clear');
    await super.delete(key);
  }
}

class _FailOnceSnapshotBox extends _SnapshotBox {
  bool fail = true;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (fail) {
      fail = false;
      throw StateError('disk full');
    }
    await super.put(key, value);
  }
}
