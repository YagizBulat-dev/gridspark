import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/challenges/data/daily_challenge_repository.dart';
import 'package:gridspark/features/challenges/data/daily_streak_repository.dart';
import 'package:gridspark/features/game/data/achievement_repository.dart';
import 'package:gridspark/features/game/domain/analytics/achievements.dart';
import 'package:gridspark/features/game/domain/analytics/game_analytics.dart';
import 'package:gridspark/features/game/domain/analytics/game_session.dart';
import 'package:gridspark/features/game/domain/game_models.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:hive/hive.dart';

class _FakeBox extends Fake implements Box<dynamic> {
  _FakeBox([Iterable<Map<String, Object>> seed = const []]) {
    _list.addAll(seed.map(Map<dynamic, dynamic>.from));
  }

  final Map<dynamic, dynamic> _map = {};
  final List<Map<dynamic, dynamic>> _list = [];

  @override
  Object? get(dynamic key, {Object? defaultValue}) => _map[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
    if (value is Map) _list.add(Map<dynamic, dynamic>.from(value));
  }

  @override
  Iterable<dynamic> get values => _list;
}

GameSession session({
  DateTime? startedAt,
  int score = 1200,
  int moves = 30,
  int lines = 9,
  int streak = 5,
  bool replay = false,
}) {
  final at = startedAt ?? DateTime(2026, 1, 5, 10);
  return GameSession(
    mode: GameMode.classic,
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 2)),
    score: score,
    moves: moves,
    linesCleared: lines,
    comboCount: 3,
    maxStreak: streak,
    fatalShapeId: 'rect2x3',
    endReason: GameEndReason.boardFull,
    wasReplay: replay,
  );
}

void main() {
  group('DailyStreakRepository', () {
    test('builds consecutive-day streaks and keeps the best', () async {
      var now = DateTime(2026, 1, 1, 12);
      final repo = InMemoryDailyStreakRepository(clock: () => now);
      await repo.recordPlay();
      expect(repo.current, 1);

      now = DateTime(2026, 1, 2, 9);
      await repo.recordPlay();
      expect(repo.current, 2);

      // Same day is a no-op.
      now = DateTime(2026, 1, 2, 20);
      await repo.recordPlay();
      expect(repo.current, 2);

      // Missed a day resets to 1 but best is preserved.
      now = DateTime(2026, 1, 4, 9);
      await repo.recordPlay();
      expect(repo.current, 1);
      expect(repo.best, 2);
    });
  });

  group('DailyChallengeRepository', () {
    test('daily score race keeps the best score of the day', () async {
      var now = DateTime(2026, 3, 10, 12);
      final repo = DailyChallengeRepository(
        _FakeBox(),
        clock: () => now,
      );
      await repo.recordDailyScore(500);
      await repo.recordDailyScore(900);
      await repo.recordDailyScore(300);
      final race = repo.challenges.firstWhere(
        (c) => c.type == DailyChallengeType.dailyScore,
      );
      expect(race.progress, 900);
      expect(race.target, greaterThan(0));
    });
  });

  group('Achievements', () {
    test('evaluates exactly the newly earned achievements', () async {
      final s = session();
      final stats = const GameAnalyticsEngine().summarize([
        s,
        ...List.generate(
          9,
          (i) => session(
            startedAt: DateTime(2026, 1, 6 + i),
            score: 10,
            lines: 0,
            streak: 0,
          ),
        ),
      ]);
      final evaluator = const AchievementEvaluator();
      final earned = evaluator.evaluate(
        session: s,
        stats: stats,
        dailyStreak: 3,
        alreadyUnlocked: const {'first_game'},
      );
      expect(earned, isNot(contains('first_game')));
      expect(earned, containsAll(['score_1k', 'line_master', 'combo_master', 'streak_3', 'ten_games']));

      final repo = InMemoryAchievementRepository();
      final unlocked = await repo.evaluateAndUnlock(
        session: s,
        stats: stats,
        dailyStreak: 3,
      );
      expect(unlocked, isNotEmpty);
      expect(repo.unlocked, contains('score_1k'));
      final second = await repo.evaluateAndUnlock(
        session: s,
        stats: stats,
        dailyStreak: 3,
      );
      expect(second, isEmpty);
    });
  });

  group('Weekly leaderboard', () {
    test('only includes scores from the current week', () {
      final now = DateTime.now().toLocal();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
      final thisWeek = weekStart.add(const Duration(hours: 2)).toUtc().toIso8601String();
      final lastWeek = weekStart
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final repo = LeaderboardRepository(
        _FakeBox([
          {'name': 'A', 'score': 100, 'mode': 'classic', 'createdAt': thisWeek},
          {'name': 'B', 'score': 300, 'mode': 'classic', 'createdAt': lastWeek},
          {'name': 'C', 'score': 200, 'mode': 'timed', 'createdAt': thisWeek},
        ]),
        firebaseEnabled: false,
      );
      final weekly = repo.weeklyLocalScores(mode: 'classic');
      expect(weekly.map((e) => e.name), ['A']);
      expect(repo.weeklyLocalScores().map((e) => e.name), ['C', 'A']);
    });
  });
}
