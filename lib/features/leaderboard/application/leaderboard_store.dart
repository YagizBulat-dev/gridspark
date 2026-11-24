import 'package:mobx/mobx.dart';

import '../data/leaderboard_repository.dart';

class LeaderboardStore {
  LeaderboardStore(this.repository) {
    refreshLocal();
    refreshGlobal();
    refreshWeekly();
  }

  final LeaderboardRepository repository;
  final localScores = ObservableList<ScoreEntry>();
  final globalScores = ObservableList<ScoreEntry>();
  final weeklyScores = ObservableList<ScoreEntry>();
  final selectedMode = Observable('classic');
  final isLoadingGlobal = Observable(false);
  final globalMessage = Observable<String?>(null);
  final globalIsFallback = Observable(false);
  bool _disposed = false;
  int _refreshGeneration = 0;

  void setMode(String mode) {
    if (_disposed) return;
    if (selectedMode.value == mode) return;
    runInAction(() => selectedMode.value = mode);
    refreshLocal();
    refreshGlobal();
    refreshWeekly();
  }

  void refreshLocal() {
    if (_disposed) return;
    runInAction(() {
      localScores
        ..clear()
        ..addAll(repository.localScores(mode: selectedMode.value));
    });
  }

  void refreshWeekly() {
    if (_disposed) return;
    runInAction(() {
      weeklyScores
        ..clear()
        ..addAll(repository.weeklyLocalScores(mode: selectedMode.value));
    });
  }

  Future<void> refreshGlobal() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    final requestedMode = selectedMode.value;
    runInAction(() {
      isLoadingGlobal.value = true;
      globalMessage.value = null;
    });
    LeaderboardLoadResult result;
    try {
      result = await repository.globalScores(requestedMode);
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      runInAction(() {
        isLoadingGlobal.value = false;
        globalMessage.value = 'Scores could not be loaded.';
      });
      return;
    }
    if (_disposed ||
        generation != _refreshGeneration ||
        requestedMode != selectedMode.value) {
      return;
    }
    runInAction(() {
      globalScores
        ..clear()
        ..addAll(result.scores);
      globalIsFallback.value = result.source == LeaderboardSource.localFallback;
      globalMessage.value = result.message;
      isLoadingGlobal.value = false;
    });
  }

  void dispose() {
    _disposed = true;
    _refreshGeneration++;
  }
}
