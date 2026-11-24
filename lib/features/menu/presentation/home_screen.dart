import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/services/audio_service.dart';
import '../../game/domain/game_models.dart';
import '../../game/presentation/game_screen.dart';
import '../../game/presentation/widgets/block_shape_view.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../challenges/data/daily_challenge_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Background glow accents
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top bar: logo + profile ──
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.grid_view,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GridSpark',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurface,
                                      fontFamily: 'PlusJakartaSans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Profile circle
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: cs.onPrimaryContainer,
                        child: const Icon(
                          Icons.person,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Score & modes row ──
                  Row(
                    children: [
                      // Highscore
                      Expanded(
                        child: Card(
                          color: cs.surfaceContainerHigh,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Rekor: 14,850',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Level
                      Expanded(
                        child: Card(
                          color: cs.surfaceContainerHigh,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: cs.tertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'L14',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // ── Game mode buttons ──
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ModeButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Classic',
                        subtitle: 'Endless — place until no moves left',
                        color: cs.primary,
                        onPressed: () => _play(context, GameMode.classic),
                      ),
                      _ModeButton(
                        icon: Icons.timer_outlined,
                        label: 'Time Attack',
                        subtitle: '2 min countdown',
                        color: cs.tertiary,
                        onPressed: () => _play(context, GameMode.timed),
                      ),
                      _ModeButton(
                        icon: Icons.trending_up,
                        label: 'Rising',
                        subtitle: 'Gets harder as you score',
                        color: cs.tertiary,
                        onPressed: () => _play(context, GameMode.rising),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Daily challenges ──
                  const SizedBox(height: 16),
                  Text(
                    'Daily Sparks',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DailyChallengesCard(
                    challenges: services.dailyChallenges.challenges,
                  ),
                  const SizedBox(height: 24),

                  // ── Bottom: Leaderboard + Settings ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NavIconButton(
                        icon: Icons.emoji_events_outlined,
                        label: 'Liderlik',
                        color: cs.tertiary,
                        onPressed: () {
                          services.audio.playSfx(Sfx.buttonClick);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeaderboardScreen(services: services),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      _NavIconButton(
                        icon: Icons.settings_outlined,
                        label: 'Ayarlar',
                        color: cs.onSurfaceVariant,
                        onPressed: () {
                          services.audio.playSfx(Sfx.buttonClick);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(services: services),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
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
      // Returning from game — restart menu music
      services.audio.playMusic(MusicTrack.menu);
    });
  }
}

// ── Widgets ──────────────────────────────────────────────────────

// Mode button
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Daily challenges card
class _DailyChallengesCard extends StatelessWidget {
  const _DailyChallengesCard({
    required this.challenges,
  });

  final List<DailyChallenge> challenges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = challenges.where((ch) => ch.complete).length;
    final total = challenges.length;

    return Card(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Progress circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Challenges list
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  challenges.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          index < completed
                              ? Icons.check_circle_outlined
                              : Icons.radio_button_off,
                          color: index < completed ? cs.primary : cs.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          challenges[index].type.toString().split('.').last,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Navigation icon button
class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}