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

  // One small pool of low-latency, pre-loaded players PER sound effect, so a
  // block placement, a clear and a tray refill can all fire at the same moment
  // without cutting each other off or re-loading the asset each time.
  final Map<Sfx, List<AudioPlayer>> _sfxPools = {};
  final Map<Sfx, int> _sfxNext = {};
  final Map<AudioPlayer, double> _sfxRate = {};
  static const int _playersPerSfx = 2;

  // Music
  AudioPlayer? _musicPlayer;
  MusicTrack? _currentTrack;
  MusicTrack? _pendingTrack;

  bool _initialized = false;

  Future<void> init() async {
    // Pre-create and pre-load SFX players (low latency, no reload per play).
    for (final sfx in Sfx.values) {
      final pool = <AudioPlayer>[];
      for (var i = 0; i < _playersPerSfx; i++) {
        try {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource(_sfxAssetPath(sfx)));
          pool.add(player);
        } catch (e) {
          assert(() {
            debugPrint('AudioService.init failed to preload $sfx: $e');
            return true;
          }());
        }
      }
      _sfxPools[sfx] = pool;
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

  AudioPlayer? _acquireSfxPlayer(Sfx sfx) {
    final pool = _sfxPools[sfx];
    if (pool == null || pool.isEmpty) return null;
    final i = (_sfxNext[sfx] ?? 0) % pool.length;
    _sfxNext[sfx] = i + 1;
    return pool[i]; // round-robin: a fast repeat uses the other player
  }

  Future<void> playSfx(Sfx sfx, {double pitch = 1.0}) async {
    if (!settings.sound || !_initialized) return;
    final player = _acquireSfxPlayer(sfx);
    if (player == null) return;
    try {
      // Always restore the rate: a pitched combo must not leave later sounds
      // permanently speeded up.
      if (_sfxRate[player] != pitch) {
        await player.setPlaybackRate(pitch);
        _sfxRate[player] = pitch;
      }
      await player.stop();
      await player.resume();
    } catch (e) {
      // Fall back to a plain (slower) play if the pre-loaded source failed.
      try {
        await player.play(AssetSource(_sfxAssetPath(sfx)));
      } catch (e2) {
        assert(() {
          debugPrint('AudioService.playSfx failed: $sfx\nError: $e2');
          return true;
        }());
      }
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
      // Keep the music well below the sound effects so clears stay punchy.
      await _musicPlayer!.setVolume(0.6);
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
    for (final pool in _sfxPools.values) {
      for (final p in pool) {
        p.dispose();
      }
    }
    _sfxPools.clear();
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
