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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AppServices get services => widget.services;
  final Set<DailyChallengeType> _completedChallenges = {};

  @override
  void initState() {
    super.initState();
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
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background grid pattern (8×8)
            Positioned.fill(
              child: CustomPaint(painter: _GridPatternPainter(cs)),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 36),

                  // ── Logo: 4 colored blocks ──
                  const _ColoredBlocksLogo(),
                  const SizedBox(height: 18),

                  // ── Title: GRIDSPARK with gradient shader ──
                  _GradientTitle(textTheme: textTheme),
                  const SizedBox(height: 6),

                  // ── Slogan ──
                  Text(
                    'Place. Clear. Spark.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Daily Sparks ──
                  AnimatedBuilder(
                    animation: services.dailyChallenges,
                    builder: (context, _) => _DailyChallengesCard(
                      challenges: services.dailyChallenges.challenges,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Classic button (teal) ──
                  _GameModeButton(
                    color: _classicColor,
                    icon: Icons.play_arrow_rounded,
                    label: 'Classic',
                    onPressed: () => _play(context, GameMode.classic),
                  ),
                  const SizedBox(height: 14),

                  // ── Time Attack (orange) + Rising Difficulty (purple) ──
                  Row(
                    children: [
                      Expanded(
                        child: _GameModeButton(
                          color: _timedColor,
                          icon: Icons.timer_outlined,
                          label: 'Time Attack',
                          onPressed: () => _play(context, GameMode.timed),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _GameModeButton(
                          color: _risingColor,
                          icon: Icons.trending_up,
                          label: 'Rising Difficulty',
                          onPressed: () => _play(context, GameMode.rising),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ── Bottom icons: Trophy + Settings ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ThemedIconButton(
                        icon: Icons.emoji_events_outlined,
                        color: blockColors[5],
                        tooltip: 'Leaderboard',
                        onPressed: () {
                          services.audio.playSfx(Sfx.buttonClick);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LeaderboardScreen(services: services),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      _ThemedIconButton(
                        icon: Icons.settings_outlined,
                        color: _classicColor,
                        tooltip: 'Settings',
                        onPressed: () {
                          services.audio.playSfx(Sfx.buttonClick);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SettingsScreen(services: services),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Status text ──
                  Text(
                    services.firebaseAvailable
                        ? 'Online leaderboard connected'
                        : 'Playing offline',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
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

// ──────────────────────────────────────────────────────────────
// Color constants
// ──────────────────────────────────────────────────────────────

final _classicColor = blockColors[1]; // teal
final _timedColor = blockColors[2]; // orange
final _risingColor = blockColors[0]; // purple

// ──────────────────────────────────────────────────────────────
// Grid pattern painter (background)
// ──────────────────────────────────────────────────────────────

class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter(this._cs);
  final ColorScheme _cs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cs.onSurface.withValues(alpha: 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cols = 8;
    const rows = 12;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var c = 0; c <= cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter old) => false;
}

// ──────────────────────────────────────────────────────────────
// 4-block colored logo
// ──────────────────────────────────────────────────────────────

class _ColoredBlocksLogo extends StatelessWidget {
  const _ColoredBlocksLogo();

  @override
  Widget build(BuildContext context) {
    final colors = [
      blockColors[1],
      blockColors[2],
      blockColors[4],
      blockColors[0],
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < colors.length; i++) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: colors[i].withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          if (i < colors.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Gradient title
// ──────────────────────────────────────────────────────────────

class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.textTheme});
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          blockColors[1], // teal
          blockColors[2], // orange
          blockColors[4], // blue
          blockColors[0], // purple
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        'GRIDSPARK',
        textAlign: TextAlign.center,
        style: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: Colors.white, // ShaderMask needs non-transparent child
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Game mode button (colored, glow'd, rounded)
// ──────────────────────────────────────────────────────────────

class _GameModeButton extends StatelessWidget {
  const _GameModeButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        shadowColor: color.withValues(alpha: 0.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Themed icon button (trophy, settings)
// ──────────────────────────────────────────────────────────────

class _ThemedIconButton extends StatelessWidget {
  const _ThemedIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: color,
          minimumSize: const Size(52, 52),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Daily Sparks card (themed)
// ──────────────────────────────────────────────────────────────

class _DailyChallengesCard extends StatelessWidget {
  const _DailyChallengesCard({required this.challenges});

  final List<DailyChallenge> challenges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: blockColors[2], // orange
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DAILY SPARKS',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _classicColor, // teal
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Challenges
          for (var i = 0; i < challenges.length; i++) ...[
            _DailyChallengeTile(
              challenge: challenges[i],
              cs: cs,
              textTheme: textTheme,
            ),
            if (i < challenges.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Single challenge tile
// ──────────────────────────────────────────────────────────────

class _DailyChallengeTile extends StatelessWidget {
  const _DailyChallengeTile({
    required this.challenge,
    required this.cs,
    required this.textTheme,
  });

  final DailyChallenge challenge;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${challenge.cappedProgress}/${challenge.target}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (challenge.complete) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: blockColors[6], // green
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: challenge.fraction,
              minHeight: 4,
              color: _classicColor, // teal
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
