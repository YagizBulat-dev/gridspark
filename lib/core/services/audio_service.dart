import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../features/settings/data/settings_store.dart';

enum Sfx {
  place,
  invalid,
  clear,
  combo,
  trayRefill,
  gameOver,
  buttonClick,
  achievement,
}

enum MusicTrack { menu, classic, timed, rising }

class AudioService {
  AudioService(this.settings);
  final SettingsStore settings;

  // SFX pool — 3 players so rapid sounds (e.g. combo clears) don't cut each other
  final List<AudioPlayer> _sfxPlayers = [];
  static const int _sfxPoolSize = 3;

  // Music
  AudioPlayer? _musicPlayer;
  MusicTrack? _currentTrack;
  MusicTrack? _pendingTrack;

  bool _initialized = false;

  Future<void> init() async {
    // Pre-create SFX players
    for (var i = 0; i < _sfxPoolSize; i++) {
      _sfxPlayers.add(AudioPlayer());
    }
    _initialized = true;
    settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!settings.music && _musicPlayer != null) {
      _musicPlayer!.stop();
      _musicPlayer!.dispose();
      _musicPlayer = null;
    } else if (settings.music &&
        _musicPlayer == null &&
        _pendingTrack != null) {
      playMusic(_pendingTrack!);
      _pendingTrack = null;
    }
  }

  AudioPlayer? _acquireSfxPlayer() {
    for (final p in _sfxPlayers) {
      if (p.state != PlayerState.playing) return p;
    }
    return _sfxPlayers.first; // all busy, interrupt the oldest
  }

  Future<void> playSfx(Sfx sfx, {double pitch = 1.0}) async {
    if (!settings.sound || !_initialized) return;
    final player = _acquireSfxPlayer();
    if (player == null) return;
    final path = _sfxAssetPath(sfx);
    try {
      if (pitch != 1.0) {
        await player.setPlaybackRate(pitch);
      }
      await player.play(AssetSource(path));
    } catch (e) {
      // Log decode/load failures in debug builds. Assets are generated PCM
      // WAV files, so a failure here means a missing or corrupted bundle.
      assert(() {
        debugPrint('AudioService.playSfx failed: $sfx\nError: $e');
        return true;
      }());
    }
  }

  Future<void> playMusic(MusicTrack track) async {
    if (!settings.music) {
      _pendingTrack = track;
      return;
    }
    if (_currentTrack == track && _musicPlayer != null) return;

    // Stop current
    if (_musicPlayer != null) {
      await _musicPlayer!.stop();
      await _musicPlayer!.dispose();
    }

    _musicPlayer = AudioPlayer();
    _currentTrack = track;
    try {
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.play(AssetSource(_musicAssetPath(track)));
    } catch (e) {
      // Log decode/load failures in debug builds. Assets are generated PCM
      // WAV files, so a failure here means a missing or corrupted bundle.
      assert(() {
        debugPrint('AudioService.playMusic failed: $track\nError: $e');
        return true;
      }());
    }
  }

  void dispose() {
    settings.removeListener(_onSettingsChanged);
    for (final p in _sfxPlayers) {
      p.dispose();
    }
    _musicPlayer?.dispose();
  }
}

String _sfxAssetPath(Sfx sfx) => switch (sfx) {
  Sfx.place => 'sounds/sfx/place.wav',
  Sfx.invalid => 'sounds/sfx/invalid.wav',
  Sfx.clear => 'sounds/sfx/clear.wav',
  Sfx.combo => 'sounds/sfx/combo.wav',
  Sfx.trayRefill => 'sounds/sfx/tray_refill.wav',
  Sfx.gameOver => 'sounds/sfx/game_over.wav',
  Sfx.buttonClick => 'sounds/sfx/button_click.wav',
  Sfx.achievement => 'sounds/sfx/achievement.wav',
};

String _musicAssetPath(MusicTrack track) => switch (track) {
  MusicTrack.menu => 'sounds/music/menu.wav',
  MusicTrack.classic => 'sounds/music/classic.wav',
  MusicTrack.timed => 'sounds/music/timed.wav',
  MusicTrack.rising => 'sounds/music/rising.wav',
};
