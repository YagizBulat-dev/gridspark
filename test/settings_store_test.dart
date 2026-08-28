import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/settings/data/settings_store.dart';
import 'package:hive/hive.dart';

void main() {
  test('corrupt persisted bool values use type-safe defaults', () {
    final store = SettingsStore(
      _MemoryBox({
        'darkMode': 'yes',
        'sound': 1,
        'haptics': null,
        'reduceMotion': true,
      }),
    );

    expect(store.darkMode, isTrue);
    expect(store.sound, isTrue);
    expect(store.haptics, isTrue);
    expect(store.reduceMotion, isTrue);
  });

  test(
    'serializes rapid writes and exposes state only after persistence',
    () async {
      final box = _BlockingBox();
      final store = SettingsStore(box);

      final first = store.setSound(false);
      final second = store.setSound(true);
      await Future<void>.delayed(Duration.zero);
      expect(box.startedValues, [false]);
      expect(store.sound, isTrue);

      box.releaseFirst.complete();
      await Future.wait([first, second]);

      expect(box.startedValues, [false, true]);
      expect(store.sound, isTrue);
      expect(box.valuesByKey['sound'], isTrue);
    },
  );

  test('failed persistence leaves observable state unchanged', () async {
    final box = _FailingBox();
    final store = SettingsStore(box);

    await expectLater(store.setDarkMode(false), throwsStateError);

    expect(store.darkMode, isTrue);
    expect(box.valuesByKey['darkMode'], isNull);
  });

  test('a failed write does not poison later settings writes', () async {
    final box = _FailOnceBox();
    final store = SettingsStore(box);

    await expectLater(store.setSound(false), throwsStateError);
    await store.setSound(false);

    expect(store.sound, isFalse);
    expect(box.valuesByKey['sound'], isFalse);
  });

  test('music setting defaults to enabled', () {
    final store = SettingsStore(_MemoryBox({}));
    expect(store.music, isTrue);
  });

  test('setMusic persists value', () async {
    final box = _MemoryBox({});
    final store = SettingsStore(box);
    await store.setMusic(false);
    expect(store.music, isFalse);
    expect(box.valuesByKey['music'], isFalse);
  });
}

class _MemoryBox extends Fake implements Box<dynamic> {
  _MemoryBox(this.valuesByKey);
  final Map<String, dynamic> valuesByKey;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      valuesByKey[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    valuesByKey[key as String] = value;
  }
}

class _BlockingBox extends _MemoryBox {
  _BlockingBox() : super({});
  final releaseFirst = Completer<void>();
  final startedValues = <bool>[];

  @override
  Future<void> put(dynamic key, dynamic value) async {
    startedValues.add(value as bool);
    if (startedValues.length == 1) await releaseFirst.future;
    await super.put(key, value);
  }
}

class _FailingBox extends _MemoryBox {
  _FailingBox() : super({});

  @override
  Future<void> put(dynamic key, dynamic value) async {
    throw StateError('disk full');
  }
}

class _FailOnceBox extends _MemoryBox {
  _FailOnceBox() : super({});
  bool fail = true;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (fail) {
      fail = false;
      throw StateError('disk full');
    }
    await super.put(key, value);
  }
}
