import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:gridspark/features/leaderboard/data/leaderboard_repository.dart';
import 'package:gridspark/features/settings/data/settings_store.dart';

class _FakeMemoryBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<int> add(dynamic value) async {
    final key = _map.length;
    _map[key] = value;
    return key;
  }

  @override
  Iterable<dynamic> get values => _map.values;

  @override
  Iterable<dynamic> get keys => _map.keys;
}

void main() {
  group('Nickname Sanitization', () {
    test('sanitizes empty or whitespace-only nicknames to Player', () {
      expect(sanitizeNickname(''), 'Player');
      expect(sanitizeNickname('   '), 'Player');
      expect(sanitizeNickname('\t\n'), 'Player');
    });

    test('collapses consecutive spaces and strips control chars', () {
      expect(sanitizeNickname('Spark  Master'), 'Spark Master');
      expect(sanitizeNickname('Pro\u0000Gamer\u001F'), 'ProGamer');
    });

    test('truncates nicknames longer than 24 characters', () {
      const longName = 'SuperUltraMegaBlockBlastChampionPlayer';
      final sanitized = sanitizeNickname(longName);
      expect(sanitized.length, 24);
      expect(sanitized, longName.substring(0, 24));
    });
  });

  group('Leaderboard Score Parsing & Validation', () {
    test('parses valid entries correctly', () {
      final raw = [
        {
          'name': 'Yagiz',
          'score': 15000,
          'mode': 'classic',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Corrupt',
          'score': -50, // invalid score
          'mode': 'classic',
        },
        {
          'name': 'ValidTimed',
          'score': 9200,
          'mode': 'timed',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'ValidRising',
          'score': 12400,
          'mode': 'rising',
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];

      final entries = parseLeaderboardEntries(raw);
      expect(entries.length, 3);
      expect(entries[0].name, 'Yagiz');
      expect(entries[0].score, 15000);
      expect(entries[1].name, 'ValidTimed');
      expect(entries[2].name, 'ValidRising');
    });
  });

  group('SettingsStore', () {
    test('initializes with default values and persists changes', () async {
      final box = _FakeMemoryBox();
      final store = SettingsStore(box);

      expect(store.darkMode, true);
      expect(store.sound, true);
      expect(store.music, true);
      expect(store.haptics, true);
      expect(store.reduceMotion, false);

      await store.setSound(false);
      expect(store.sound, false);
      expect(box.get('sound'), false);

      await store.setHaptics(false);
      expect(store.haptics, false);
      expect(box.get('haptics'), false);

      await store.setDarkMode(false);
      expect(store.darkMode, false);
      expect(box.get('darkMode'), false);
    });
  });
}
