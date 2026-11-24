import 'package:hive/hive.dart';

import '../domain/analytics/achievements.dart';
import '../domain/analytics/game_analytics.dart';
import '../domain/analytics/game_session.dart';

abstract interface class AchievementStore {
  Object? get(String key);
  Future<void> put(String key, Object value);
}

class HiveAchievementStore implements AchievementStore {
  HiveAchievementStore(this._box);
  final Box<dynamic> _box;

  @override
  Object? get(String key) => _box.get(key);

  @override
  Future<void> put(String key, Object value) => _box.put(key, value);
}

class MemoryAchievementStore implements AchievementStore {
  final Map<String, Object> _values = {};

  @override
  Object? get(String key) => _values[key];

  @override
  Future<void> put(String key, Object value) async => _values[key] = value;
}

class AchievementRepository {
  AchievementRepository(this._store);

  final AchievementStore _store;
  static const _key = 'unlocked';
  final _evaluator = const AchievementEvaluator();

  Set<String> get unlocked {
    final raw = _store.get(_key);
    if (raw is! List) return const <String>{};
    return raw.whereType<String>().toSet();
  }

  Future<List<Achievement>> evaluateAndUnlock({
    required GameSession session,
    required PlayerAnalytics stats,
    required int dailyStreak,
  }) async {
    final newIds = _evaluator.evaluate(
      session: session,
      stats: stats,
      dailyStreak: dailyStreak,
      alreadyUnlocked: unlocked,
    );
    if (newIds.isEmpty) return const <Achievement>[];
    await _store.put(_key, <String>[...unlocked, ...newIds]);
    return achievements.where((a) => newIds.contains(a.id)).toList();
  }
}

class InMemoryAchievementRepository extends AchievementRepository {
  InMemoryAchievementRepository() : super(MemoryAchievementStore());
}
