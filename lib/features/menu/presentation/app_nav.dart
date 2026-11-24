import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/domain/game_models.dart';
import '../../game/presentation/game_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../stats/presentation/stats_screen.dart';
import 'home_screen.dart';

enum AppTab { home, play, leaderboard, stats, settings }

/// Bottom navigation shared by the menu, leaderboard and settings screens.
class ArcadeNavBar extends StatelessWidget {
  const ArcadeNavBar({
    super.key,
    required this.services,
    required this.current,
  });

  final AppServices services;
  final AppTab current;

  static const _items = [
    (AppTab.home, Icons.sports_esports_rounded, 'Ana Menü'),
    (AppTab.play, Icons.grid_view_rounded, 'Oyna'),
    (AppTab.leaderboard, Icons.emoji_events_rounded, 'Liderlik'),
    (AppTab.stats, Icons.bar_chart_rounded, 'İstatistik'),
    (AppTab.settings, Icons.settings_rounded, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.canvas.withValues(alpha: 0.96),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final item in _items)
              Expanded(
                child: _NavItem(
                  icon: item.$2,
                  label: item.$3,
                  selected: item.$1 == current,
                  onTap: () => _go(context, item.$1),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  void _go(BuildContext context, AppTab tab) {
    if (tab == current && tab != AppTab.play) return;
    services.audio.playSfx(Sfx.buttonClick);
    switch (tab) {
      case AppTab.play:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GameScreen(mode: GameMode.classic, services: services),
          ),
        ).then((_) => services.audio.playMusic(MusicTrack.menu));
      case AppTab.home:
        _replace(context, HomeScreen(services: services));
      case AppTab.leaderboard:
        _replace(context, LeaderboardScreen(services: services));
      case AppTab.stats:
        _replace(context, StatsScreen(services: services));
      case AppTab.settings:
        _replace(context, SettingsScreen(services: services));
    }
  }

  void _replace(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (_) => false,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.cyan : AppColors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: color,
              shadows: selected
                  ? [
                      Shadow(
                        color: AppColors.cyan.withValues(alpha: 0.8),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.jakarta(
                11,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
