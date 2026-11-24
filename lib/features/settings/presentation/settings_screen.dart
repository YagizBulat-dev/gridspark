import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});
  final AppServices services;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: services.settings,
    builder: (_, _) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  value: services.settings.darkMode,
                  onChanged: services.settings.setDarkMode,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sound Effects'),
                  value: services.settings.sound,
                  onChanged: services.settings.setSound,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.music_note_outlined),
                  title: const Text('Music'),
                  value: services.settings.music,
                  onChanged: services.settings.setMusic,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.motion_photos_off_outlined),
                  title: const Text('Reduce motion'),
                  subtitle: const Text('Simplify score and line-clear effects'),
                  value: services.settings.reduceMotion,
                  onChanged: services.settings.setReduceMotion,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_outlined),
                  title: const Text('Haptics'),
                  subtitle: const Text('Vibrate on invalid placements'),
                  value: services.settings.haptics,
                  onChanged: services.settings.setHaptics,
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                services.firebaseAvailable ? Icons.cloud_done : Icons.cloud_off,
              ),
              title: Text(
                services.firebaseAvailable
                    ? 'Firebase connected'
                    : 'Offline mode',
              ),
              subtitle: Text(
                services.firebaseAvailable
                    ? 'Anonymous sign-in active'
                    : 'Add platform Firebase configuration to enable cloud scores',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              subtitle: const Text('No tracking • Anonymous scores'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showPrivacyPolicy(context),
            ),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'GridSpark',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 GridSpark. All rights reserved.',
          ),
        ],
      ),
    ),
  );

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                style: TextStyle(height: 1.5, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
