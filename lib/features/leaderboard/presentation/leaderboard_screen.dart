import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/arcade_widgets.dart';
import '../../menu/presentation/app_nav.dart';
import '../application/leaderboard_store.dart';
import '../data/leaderboard_repository.dart';

String _modeDisplayName(String mode) => switch (mode) {
  'classic' => 'Klasik',
  'timed' => 'Time Attack',
  'rising' => 'Zorlaşan',
  _ => mode.toUpperCase(),
};

String _fmt(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

enum _BoardScope { global, local, weekly }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardStore store;
  _BoardScope _scope = _BoardScope.global;

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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    bottomNavigationBar: ArcadeNavBar(
      services: widget.services,
      current: AppTab.leaderboard,
    ),
    body: ArcadeBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ArcadeHeader(subtitle: 'Liderlik'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _Segmented<_BoardScope>(
                value: _scope,
                onChanged: (v) => setState(() => _scope = v),
                options: const [
                  (_BoardScope.global, 'GLOBAL'),
                  (_BoardScope.local, 'YEREL'),
                  (_BoardScope.weekly, 'HAFTALIK'),
                ],
              ),
            ),
            Observer(
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Segmented<String>(
                  value: store.selectedMode.value,
                  onChanged: store.setMode,
                  options: const [
                    ('classic', 'KLASİK'),
                    ('timed', 'TIME ATTACK'),
                    ('rising', 'ZORLAŞAN'),
                  ],
                  compact: true,
                ),
              ),
            ),
            Expanded(
              child: Observer(
                builder: (_) {
                  if (_scope == _BoardScope.local) {
                    return _ScoreList(scores: store.localScores.toList());
                  }
                  if (_scope == _BoardScope.weekly) {
                    return _ScoreList(
                      scores: store.weeklyScores.toList(),
                      message: 'Bu haftanın yerel skorları',
                    );
                  }
                  if (store.isLoadingGlobal.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.cyan),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.cyan,
                    backgroundColor: AppColors.deck,
                    onRefresh: store.refreshGlobal,
                    child: _ScoreList(
                      scores: store.globalScores.toList(),
                      message: store.globalMessage.value,
                      isFallback: store.globalIsFallback.value,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pill-shaped segmented control; the active segment glows cyan.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.onChanged,
    required this.options,
    this.compact = false,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        for (final o in options)
          Expanded(
            child: Semantics(
              button: true,
              selected: o.$1 == value,
              label: o.$2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: compact ? 34 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: o.$1 == value ? AppColors.cyan : Colors.transparent,
                    boxShadow: o.$1 == value
                        ? [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    o.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.grotesk(
                      compact ? 11 : 12,
                      color: o.$1 == value
                          ? AppColors.canvas
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final notice = message == null
        ? null
        : GlassPanel(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  isFallback
                      ? Icons.cloud_off_rounded
                      : Icons.info_outline_rounded,
                  color: AppColors.amber,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message!, style: AppTheme.jakarta(13))),
              ],
            ),
          );

    if (scores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: AppColors.outline,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Henüz skor yok',
              style: AppTheme.sora(18, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Bir oyun oyna, ilk skorun burada görünsün.',
              style: AppTheme.jakarta(14, color: AppColors.onSurfaceVariant),
            ),
          ),
          if (notice != null) ...[const SizedBox(height: 16), notice],
        ],
      );
    }

    final podium = scores.take(3).toList();
    final rest = scores.skip(3).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (notice != null) ...[notice, const SizedBox(height: 12)],
        _Podium(entries: podium),
        const SizedBox(height: 12),
        for (var i = 0; i < rest.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RankRow(rank: i + 4, entry: rest[i]),
          ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<ScoreEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd. Missing places stay empty.
    ScoreEntry? at(int i) => i < entries.length ? entries[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumSlot(
            rank: 2,
            entry: at(1),
            height: 132,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumSlot(
            rank: 1,
            entry: at(0),
            height: 164,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumSlot(
            rank: 3,
            entry: at(2),
            height: 116,
            color: AppColors.violet,
          ),
        ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.rank,
    required this.entry,
    required this.height,
    required this.color,
  });

  final int rank;
  final ScoreEntry? entry;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Semantics(
      label: e == null
          ? '$rank. sıra boş'
          : '$rank. ${e.name}, ${_fmt(e.score)} puan',
      child: GlassPanel(
        glow: e == null ? null : color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: SizedBox(
          height: height - 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color),
                ),
                child: Text(
                  '$rank',
                  style: AppTheme.sora(
                    15,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                e?.name ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.sora(13, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                e == null ? '' : _fmt(e.score),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.grotesk(15, color: color),
              ),
              if (e != null) ...[
                const SizedBox(height: 4),
                Text(
                  _modeDisplayName(e.mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.grotesk(10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});
  final int rank;
  final ScoreEntry entry;

  @override
  Widget build(BuildContext context) => GlassPanel(
    blur: false,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$rank',
            style: AppTheme.sora(
              16,
              weight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sora(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(_modeDisplayName(entry.mode), style: AppTheme.grotesk(11)),
            ],
          ),
        ),
        const Icon(Icons.bolt_rounded, size: 18, color: AppColors.amber),
        const SizedBox(width: 4),
        Text(
          _fmt(entry.score),
          style: AppTheme.sora(16, weight: FontWeight.w700),
        ),
      ],
    ),
  );
}
