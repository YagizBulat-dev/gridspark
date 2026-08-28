import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/leaderboard/data/high_score_box.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:hive/hive.dart';

void main() {
  group('HighScoreBox', () {
    test('adds and retrieves scores', () async {
      final box = _MemoryBox();
      final highScoreBox = HighScoreBox(box);

      await highScoreBox.add(
        const ScoreEntry(name: 'Alice', score: 100, mode: 'classic'),
      );
      await highScoreBox.add(
        const ScoreEntry(name: 'Bob', score: 200, mode: 'timed'),
      );

      expect(highScoreBox.all, hasLength(2));
    });

    test('filters scores by mode and sorts by score descending', () async {
      final box = _MemoryBox();
      final highScoreBox = HighScoreBox(box);

      await highScoreBox.add(
        const ScoreEntry(name: 'Alice', score: 100, mode: 'classic'),
      );
      await highScoreBox.add(
        const ScoreEntry(name: 'Bob', score: 300, mode: 'classic'),
      );
      await highScoreBox.add(
        const ScoreEntry(name: 'Charlie', score: 200, mode: 'timed'),
      );

      final classicScores = highScoreBox.getForMode('classic');
      expect(classicScores, hasLength(2));
      expect(classicScores[0].score, 300);
      expect(classicScores[0].name, 'Bob');
      expect(classicScores[1].score, 100);
      expect(classicScores[1].name, 'Alice');

      final timedScores = highScoreBox.getForMode('timed');
      expect(timedScores, hasLength(1));
      expect(timedScores[0].name, 'Charlie');
    });

    test('clearAll removes all scores', () async {
      final box = _MemoryBox();
      final highScoreBox = HighScoreBox(box);

      await highScoreBox.add(
        const ScoreEntry(name: 'Alice', score: 100, mode: 'classic'),
      );
      expect(highScoreBox.all, hasLength(1));

      await highScoreBox.clearAll();
      expect(highScoreBox.all, isEmpty);
    });

    test('returns empty list for mode with no scores', () {
      final box = _MemoryBox();
      final highScoreBox = HighScoreBox(box);
      expect(highScoreBox.getForMode('rising'), isEmpty);
    });
  });
}

class _MemoryBox extends Fake implements Box<dynamic> {
  final List<dynamic> _values = [];

  @override
  Iterable<dynamic> get values => _values;

  @override
  Future<int> add(dynamic value) async {
    _values.add(value);
    return _values.length - 1;
  }

  @override
  Future<int> clear() async {
    final count = _values.length;
    _values.clear();
    return count;
  }
}
