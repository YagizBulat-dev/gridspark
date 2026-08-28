import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:hive/hive.dart';

void main() {
  group('LeaderboardRepository', () {
    test('filters and sorts local scores by mode', () {
      final box = _MemoryBox([
        {'name': 'A', 'score': 20, 'mode': 'classic'},
        {'name': 'B', 'score': 50, 'mode': 'timed'},
        {'name': 'C', 'score': 40, 'mode': 'classic'},
      ]);
      final repository = LeaderboardRepository(box, firebaseEnabled: false);

      final scores = repository.localScores(mode: 'classic');

      expect(scores.map((score) => score.name), ['C', 'A']);
    });

    test(
      'falls back to mode-filtered local scores when remote read fails',
      () async {
        final box = _MemoryBox([
          {'name': 'Classic', 'score': 30, 'mode': 'classic'},
          {'name': 'Timed', 'score': 90, 'mode': 'timed'},
        ]);
        final repository = LeaderboardRepository(
          box,
          firebaseEnabled: true,
          remote: _FakeRemote(failRead: true),
        );

        final result = await repository.globalScores('classic');

        expect(result.source, LeaderboardSource.localFallback);
        expect(result.scores.single.name, 'Classic');
        expect(result.message, contains('Global scores unavailable'));
      },
    );

    test('keeps local save when remote write fails', () async {
      final box = _MemoryBox([]);
      final repository = LeaderboardRepository(
        box,
        firebaseEnabled: true,
        remote: _FakeRemote(failWrite: true),
      );

      final result = await repository.submit(
        120,
        'rising',
        nickname: '  Player\n One  ',
      );

      expect(result.savedLocally, isTrue);
      expect(result.syncedRemotely, isFalse);
      expect(box.values.single['name'], 'Player One');
      expect(result.message, contains('cloud sync failed'));
    });

    test('rejects invalid modes and implausible scores', () async {
      final repository = LeaderboardRepository(
        _MemoryBox([]),
        firebaseEnabled: false,
      );

      expect(() => repository.globalScores('unknown'), throwsArgumentError);
      expect(
        () => repository.submit(maxAcceptedScore + 1, 'classic'),
        throwsArgumentError,
      );
    });

    test('skips malformed remote records without discarding valid records', () {
      final scores = parseLeaderboardEntries([
        {
          'name': 'Remote player',
          'score': 125.0,
          'mode': 'classic',
          'createdAt': '2026-08-14T12:00:00.000Z',
        },
        {'name': 'Fractional score', 'score': 12.5, 'mode': 'classic'},
        {'name': '   ', 'score': 99, 'mode': 'classic'},
        {'name': 'Bad mode', 'score': 99, 'mode': 'unknown'},
        {'name': 'Bad date', 'score': 99, 'mode': 'classic', 'createdAt': 42},
      ]);

      expect(scores, hasLength(1));
      expect(scores.single.name, 'Remote player');
      expect(scores.single.score, 125);
    });
  });
}

class _FakeRemote implements RemoteLeaderboardDataSource {
  _FakeRemote({this.failRead = false, this.failWrite = false});

  final bool failRead;
  final bool failWrite;

  @override
  Future<List<ScoreEntry>> fetchScores(String mode) async {
    if (failRead) throw Exception('offline');
    return [ScoreEntry(name: 'Global', score: 100, mode: mode)];
  }

  @override
  Future<void> submit(ScoreEntry entry) async {
    if (failWrite) throw Exception('offline');
  }
}

class _MemoryBox extends Fake implements Box<dynamic> {
  _MemoryBox(List<Map<String, Object>> seed)
    : _values = seed.map<Map<dynamic, dynamic>>((item) => item).toList();

  final List<Map<dynamic, dynamic>> _values;

  @override
  Iterable<dynamic> get values => _values;

  @override
  Future<int> add(dynamic value) async {
    _values.add(Map<dynamic, dynamic>.from(value as Map));
    return _values.length - 1;
  }
}
