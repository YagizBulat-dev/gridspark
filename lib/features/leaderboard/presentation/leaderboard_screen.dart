import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/services/app_services.dart';
import '../application/leaderboard_store.dart';
import '../data/leaderboard_repository.dart';

String _modeDisplayName(String mode) => switch (mode) {
      'classic' => 'Classic',
      'timed' => 'Time Attack',
      'rising' => 'Rising Difficulty',
      _ => mode.toUpperCase(),
    };

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardStore store;

  @override
  void initState() {
    super.initState();
    store = LeaderboardStore(widget.services.leaderboard);
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Local'),
            Tab(text: 'Global'),
          ],
        ),
      ),
      body: Column(
        children: [
          Observer(
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'classic', label: Text('Classic')),
                  ButtonSegment(value: 'timed', label: Text('Time Attack')),
                  ButtonSegment(value: 'rising', label: Text('Rising')),
                ],
                selected: {store.selectedMode.value},
                onSelectionChanged: (value) => store.setMode(value.first),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Observer(builder: (_) => _ScoreList(scores: store.localScores)),
                Observer(
                  builder: (_) {
                    if (store.isLoadingGlobal.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return RefreshIndicator(
                      onRefresh: store.refreshGlobal,
                      child: _ScoreList(
                        scores: store.globalScores,
                        message: store.globalMessage.value,
                        isFallback: store.globalIsFallback.value,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScoreList extends StatelessWidget {
  const _ScoreList({
    required this.scores,
    this.message,
    this.isFallback = false,
  });

  final List<ScoreEntry> scores;
  final String? message;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.emoji_events_outlined, size: 64),
          const SizedBox(height: 16),
          const Center(child: Text('No scores yet')),
          if (message != null) ...[
            const SizedBox(height: 8),
            Center(child: Text(message!, textAlign: TextAlign.center)),
          ],
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: scores.length + (message == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        if (message != null && index == 0) {
          return Card(
            child: ListTile(
              leading: Icon(isFallback ? Icons.cloud_off : Icons.info_outline),
              title: Text(message!),
            ),
          );
        }
        final scoreIndex = index - (message == null ? 0 : 1);
        final score = scores[scoreIndex];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${scoreIndex + 1}')),
            title: Text(score.name),
            subtitle: Text(_modeDisplayName(score.mode)),
            trailing: Text(
              '${score.score}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
