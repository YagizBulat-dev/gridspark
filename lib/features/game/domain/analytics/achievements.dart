import 'game_analytics.dart';
import 'game_session.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
}

const achievements = <Achievement>[
  Achievement(
    id: 'first_game',
    title: 'İlk Kıvılcım',
    description: 'İlk oyununu tamamla',
    iconName: 'spark',
  ),
  Achievement(
    id: 'ten_games',
    title: 'Arcade Alışkanlığı',
    description: '10 oyun oyna',
    iconName: 'repeat',
  ),
  Achievement(
    id: 'score_1k',
    title: 'Bin Puan',
    description: 'Tek oyunda 1000 puan yap',
    iconName: 'star',
  ),
  Achievement(
    id: 'line_master',
    title: 'Satır Ustası',
    description: 'Tek oyunda 8 satır temizle',
    iconName: 'grid',
  ),
  Achievement(
    id: 'combo_master',
    title: 'Combo Kralı',
    description: '5x seri yakala',
    iconName: 'bolt',
  ),
  Achievement(
    id: 'streak_3',
    title: 'Üç Gün Üst Üste',
    description: '3 günlük günlük seri yap',
    iconName: 'calendar',
  ),
  Achievement(
    id: 'replay_veteran',
    title: 'Bir Kez Daha',
    description: '8 oyunun en az çeyreğini yeniden oyna',
    iconName: 'replay',
  ),
  Achievement(
    id: 'marathon',
    title: 'Maraton',
    description: 'Tek oyunda 50 hamle yap',
    iconName: 'timer',
  ),
];

/// Pure evaluation of which achievements a finished session unlocks.
class AchievementEvaluator {
  const AchievementEvaluator();

  Set<String> evaluate({
    required GameSession session,
    required PlayerAnalytics stats,
    required int dailyStreak,
    required Set<String> alreadyUnlocked,
  }) {
    final earned = <String>{
      if (stats.totalGames >= 1) 'first_game',
      if (stats.totalGames >= 10) 'ten_games',
      if (session.score >= 1000) 'score_1k',
      if (session.linesCleared >= 8) 'line_master',
      if (session.maxStreak >= 5) 'combo_master',
      if (dailyStreak >= 3) 'streak_3',
      if (stats.totalGames >= 8 && stats.replayRate >= 0.25) 'replay_veteran',
      if (session.moves >= 50) 'marathon',
    };
    return earned.difference(alreadyUnlocked);
  }
}

Achievement? achievementById(String id) =>
    achievements.where((a) => a.id == id).firstOrNull;
