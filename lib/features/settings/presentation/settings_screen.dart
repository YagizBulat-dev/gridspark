import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/arcade_widgets.dart';
import '../../menu/presentation/app_nav.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: services.settings,
    builder: (_, _) => Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: ArcadeNavBar(
        services: services,
        current: AppTab.settings,
      ),
      body: ArcadeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ArcadeHeader(subtitle: 'Ayarlar'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const SectionLabel(
                      'Ses & Müzik',
                      icon: Icons.graphic_eq_rounded,
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.volume_up_rounded,
                            title: 'Ses Efektleri',
                            subtitle: 'Blok yerleştirme ve kombo sesleri',
                            value: services.settings.sound,
                            onChanged: services.settings.setSound,
                          ),
                          const Divider(),
                          _SettingRow(
                            icon: Icons.music_note_rounded,
                            title: 'Arka Plan Müziği',
                            subtitle: 'Synthwave arcade ritimleri',
                            value: services.settings.music,
                            onChanged: services.settings.setMusic,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(
                      'Dokunsal Geri Bildirim',
                      icon: Icons.vibration_rounded,
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _SettingRow(
                        icon: Icons.touch_app_rounded,
                        title: 'Haptik Geri Bildirim',
                        subtitle: 'Yerleştirme, satır temizleme ve hatalı hamlede titreşim',
                        value: services.settings.haptics,
                        onChanged: services.settings.setHaptics,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(
                      'Zorluk',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _SettingRow(
                        icon: Icons.auto_graph_rounded,
                        title: 'Uyarlanabilir Zorluk',
                        subtitle:
                            'Zorlayan ızgarada performansına göre parça boyutu',
                        value: services.settings.adaptiveDifficulty,
                        onChanged: services.settings.setAdaptiveDifficulty,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(
                      'Görünüm & Erişilebilirlik',
                      icon: Icons.palette_rounded,
                      color: AppColors.violet,
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _SettingRow(
                        icon: Icons.motion_photos_off_rounded,
                        title: 'Azaltılmış Hareket',
                        subtitle:
                            'Skor ve satır temizleme efektlerini sadeleştir',
                        value: services.settings.reduceMotion,
                        onChanged: services.settings.setReduceMotion,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(
                      'Oyuncu Profili & Veri',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _IconTile(
                            icon: services.firebaseAvailable
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            color: services.firebaseAvailable
                                ? AppColors.cyan
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  services.firebaseAvailable
                                      ? 'Firebase bağlı'
                                      : 'Çevrimdışı mod',
                                  style: AppTheme.sora(
                                    15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  services.firebaseAvailable
                                      ? 'Anonim giriş aktif'
                                      : 'Bulut skorları için Firebase yapılandırması ekle',
                                  style: AppTheme.jakarta(
                                    13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      onTap: () => _showPrivacyPolicy(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const _IconTile(
                            icon: Icons.privacy_tip_outlined,
                            color: AppColors.violet,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gizlilik Politikası',
                                  style: AppTheme.sora(
                                    15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'İzleme yok • Anonim skorlar',
                                  style: AppTheme.jakarta(
                                    13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'GridSpark v1.0.0',
                        style: AppTheme.grotesk(12, color: AppColors.outline),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deck,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Privacy Policy',
                style: AppTheme.sora(22, weight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text(
                'GridSpark is committed to protecting your privacy.\n\n'
                '1. Data Collection:\n'
                'GridSpark does not collect, sell, or share personal identifiable information (PII).\n\n'
                '2. Leaderboards & Authentication:\n'
                'Global scores utilize Firebase Anonymous Authentication to allow safe and isolated score submission without requiring email, phone, or password.\n\n'
                '3. Local Storage:\n'
                'Game settings, challenge progress, and local high scores are stored strictly on your device using Hive.\n\n'
                '4. Children’s Privacy:\n'
                'GridSpark is suitable for all ages and contains no targeted advertising or tracking.',
                style: TextStyle(
                  height: 1.5,
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              JuicyButton(label: 'Kapat', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.color = AppColors.cyan});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.well,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _IconTile(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.sora(15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.jakarta(
                    13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}
