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
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'GridSpark',
            applicationVersion: '1.0.0',
          ),
        ],
      ),
    ),
  );
}
