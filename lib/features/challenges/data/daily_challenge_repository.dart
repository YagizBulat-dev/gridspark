import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../game/application/game_store.dart';
import '../../game/domain/game_models.dart';

enum DailyChallengeType { lines, moves, timedScore, dailyScore }

class DailyChallenge {
  const DailyChallenge({
    required this.type,
    required this.target,
    required this.progress,
  });

  final DailyChallengeType type;
  final int target;
  final int progress;

  int get cappedProgress => progress.clamp(0, target);
  bool get complete => progress >= target;
  double get fraction => target == 0 ? 1 : cappedProgress / target;

  String get title => switch (type) {
    DailyChallengeType.lines => 'Clear $target lines',
    DailyChallengeType.moves => 'Place $target pieces',
    DailyChallengeType.timedScore => 'Score $target in Timed',
    DailyChallengeType.dailyScore => 'Daily score race: $target',
  };
}

class DailyChallengeRepository extends ChangeNotifier {
  DailyChallengeRepository(this._box, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _ensureToday();
  }

  final Box<dynamic> _box;
  final DateTime Function() _clock;
  String _dayKey = '';
  Map<String, int> _progress = {};
  Future<void> _writeChain = Future<void>.value();

  List<DailyChallenge> get challenges {
    // UI entry points call refreshToday so a rollover is observable instead of
    // silently changing state from inside this getter.
    final seed = _seedFor(_dayKey);
    return [
      DailyChallenge(
        type: DailyChallengeType.lines,
        target: 4 + seed % 3,
        progress: _progress['lines'] ?? 0,
      ),
      DailyChallenge(
        type: DailyChallengeType.moves,
        target: 18 + seed % 8,
        progress: _progress['moves'] ?? 0,
      ),
      DailyChallenge(
        type: DailyChallengeType.timedScore,
        target: 700 + (seed % 5) * 100,
        progress: _progress['timedScore'] ?? 0,
      ),
      DailyChallenge(
        type: DailyChallengeType.dailyScore,
        target: 800 + (seed % 5) * 200,
        progress: _progress['dailyScore'] ?? 0,
      ),
    ];
  }

  Future<void> record(GameProgressEvent event) {
    final operation = _writeChain.catchError((_) {}).then((_) async {
      _ensureToday();
      final nextProgress = Map<String, int>.from(_progress);
      nextProgress['lines'] = (nextProgress['lines'] ?? 0) + event.linesCleared;
      nextProgress['moves'] = (nextProgress['moves'] ?? 0) + 1;
      if (event.mode == GameMode.timed &&
          event.score > (nextProgress['timedScore'] ?? 0)) {
        nextProgress['timedScore'] = event.score;
      }
      await _box.put('dailyChallenges', {
        'day': _dayKey,
        'progress': nextProgress,
      });
      _progress = nextProgress;
      notifyListeners();
    });
    _writeChain = operation;
    return operation;
  }

  /// Daily score race keeps the best score achieved today.
  Future<void> recordDailyScore(int score) {
    final operation = _writeChain.catchError((_) {}).then((_) async {
      _ensureToday();
      if (score <= (_progress['dailyScore'] ?? 0)) return;
      final nextProgress = Map<String, int>.from(_progress);
      nextProgress['dailyScore'] = score;
      await _box.put('dailyChallenges', {
        'day': _dayKey,
        'progress': nextProgress,
      });
      _progress = nextProgress;
      notifyListeners();
    });
    _writeChain = operation;
    return operation;
  }

  /// Reloads date-scoped state, notifying the Home UI when the local day rolls.
  bool refreshToday() {
    final changed = _ensureToday();
    if (changed) notifyListeners();
    return changed;
  }

  bool _ensureToday() {
    final now = _clock().toLocal();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (today == _dayKey) return false;
    _dayKey = today;
    _progress = {};
    final raw = _box.get('dailyChallenges');
    if (raw is Map && raw['day'] == today && raw['progress'] is Map) {
      for (final entry in (raw['progress'] as Map).entries) {
        if (entry.key is String && entry.value is int && entry.value >= 0) {
          _progress[entry.key as String] = entry.value as int;
        }
      }
    }
    return true;
  }

  static int _seedFor(String day) =>
      day.codeUnits.fold<int>(17, (value, unit) => value * 31 + unit).abs();
}
