import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/leaderboard/application/leaderboard_store.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:hive/hive.dart';

void main() {
  test('a stale request cannot replace scores for a newer mode', () async {
    final remote = _ControlledRemote();
    final store = LeaderboardStore(
      LeaderboardRepository(_EmptyBox(), firebaseEnabled: true, remote: remote),
    );
    await Future<void>.delayed(Duration.zero);

    store.setMode('timed');
    await Future<void>.delayed(Duration.zero);
    remote.complete('timed', 200);
    await Future<void>.delayed(Duration.zero);
    remote.complete('classic', 100);
    await Future<void>.delayed(Duration.zero);

    expect(store.selectedMode.value, 'timed');
    expect(store.globalScores.single.mode, 'timed');
    expect(store.globalScores.single.score, 200);
    expect(store.isLoadingGlobal.value, isFalse);
  });

  test('dispose invalidates an outstanding global request', () async {
    final remote = _ControlledRemote();
    final store = LeaderboardStore(
      LeaderboardRepository(_EmptyBox(), firebaseEnabled: true, remote: remote),
    );
    await Future<void>.delayed(Duration.zero);

    store.dispose();
    remote.complete('classic', 100);
    await Future<void>.delayed(Duration.zero);

    expect(store.globalScores, isEmpty);
  });
}

class _ControlledRemote implements RemoteLeaderboardDataSource {
  final Map<String, Completer<List<ScoreEntry>>> _requests = {};

  @override
  Future<List<ScoreEntry>> fetchScores(String mode) {
    final completer = Completer<List<ScoreEntry>>();
    _requests[mode] = completer;
    return completer.future;
  }

  void complete(String mode, int score) {
    _requests[mode]!.complete([
      ScoreEntry(name: mode, score: score, mode: mode),
    ]);
  }

  @override
  Future<void> submit(ScoreEntry entry) async {}
}

class _EmptyBox extends Fake implements Box<dynamic> {
  @override
  Iterable<dynamic> get values => const [];
}
