import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/arcade_widgets.dart';
import '../../game/domain/game_models.dart';
import '../../game/presentation/game_screen.dart';
import '../../challenges/data/daily_challenge_repository.dart';
import 'app_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late AppServices services;
  final Set<DailyChallengeType> _completedChallenges = {};

  @override
  void initState() {
    super.initState();
    services = widget.services;
    WidgetsBinding.instance.addObserver(this);
    services.dailyChallenges.refreshToday();
    services.audio.playMusic(MusicTrack.menu);
    _initCompletedChallenges();
    services.dailyChallenges.addListener(_onChallengeUpdated);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      services.dailyChallenges.refreshToday();
    }
  }

  void _initCompletedChallenges() {
    for (final ch in services.dailyChallenges.challenges) {
      if (ch.complete) _completedChallenges.add(ch.type);
    }
  }

  void _onChallengeUpdated() {
    for (final challenge in services.dailyChallenges.challenges) {
      if (challenge.complete &&
          !_completedChallenges.contains(challenge.type)) {
        _completedChallenges.add(challenge.type);
        services.audio.playSfx(Sfx.achievement);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    services.dailyChallenges.removeListener(_onChallengeUpdated);
    super.dispose();
  }

  int _best(GameMode mode) =>
      services.leaderboard.localScores(mode: mode.name).firstOrNull?.score ?? 0;

  @override
  Widget build(BuildContext context) {
    final bests = {for (final m in GameMode.values) m: _best(m)};
    final overall = bests.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: ArcadeNavBar(
        services: services,
        current: AppTab.home,
      ),
      body: ArcadeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ArcadeHeader(subtitle: 'Ana Menü'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _BestScoreCard(score: overall),
                    const SizedBox(height: 16),
                    JuicyButton(
                      label: 'Hemen Oyna',
                      icon: Icons.play_arrow_rounded,
                      height: 64,
                      onPressed: () => _play(context, GameMode.classic),
                    ),
                    const SizedBox(height: 16),
                    ListenableBuilder(
                      listenable: services.dailyChallenges,
                      builder: (_, _) => _DailyQuestCard(
                        challenges: services.dailyChallenges.challenges,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(
                      'Oyun Modları',
                      icon: Icons.sports_esports_rounded,
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.all_inclusive_rounded,
                      color: AppColors.cyan,
                      title: 'Klasik Mod',
                      badge: 'SONSUZ',
                      description: 'Süresiz, stratejik rahatlama. Hamle kalmayana kadar blokları yerleştir.',
                      best: bests[GameMode.classic]!,
                      onTap: () => _play(context, GameMode.classic),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.timer_outlined,
                      color: AppColors.amber,
                      title: 'Time Attack',
                      badge: '02:00',
                      description: '2 dakikaya karşı yarış! Hızlı kombolarla en yüksek skoru yap.',
                      best: bests[GameMode.timed]!,
                      onTap: () => _play(context, GameMode.timed),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.trending_up_rounded,
                      color: AppColors.violet,
                      title: 'Zorlaşan Izgara',
                      badge: 'UZMAN',
                      description: 'Skor yükseldikçe zorluk artar. Yüksek risk, devasa kıvılcım.',
                      best: bests[GameMode.rising]!,
                      onTap: () => _play(context, GameMode.rising),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context, GameMode mode) {
    services.audio.playSfx(Sfx.buttonClick);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(mode: mode, services: services),
      ),
    ).then((_) {
      // Returning from game: refresh bests and restart menu music.
      if (mounted) setState(() {});
      services.audio.playMusic(MusicTrack.menu);
    });
  }
}

String _fmt(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

class _BestScoreCard extends StatelessWidget {
  const _BestScoreCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: AppColors.violet,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            'Kişisel Rekor',
            icon: Icons.star_outline_rounded,
            color: AppColors.amber,
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(score),
            style: AppTheme.sora(
              48,
              weight: FontWeight.w800,
              color: AppColors.cyan,
              letterSpacing: -0.96,
              height: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DailyQuestCard extends StatelessWidget {
  const _DailyQuestCard({required this.challenges});
  final List<DailyChallenge> challenges;

  static String _title(DailyChallenge c) => switch (c.type) {
    DailyChallengeType.lines => '${c.target} satır temizle',
    DailyChallengeType.moves => '${c.target} blok yerleştir',
    DailyChallengeType.timedScore => "Time Attack'te ${c.target} puan yap",
  };

  @override
  Widget build(BuildContext context) {
    final done = challenges.where((c) => c.complete).length;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionLabel(
                  'Günün Görevleri',
                  icon: Icons.flag_rounded,
                  color: AppColors.amber,
                ),
              ),
              StatPill(
                text: '$done/${challenges.length}',
                color: AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final c in challenges)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title(c),
                          style: AppTheme.jakarta(
                            14,
                            weight: FontWeight.w600,
                            color: c.complete
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                      if (c.complete)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.cyan,
                        )
                      else
                        Text(
                          '${c.cappedProgress}/${c.target}',
                          style: AppTheme.grotesk(12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: c.fraction,
                      minHeight: 8,
                      backgroundColor: AppColors.canvas,
                      valueColor: AlwaysStoppedAnimation(
                        c.complete ? AppColors.cyan : AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.badge,
    required this.description,
    required this.best,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String badge;
  final String description;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. En yüksek skor ${_fmt(best)}',
    child: GlassPanel(
      onTap: onTap,
      glow: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.well,
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.sora(18, weight: FontWeight.w600),
                      ),
                    ),
                    StatPill(text: badge, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTheme.jakarta(
                    13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rekor ${_fmt(best)}',
                      style: AppTheme.grotesk(12, color: AppColors.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
