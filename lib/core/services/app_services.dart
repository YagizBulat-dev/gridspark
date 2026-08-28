import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/leaderboard/data/leaderboard_repository.dart';
import '../../features/game/data/game_snapshot_repository.dart';
import '../../features/settings/data/settings_store.dart';
import '../../features/challenges/data/daily_challenge_repository.dart';
import 'audio_service.dart';
import 'share_service.dart';

class AppServices {
  AppServices({
    required this.settings,
    required this.leaderboard,
    required this.firebaseAvailable,
    required this.gameSnapshots,
    required this.dailyChallenges,
    required this.share,
    required this.audio,
  });

  final SettingsStore settings;
  final LeaderboardRepository leaderboard;
  final bool firebaseAvailable;
  final GameSnapshotRepository gameSnapshots;
  final DailyChallengeRepository dailyChallenges;
  final ShareService share;
  final AudioService audio;

  static Future<AppServices> bootstrap() async {
    await Hive.initFlutter();
    final settingsBox = await Hive.openBox<dynamic>('settings');
    final scoresBox = await Hive.openBox<dynamic>('scores');
    final gameStateBox = await Hive.openBox<dynamic>('game_state');
    final challengesBox = await Hive.openBox<dynamic>('daily_challenges');
    var firebaseReady = false;
    try {
      await Firebase.initializeApp();
      await FirebaseAuth.instance.signInAnonymously();
      firebaseReady = true;
    } catch (_) {
      // Firebase is optional until platform configuration files are supplied.
    }
    final settings = SettingsStore(settingsBox);
    final audio = AudioService(settings);
    await audio.init();
    return AppServices(
      settings: settings,
      leaderboard: LeaderboardRepository(
        scoresBox,
        firebaseEnabled: firebaseReady,
        remote: firebaseReady ? FirestoreLeaderboardDataSource() : null,
      ),
      firebaseAvailable: firebaseReady,
      gameSnapshots: HiveGameSnapshotRepository(gameStateBox),
      dailyChallenges: DailyChallengeRepository(challengesBox),
      share: NativeShareService(),
      audio: audio,
    );
  }
}
