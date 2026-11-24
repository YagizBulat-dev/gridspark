import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/arcade_widgets.dart';
import '../../game/domain/analytics/achievements.dart';
import '../../menu/presentation/app_nav.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final stats = services.analytics.currentStats();
    final streak = services.dailyStreak.info;
    final unlocked = services.achievements.unlocked;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: ArcadeNavBar(
        services: services,
        current: AppTab.stats,
      ),
      body: ArcadeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ArcadeHeader(subtitle: 'İstatistikler'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel(
                            'Oyun Özeti',
                            icon: Icons.bar_chart_rounded,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _BigStat(
                                  label: 'Oyun',
                                  value: '${stats.totalGames}',
                                ),
                              ),
                              Expanded(
                                child: _BigStat(
                                  label: 'Ort. Skor',
                                  value: _fmt(stats.averageScore.round()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _BigStat(
                                  label: 'Ort. Süre',
                                  value:
                                      '${stats.averageGameDurationSeconds.round()}s',
                                ),
                              ),
                              Expanded(
                                child: _BigStat(
                                  label: 'Günlük Seri',
                                  value: '${streak.current} gün',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel(
                            'Oyun Tarzın',
                            icon: Icons.psychology_rounded,
                            color: AppColors.violet,
                          ),
                          const SizedBox(height: 12),
                          _RateRow(
                            label: 'İlk 10 oyunda kaybetme',
                            value: stats.firstTenLossRate,
                          ),
                          _RateRow(
                            label: 'Yeniden oynama oranı',
                            value: stats.replayRate,
                          ),
                          _RateRow(
                            label: 'Combo / hamle',
                            value: stats.combosPerMove,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Oyun başına ortalama ${stats.combosPerGame.toStringAsFixed(1)} combo • '
                            'En iyi günlük seri ${streak.best} gün',
                            style: AppTheme.grotesk(
                              12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stats.fatalShapeCounts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GlassPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel(
                              'Oyunu Bitiren Parçalar',
                              icon: Icons.warning_amber_rounded,
                              color: AppColors.amber,
                            ),
                            const SizedBox(height: 10),
                            for (final entry in stats.fatalShapeCounts.entries
                                .take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: AppTheme.jakarta(14),
                                      ),
                                    ),
                                    StatPill(
                                      text: '${entry.value}',
                                      color: AppColors.amber,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const SectionLabel(
                      'Başarımlar',
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 10),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (final achievement in achievements)
                            _AchievementRow(
                              achievement: achievement,
                              unlocked: unlocked.contains(achievement.id),
                            ),
                        ],
                      ),
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

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppTheme.jakarta(10, color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: AppTheme.sora(22, weight: FontWeight.w800),
      ),
    ],
  );
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.jakarta(13))),
            Text(
              '%${(value * 100).round()}',
              style: AppTheme.jakarta(13, color: AppColors.cyan),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: AppColors.cyan,
          ),
        ),
      ],
    ),
  );
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: unlocked ? AppColors.cyan : AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: AppTheme.jakarta(
                  14,
                  color: unlocked ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                achievement.description,
                style: AppTheme.grotesk(
                  11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
