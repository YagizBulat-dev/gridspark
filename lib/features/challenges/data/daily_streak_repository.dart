import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class DailyStreakInfo {
  const DailyStreakInfo({
    required this.current,
    required this.best,
    required this.lastDay,
  });

  final int current;
  final int best;
  final String? lastDay;
  bool get playedToday => lastDay == dayKey(DateTime.now());

  static String dayKey(DateTime date) {
    final d = date.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

abstract interface class DailyStreakStore {
  Object? get(String key);
  Future<void> put(String key, Object value);
}

class HiveDailyStreakStore implements DailyStreakStore {
  HiveDailyStreakStore(this._box);
  final Box<dynamic> _box;

  @override
  Object? get(String key) => _box.get(key);

  @override
  Future<void> put(String key, Object value) => _box.put(key, value);
}

class MemoryDailyStreakStore implements DailyStreakStore {
  final Map<String, Object> _values = {};

  @override
  Object? get(String key) => _values[key];

  @override
  Future<void> put(String key, Object value) async => _values[key] = value;
}

/// Tracks consecutive days with at least one finished game.
class DailyStreakRepository extends ChangeNotifier {
  DailyStreakRepository(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DailyStreakStore _store;
  final DateTime Function() _clock;
  static const _key = 'dailyStreak';

  DailyStreakInfo get info {
    final raw = _store.get(_key);
    if (raw is! Map) {
      return const DailyStreakInfo(current: 0, best: 0, lastDay: null);
    }
    final current = (raw['current'] as num?)?.toInt() ?? 0;
    final best = (raw['best'] as num?)?.toInt() ?? 0;
    final last = raw['lastDay'] as String?;
    return DailyStreakInfo(current: current, best: best, lastDay: last);
  }

  int get current => info.current;
  int get best => info.best;

  Future<void> recordPlay() async {
    final day = DailyStreakInfo.dayKey(_clock());
    final previous = info;
    if (previous.lastDay == day) return;

    final yesterday = DailyStreakInfo.dayKey(
      _clock().subtract(const Duration(days: 1)),
    );
    final next = previous.lastDay == yesterday ? previous.current + 1 : 1;
    final best = next > previous.best ? next : previous.best;
    await _store.put(_key, {'current': next, 'best': best, 'lastDay': day});
    notifyListeners();
  }
}

/// In-memory version for tests / analytics-disabled builds.
class InMemoryDailyStreakRepository extends DailyStreakRepository {
  InMemoryDailyStreakRepository({super.clock})
      : super(MemoryDailyStreakStore());
}
