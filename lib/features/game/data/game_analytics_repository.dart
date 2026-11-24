import 'package:hive/hive.dart';

import '../domain/analytics/game_analytics.dart';
import '../domain/analytics/game_session.dart';

abstract class GameAnalyticsRepository {
  Future<void> record(GameSession session);
  List<GameSession> loadAll();
  PlayerAnalytics currentStats();
  Future<PlayerAnalytics> stats();
  Future<void> clear();
}

/// Stores finished sessions in a single Hive box entry as JSON-compatible maps.
class HiveGameAnalyticsRepository implements GameAnalyticsRepository {
  HiveGameAnalyticsRepository(this._box);

  final Box<dynamic> _box;
  static const _sessionsKey = 'sessions';
  static const _maxSessions = 500;

  @override
  List<GameSession> loadAll() {
    final raw = _box.get(_sessionsKey);
    if (raw is! List) return const <GameSession>[];
    final result = <GameSession>[];
    for (final entry in raw) {
      if (entry is Map) {
        try {
          result.add(GameSession.fromJson(Map<String, Object?>.from(entry)));
        } catch (_) {
          // A single corrupt record must not hide the rest of the history.
        }
      }
    }
    return List.unmodifiable(result);
  }

  @override
  Future<void> record(GameSession session) async {
    final updated = <Object?>[
      ...loadAll().map((s) => s.toJson()),
      session.toJson(),
    ];
    if (updated.length > _maxSessions) {
      updated.removeRange(0, updated.length - _maxSessions);
    }
    await _box.put(_sessionsKey, updated);
  }

  @override
  PlayerAnalytics currentStats() =>
      const GameAnalyticsEngine().summarize(loadAll());

  @override
  Future<PlayerAnalytics> stats() async => currentStats();

  @override
  Future<void> clear() => _box.delete(_sessionsKey);
}

/// In-memory implementation for tests and offline/analytics-disabled builds.
class InMemoryGameAnalyticsRepository implements GameAnalyticsRepository {
  final List<GameSession> _sessions = <GameSession>[];

  @override
  Future<void> record(GameSession session) async => _sessions.add(session);

  @override
  List<GameSession> loadAll() => List.unmodifiable(_sessions);

  @override
  PlayerAnalytics currentStats() =>
      const GameAnalyticsEngine().summarize(_sessions);

  @override
  Future<PlayerAnalytics> stats() async => currentStats();

  @override
  Future<void> clear() async => _sessions.clear();
}
