import 'package:hive/hive.dart';

import 'leaderboard_repository.dart';

class HighScoreBox {
  HighScoreBox(this._box);
  final Box<dynamic> _box;

  List<ScoreEntry> get all => parseLeaderboardEntries(
    _box.values.whereType<Map>().map((v) => Map<dynamic, dynamic>.from(v)),
  );

  List<ScoreEntry> getForMode(String mode) =>
      all.where((e) => e.mode == mode).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  Future<void> add(ScoreEntry entry) => _box.add({
    'name': entry.name,
    'score': entry.score,
    'mode': entry.mode,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });

  Future<void> clearAll() => _box.clear();
}
