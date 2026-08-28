import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/challenges/data/daily_challenge_repository.dart';
import 'package:gridspark/features/game/application/game_store.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'generates deterministic daily goals and records mode-aware progress',
    () async {
      final box = _MemoryBox();
      final day = DateTime(2026, 8, 14);
      final repository = DailyChallengeRepository(box, clock: () => day);
      final initialTargets = repository.challenges
          .map((item) => item.target)
          .toList();

      await repository.record(
        const GameProgressEvent(
          mode: GameMode.timed,
          linesCleared: 2,
          score: 850,
          moves: 1,
        ),
      );

      expect(repository.challenges.map((item) => item.target), initialTargets);
      expect(repository.challenges[0].progress, 2);
      expect(repository.challenges[1].progress, 1);
      expect(repository.challenges[2].progress, 850);
    },
  );

  test(
    'refreshes, clears progress and notifies when local date changes',
    () async {
      final box = _MemoryBox();
      var day = DateTime(2026, 8, 14);
      final repository = DailyChallengeRepository(box, clock: () => day);
      await repository.record(
        const GameProgressEvent(
          mode: GameMode.classic,
          linesCleared: 1,
          score: 100,
          moves: 1,
        ),
      );
      day = DateTime(2026, 8, 15);
      var notifications = 0;
      repository.addListener(() => notifications++);

      expect(repository.refreshToday(), isTrue);
      expect(repository.challenges.every((item) => item.progress == 0), isTrue);
      expect(notifications, 1);
    },
  );

  test('serializes concurrent records without losing progress', () async {
    final box = _BlockingBox();
    final repository = DailyChallengeRepository(
      box,
      clock: () => DateTime(2026, 8, 14),
    );

    final first = repository.record(_event(lines: 2, score: 500));
    final second = repository.record(_event(lines: 3, score: 900));
    await Future<void>.delayed(Duration.zero);
    expect(box.startedWrites, 1);

    box.releaseFirst.complete();
    await Future.wait([first, second]);

    expect(box.startedWrites, 2);
    expect(repository.challenges[0].progress, 5);
    expect(repository.challenges[1].progress, 2);
    expect(repository.challenges[2].progress, 900);
    final persisted = box.data['dailyChallenges'] as Map;
    expect((persisted['progress'] as Map)['lines'], 5);
  });

  test('refreshToday notifies listeners on day rollover', () {
    final box = _MemoryBox();
    var day = DateTime(2026, 8, 14);
    final repository = DailyChallengeRepository(box, clock: () => day);
    var notifications = 0;
    repository.addListener(() => notifications++);

    expect(repository.refreshToday(), isFalse);
    day = DateTime(2026, 8, 15);
    expect(repository.refreshToday(), isTrue);
    expect(notifications, 1);
  });

  test(
    'failed persistence does not expose progress and chain recovers',
    () async {
      final box = _FailOnceBox();
      final repository = DailyChallengeRepository(
        box,
        clock: () => DateTime(2026, 8, 14),
      );

      await expectLater(
        repository.record(_event(lines: 2, score: 500)),
        throwsStateError,
      );
      expect(repository.challenges[0].progress, 0);
      expect(repository.challenges[1].progress, 0);

      await repository.record(_event(lines: 3, score: 700));
      expect(repository.challenges[0].progress, 3);
      expect(repository.challenges[1].progress, 1);
    },
  );
}

GameProgressEvent _event({required int lines, required int score}) =>
    GameProgressEvent(
      mode: GameMode.timed,
      linesCleared: lines,
      score: score,
      moves: 1,
    );

class _MemoryBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> data = {};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => data[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    data[key] = value;
  }
}

class _BlockingBox extends _MemoryBox {
  final releaseFirst = Completer<void>();
  int startedWrites = 0;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    startedWrites++;
    if (startedWrites == 1) await releaseFirst.future;
    await super.put(key, value);
  }
}

class _FailOnceBox extends _MemoryBox {
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
