import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore(this.box)
    : darkModeObservable = Observable(_readBool(box, 'darkMode', true)),
      soundObservable = Observable(_readBool(box, 'sound', true)),
      hapticsObservable = Observable(_readBool(box, 'haptics', true)),
      reduceMotionObservable = Observable(
        _readBool(box, 'reduceMotion', false),
      ),
      musicObservable = Observable(_readBool(box, 'music', true));
  final Box<dynamic> box;
  final Observable<bool> darkModeObservable;
  final Observable<bool> soundObservable;
  final Observable<bool> hapticsObservable;
  final Observable<bool> reduceMotionObservable;
  final Observable<bool> musicObservable;
  Future<void> _writeChain = Future<void>.value();
  bool get darkMode => darkModeObservable.value;
  bool get sound => soundObservable.value;
  bool get haptics => hapticsObservable.value;
  bool get reduceMotion => reduceMotionObservable.value;
  bool get music => musicObservable.value;

  Future<void> setDarkMode(bool value) =>
      _set('darkMode', value, darkModeObservable);

  Future<void> setSound(bool value) => _set('sound', value, soundObservable);

  Future<void> setHaptics(bool value) =>
      _set('haptics', value, hapticsObservable);

  Future<void> setReduceMotion(bool value) =>
      _set('reduceMotion', value, reduceMotionObservable);

  Future<void> setMusic(bool value) => _set('music', value, musicObservable);

  Future<void> _set(String key, bool value, Observable<bool> observable) {
    final operation = _writeChain.catchError((_) {}).then((_) async {
      await box.put(key, value);
      runInAction(() => observable.value = value);
      notifyListeners();
    });
    _writeChain = operation;
    return operation;
  }

  static bool _readBool(Box<dynamic> box, String key, bool fallback) {
    final value = box.get(key);
    return value is bool ? value : fallback;
  }
}
