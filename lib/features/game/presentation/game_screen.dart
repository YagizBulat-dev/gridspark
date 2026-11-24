import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../../core/services/app_services.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/share_service.dart';
import '../application/game_store.dart';
import '../domain/game_models.dart';
import 'effects/effects_overlay.dart';
import 'game_animation.dart';
import 'widgets/block_shape_view.dart';
import 'widgets/game_grid.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, required this.services});
  final GameMode mode;
  final AppServices services;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late GameStore store;
  bool submitted = false;
  int scoreAnimationKey = 0;
  late final AnimationController _trayShakeController;
  late final Animation<double> _trayShakeAnimation;
  int _shakingTrayIndex = -1;
  final GlobalKey<GameGridState> _gridKey = GlobalKey<GameGridState>();

  // --- Audio reactions ---
  final List<ReactionDisposer> _disposers = [];

  // --- Combo zoom pulse ---
  late final AnimationController _comboZoomController;
  int _lastComboTrigger = 0;

  // --- Streak threshold glow ---
  late final AnimationController _streakGlowController;
  late final Animation<double> _streakGlowIntensity;
  int _lastStreak = 0;
  Color _streakGlowColor = const Color(0xFF26D7B7);

  // --- Game-over blur/darken ---
  late final AnimationController _gameOverController;
  late final Animation<double> _gameOverBlur;
  late final Animation<double> _gameOverDarken;
  bool _wasGameOver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createStore();
    _trayShakeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _trayShakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _trayShakeController,
            curve: Curves.easeInOut,
          ),
        );

    // Combo zoom pulse: 150ms elastic overshoot.
    _comboZoomController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _comboZoomController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _comboZoomController.reverse();
      }
    });

    // Streak glow: 300ms pulse.
    _streakGlowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _streakGlowIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _streakGlowController, curve: Curves.easeOut),
    );
    _streakGlowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _streakGlowController.reverse();
      }
    });

    // Game-over blur/darken: 300ms.
    _gameOverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _gameOverBlur = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _gameOverController, curve: Curves.easeOut),
    );
    _gameOverDarken = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _gameOverController, curve: Curves.easeOut),
    );
  }

  void _createStore() {
    // Dispose old reactions
    for (final d in _disposers.toList()) {
      d();
    }
    _disposers.clear();

    store = GameStore(
      widget.mode,
      snapshot: widget.services.gameSnapshots.load(widget.mode),
      onSnapshot: widget.services.gameSnapshots.save,
      onClearSnapshot: () => widget.services.gameSnapshots.clear(widget.mode),
      onInvalidSnapshot: () => widget.services.gameSnapshots.clear(widget.mode),
      onProgress: widget.services.dailyChallenges.record,
    );
    _setupReactions();

    // Play game music based on mode
    final track = switch (widget.mode) {
      GameMode.classic => MusicTrack.classic,
      GameMode.timed => MusicTrack.timed,
      GameMode.rising => MusicTrack.rising,
    };
    widget.services.audio.playMusic(track);
  }

  void _setupReactions() {
    // Combo/line-clear SFX
    _disposers.add(
      reaction((_) => store.comboPopupTrigger.value, (trigger) {
        if (trigger > 0) {
          final lines = store.lastClearedLines.value;
          if (lines >= 2) {
            // Combo — pitch varies with line count
            widget.services.audio.playSfx(
              Sfx.combo,
              pitch: 1.0 + (lines - 2) * 0.1,
            );
          } else {
            widget.services.audio.playSfx(Sfx.clear);
          }
        }
      }),
    );

    // Game over SFX
    _disposers.add(
      reaction((_) => store.isGameOver.value, (isOver) {
        if (isOver) {
          widget.services.audio.playSfx(Sfx.gameOver);
        }
      }),
    );

    // Tray refill SFX
    _disposers.add(
      reaction((_) => store.trayRefillCount.value, (_) {
        widget.services.audio.playSfx(Sfx.trayRefill);
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    store.setLifecycleActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    for (final d in _disposers.toList()) {
      d();
    }
    _disposers.clear();
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    _trayShakeController.dispose();
    _comboZoomController.dispose();
    _streakGlowController.dispose();
    _gameOverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.mode.displayName),
      centerTitle: true,
      actions: [
        Observer(
          builder: (_) => IconButton(
            tooltip: store.manuallyPaused.value ? 'Resume game' : 'Pause game',
            onPressed: store.isGameOver.value ? null : store.toggleManualPause,
            icon: Icon(
              store.manuallyPaused.value
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
            ),
          ),
        ),
      ],
    ),
    body: Observer(builder: _buildGame),
  );

  Widget _buildGame(BuildContext context) {
    final _ = store.gridVersion.value;
    final trayRefill = store.trayRefillCount.value;
    final comboTrigger = store.comboPopupTrigger.value;
    final currentStreak = store.streak.value;
    final reduceMotion = widget.services.settings.reduceMotion;

    // --- Detect combo zoom trigger ---
    if (comboTrigger > _lastComboTrigger && !reduceMotion) {
      _lastComboTrigger = comboTrigger;
      _comboZoomController.forward(from: 0);
    } else if (comboTrigger > _lastComboTrigger) {
      _lastComboTrigger = comboTrigger;
    }

    // --- Detect streak threshold crossings ---
    if (currentStreak != _lastStreak && !reduceMotion) {
      _detectStreakThreshold(_lastStreak, currentStreak);
      _lastStreak = currentStreak;
    } else if (currentStreak != _lastStreak) {
      _lastStreak = currentStreak;
    }

    // --- Detect game over ---
    if (store.isGameOver.value && !_wasGameOver) {
      _wasGameOver = true;
      _comboZoomController.reset();
      _streakGlowController.stop();
      _trayShakeController.stop();
      if (!reduceMotion) {
        _gameOverController.forward(from: 0);
      }
    }

    if (store.isGameOver.value && !submitted) {
      submitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver());
    }

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridSize = constraints.maxWidth;
                final gridPitch = GameGridState.cellPitch(
                  gridSize,
                  GameGridState.gridPadding,
                  store.engine.size,
                );
                // Tray pieces use their own cell size so the three slots always
                // fit the available width (no horizontal overflow on narrow
                // screens). Width is derived from the slot width assuming the
                // widest possible shape spans 5 cells.
                const traySpacing = 12.0;
                final traySlotCount = store.tray.length;
                final traySlotWidth =
                    (constraints.maxWidth - traySpacing * (traySlotCount - 1)) /
                        traySlotCount;
                final trayCellSize =
                    (traySlotWidth / 5).clamp(12.0, 30.0);
                final trayHeight =
                    (trayCellSize * 4 + 12).clamp(100.0, 132.0);
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AnimatedStat(
                          label: 'SCORE',
                          value: store.score.value,
                          reduceMotion: reduceMotion,
                        ),
                        _Stat(label: 'STREAK', value: '${store.streak.value}x'),
                        if (widget.mode == GameMode.timed)
                          _Stat(
                            label: 'TIME',
                            value: '${store.secondsLeft.value}s',
                          ),
                        if (widget.mode == GameMode.rising)
                          _Stat(
                            label: 'LEVEL',
                            value: 'L${store.difficultyLevel.value + 1}',
                          ),
                        _Stat(
                          label: 'BEST',
                          value:
                              '${widget.services.leaderboard.localScores(mode: widget.mode.name).firstOrNull?.score ?? 0}',
                        ),
                      ],
                    ),
                    if (store.lastPlacementPoints.value > 0)
                      AnimatedSwitcher(
                        duration: gameAnimationDuration(
                          reduceMotion,
                          const Duration(milliseconds: 260),
                        ),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '+${store.lastPlacementPoints.value} • ${store.lastMoveFeedback.value}',
                          key: ValueKey(
                            '${store.score.value}-$scoreAnimationKey',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Combo zoom pulse wraps the GameGrid + effects overlay.
                    AnimatedBuilder(
                      animation: _comboZoomController,
                      builder: (context, child) {
                        final t = _comboZoomController.value;
                        final scale = 1.0 + 0.03 * _elasticPulse(t);
                        return Transform.scale(
                          scale: reduceMotion ? 1.0 : scale,
                          child: child,
                        );
                      },
                      child: Stack(
                        children: [
                          GameGrid(
                            key: _gridKey,
                            engine: store.engine,
                            size: gridSize,
                            shapes: store.tray,
                            onDrop: _place,
                            clearedCells: store.lastClearedCells,
                            placedCells: store.lastPlacedCells,
                            clearAnimationKey: store.gridVersion.value,
                            reduceMotion: reduceMotion,
                            onInvalidDrop: _handleInvalidDrop,
                          ),
                          EffectsOverlay(
                            key: ObjectKey(store),
                            store: store,
                            size: gridSize,
                            gridSize: store.engine.size,
                            reduceMotion: reduceMotion,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: DragTarget<int>(
                        onWillAcceptWithDetails: (_) => true,
                        onMove: (d) => _gridKey.currentState
                            ?.updateHoverFromGlobal(d.offset, d.data),
                        onLeave: (_) => _gridKey.currentState?.clearHover(),
                        onAcceptWithDetails: (d) => _gridKey.currentState
                            ?.acceptDropFromGlobal(d.offset, d.data),
                        builder: (context, _, __) => Column(
                          children: [
                            const Spacer(),
                            Text(
                              'DRAG A PIECE TO PLACE',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: trayHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var i = 0; i < store.tray.length; i++)
                            Expanded(
                              child: Semantics(
                              label: store.tray[i] == null
                                  ? 'Piece ${i + 1}, placed'
                                  : 'Piece ${i + 1}, ${store.tray[i]!.id}, ${store.tray[i]!.cells.length} blocks',
                              button: store.tray[i] != null,
                              hint: store.tray[i] == null
                                  ? 'This piece has been placed'
                                  : 'Drag to place on the grid',
child: store.tray[i] == null
                                  ? Opacity(
                                      opacity: 0.4,
                                      child: SizedBox(
                                        width: 54,
                                        height: 100,
                                        child: Center(
                                          child: Icon(
                                            Icons.check_circle_outline,
                                            size: 28,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                    )
                                  : AnimatedBuilder(
                                      animation: _trayShakeController,
                                      builder: (context, child) {
                                        final isShaking =
                                            _shakingTrayIndex == i &&
                                            _trayShakeController.isAnimating;
                                        return Transform.translate(
                                          offset: Offset(
                                            isShaking
                                                ? _trayShakeAnimation.value
                                                : 0,
                                            0,
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: _TraySlotAppear(
                                        slotIndex: i,
                                        refillTrigger: trayRefill,
                                        refillSlot:
                                            store.trayRefillSlot.value,
                                        reduceMotion: reduceMotion,
                                        child: AnimatedOpacity(
                                          duration: gameAnimationDuration(
                                            reduceMotion,
                                            const Duration(milliseconds: 150),
                                          ),
                                          opacity: store.isPaused ? .35 : 1,
child: Draggable<int>(
  data: i,
  dragAnchorStrategy: (draggable, context, position) {
    final shape = store.tray[i]!;
    final feedbackWidth = shape.width * gridPitch;
    final feedbackHeight = shape.height * gridPitch;
    return Offset(
      feedbackWidth / 2,
      feedbackHeight + GameGridState.liftOffset,
    );
  },
  feedback: IgnorePointer(
    child: Material(
      color: Colors.transparent,
      child: BlockShapeView(
        shape: store.tray[i]!,
        cellSize: gridPitch,
        isDragging: true,
      ),
    ),
  ),
                                            childWhenDragging: Opacity(
                                              opacity: .18,
                                              child: Center(
                                                child: BlockShapeView(
                                                  shape: store.tray[i]!,
                                                  cellSize: trayCellSize,
                                                ),
                                              ),
                                            ),
                                            child: Center(
                                              child: BlockShapeView(
                                                shape: store.tray[i]!,
                                                cellSize: trayCellSize,
                                              ),
                                            ),
                                            onDraggableCanceled:
                                                (velocity, offset) {
                                              if (widget
                                                  .services
                                                  .settings
                                                  .haptics) {
                                                HapticFeedback.mediumImpact();
                                              }
                                              _gridKey.currentState
                                                  ?.clearHover();
                                              _shakeTraySlot(i);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            ),
                        ],
                      ),
                    ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (store.isPaused && !store.isGameOver.value)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .48),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_circle_outline, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            store.lifecyclePaused.value
                                ? 'Game paused while the app is inactive'
                                : 'Game paused',
                          ),
                          if (store.manuallyPaused.value) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: store.toggleManualPause,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Resume'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Streak threshold glow — radial vignette overlay.
          if (_streakGlowController.isAnimating && !reduceMotion)
            AnimatedBuilder(
              animation: _streakGlowController,
              builder: (context, _) => IgnorePointer(
                child: Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Transparent centre, coloured edges.
                      gradient: RadialGradient(
                        radius: 1.0,
                        center: Alignment.center,
                        colors: [
                          Colors.transparent,
                          _streakGlowColor.withValues(
                            alpha: _streakGlowIntensity.value * 0.25,
                          ),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Game-over blur + darken overlay.
          if (_gameOverController.isAnimating &&
              _gameOverController.value > 0 &&
              !reduceMotion)
            AnimatedBuilder(
              animation: _gameOverController,
              builder: (context, _) => IgnorePointer(
                child: Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _gameOverBlur.value,
                      sigmaY: _gameOverBlur.value,
                    ),
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: _gameOverDarken.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (comboTrigger > 0)
            _ComboPopup(
              key: ValueKey(comboTrigger),
              message: store.lastMoveFeedback.value,
              points: store.lastPlacementPoints.value,
              reduceMotion: reduceMotion,
            ),
        ],
      ),
    );
  }

  /// Simple elastic pulse curve: 0→~1.2→0 in one cycle.
  double _elasticPulse(double t) {
    if (t <= 0 || t >= 1) return 0;
    return math.sin(t * math.pi) * (1 + 0.2 * math.sin(t * 3 * math.pi));
  }

  /// Detect streak threshold crossings (3, 5, 10) and trigger glow.
  void _detectStreakThreshold(int oldStreak, int newStreak) {
    const thresholds = [3, 5, 10];
    const colors = [
      Color(0xFF26D7B7), // teal at 3x
      Color(0xFFFFB84D), // orange at 5x
      Color(0xFF7C5CFF), // purple at 10x
    ];
    for (var i = thresholds.length - 1; i >= 0; i--) {
      if (oldStreak < thresholds[i] && newStreak >= thresholds[i]) {
        _streakGlowColor = colors[i];
        _streakGlowController.forward(from: 0);
        return;
      }
    }
  }

  bool _place(int trayIndex, int row, int col) {
    final placed = store.place(trayIndex, row, col);
    if (placed && mounted) {
      widget.services.audio.playSfx(Sfx.place);
      setState(() {
        scoreAnimationKey++;
      });
    }
    return placed;
  }

  /// Geçersiz bir bırakmada (normalde onWillAccept bunu önler; yedek güvence)
  /// haptic + tray shake tetikler.
  void _handleInvalidDrop(int trayIndex) {
  if (widget.services.settings.haptics) {
    HapticFeedback.mediumImpact();
  }
  _shakeTraySlot(trayIndex);
}
  /// Cancels any in-progress shake first so rapid drops don't layer animations.
  void _shakeTraySlot(int trayIndex) {
    widget.services.audio.playSfx(Sfx.invalid);
    if (widget.services.settings.reduceMotion) return;
    _trayShakeController.stop();
    setState(() => _shakingTrayIndex = trayIndex);
    _trayShakeController.forward(from: 0);
  }

  /// Prompts the user for a nickname (max 24 chars) before saving.
  /// Returns the sanitized nickname, or 'Player' if the dialog is dismissed.
  Future<String> _promptNickname() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Player',
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (result == null || result.isEmpty) ? 'Player' : result;
  }

  Future<void> _showGameOver() async {
    await store.clearSnapshot();
    if (!mounted) return;
    final nickname = await _promptNickname();
    if (!mounted) return;
    String? saveMessage;
    try {
      saveMessage = (await widget.services.leaderboard.submit(
        store.score.value,
        widget.mode.name,
        nickname: nickname,
      )).message;
    } catch (_) {
      saveMessage = 'Score could not be saved. Please try again later.';
    }
    if (!mounted) return;
    final action = await showGeneralDialog<_GameOverAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Game Over',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        );
        return ScaleTransition(
          scale: curvedAnim,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => _GameOverPanel(
        score: store.score.value,
        bestStreak: store.bestStreak.value,
        saveMessage: saveMessage,
        onShare: () async {
          try {
            final result = await widget.services.share.shareScore(
              score: store.score.value,
              mode: widget.mode.name,
              bestStreak: store.bestStreak.value,
            );
            if (context.mounted) {
              final message = switch (result) {
                ShareOutcome.success => 'Score shared.',
                ShareOutcome.dismissed => 'Sharing dismissed.',
                ShareOutcome.error => 'Sharing is unavailable.',
              };
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing is unavailable.')),
              );
            }
          }
          // Stay in the game-over panel; don't pop.
        },
        onMenu: () => Navigator.pop(context, _GameOverAction.menu),
        onReplay: () => Navigator.pop(context, _GameOverAction.replay),
      ),
    );
    if (!mounted) return;
    if (action == _GameOverAction.replay) {
      await store.dispose();
      await store.clearSnapshot();
      setState(() {
        submitted = false;
        _wasGameOver = false;
        _gameOverController.reset();
        _lastComboTrigger = 0;
        _lastStreak = 0;
        _shakingTrayIndex = -1;
        _createStore();
      });
    } else if (action == _GameOverAction.menu) {
      Navigator.pop(context);
    }
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({
    required this.score,
    required this.bestStreak,
    required this.saveMessage,
    required this.onShare,
    required this.onMenu,
    required this.onReplay,
  });

  final int score;
  final int bestStreak;
  final String? saveMessage;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10111A), // fallback; overridden by gradient below
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF232441), Color(0xFF16172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Color(0x332A2B4E), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x1A7C5CFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x667C5CFF),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 42,
                        color: Color(0xFF7C5CFF),
                      ),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Game Over',
                  style: TextStyle(
                    color: Color(0xFFF2F3FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Score label and value
                _StatLabel(
                  label: 'Final score',
                  value: score,
                  color: Color(0xFF9AA0B5),
                  valueColor: Color(0xFFFFD166),
                  valueWeight: FontWeight.w800,
                  valueSize: 34,
                ),
                const SizedBox(height: 12),
                _StatLabel(
                  label: 'Best streak',
                  value: bestStreak,
                  color: Color(0xFF9AA0B5),
                  valueColor: Color(0xFFB7BBD0),
                  valueWeight: FontWeight.w600,
                  valueSize: 20,
                ),
                if (saveMessage?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    saveMessage!,
                    style: const TextStyle(
                      color: Color(0xFF8E93A9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),

                // Buttons row (try horizontal, fall back to column via SizedBox spacing)
                _ButtonRow(
                  onShare: onShare,
                  onMenu: onMenu,
                  onReplay: onReplay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stat label with a label and a prominently-styled value.
class _StatLabel extends StatelessWidget {
  const _StatLabel({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
    required this.valueWeight,
    required this.valueSize,
  });
  final String label;
  final int value;
  final Color color;
  final Color valueColor;
  final FontWeight valueWeight;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        '$value',
        style: TextStyle(
          color: valueColor,
          fontSize: valueSize,
          fontWeight: valueWeight,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

/// A horizontal row of three game-over action buttons.
/// If the context is narrow, the buttons wrap into a column via MainAxisSize.min.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.onShare,
    required this.onMenu,
    required this.onReplay,
  });

  final VoidCallback onShare;
  final VoidCallback onMenu;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 10,
    alignment: WrapAlignment.center,
    children: [
      _GameOverButton(
        icon: Icons.share_outlined,
        label: 'Share',
        color: Color(0xFF26D7B7),
        fontWeight: FontWeight.w600,
        onPressed: onShare,
        isFilled: false,
      ),
      _GameOverButton(
        icon: Icons.home_outlined,
        label: 'Back to menu',
        color: Color(0xFF4CB5FF),
        fontWeight: FontWeight.w600,
        onPressed: onMenu,
        isFilled: false,
      ),
      _GameOverButton(
        icon: Icons.replay_rounded,
        label: 'Play again',
        color: Color(0xFFFFFFFF),
        fontWeight: FontWeight.w700,
        onPressed: onReplay,
        isFilled: true,
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF9B6BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x557C5CFF),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
    ],
  );
}

/// A single game-over action button.
class _GameOverButton extends StatelessWidget {
  const _GameOverButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.fontWeight,
    required this.onPressed,
    this.isFilled = false,
    this.gradient,
    this.boxShadow,
  });

  final IconData icon;
  final String label;
  final Color color;
  final FontWeight fontWeight;
  final VoidCallback onPressed;
  final bool isFilled;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient:
              gradient ??
              const LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFF9B6BFF)],
              ),
          boxShadow: boxShadow,
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(150, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: 17,
        ),
      ),
    );
  }
}

enum _GameOverAction { replay, menu }

class _AnimatedStat extends StatelessWidget {
  const _AnimatedStat({
    required this.label,
    required this.value,
    required this.reduceMotion,
    this.color,
  });
  final String label;
  final int value;
  final bool reduceMotion;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      AnimatedSwitcher(
        duration: gameAnimationDuration(
          reduceMotion,
          const Duration(milliseconds: 220),
        ),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text(
          '$value',
          key: ValueKey(value),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ],
  );
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.onPressed,
    required this.icon,
    required this.color,
  });
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

/// Animation 4: Combo/streak popup — parabolic float-up + fade (~450ms)
/// with an initial scale-bounce (0.3→1.3→1.0) for a pop-in feel.
/// Shown as an overlay in the Stack when a line-clear combo occurs.
class _ComboPopup extends StatefulWidget {
  const _ComboPopup({
    super.key,
    required this.message,
    required this.points,
    required this.reduceMotion,
  });
  final String message;
  final int points;
  final bool reduceMotion;

  @override
  State<_ComboPopup> createState() => _ComboPopupState();
}

class _ComboPopupState extends State<_ComboPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _scaleController = AnimationController(vsync: this);
      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    } else {
      _scaleController = AnimationController(
        duration: const Duration(milliseconds: 100),
        vsync: this,
      );
      _scaleAnimation =
          TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.3), weight: 60),
            TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 40),
          ]).animate(
            CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
          );
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = gameAnimationDuration(
      widget.reduceMotion,
      const Duration(milliseconds: 450),
    );
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          builder: (context, val, _) {
            // Parabolic float-up: ease upward.
            final yOffset = -120 * (1 - (1 - val) * (1 - val));
            // Fade: hold at 1 until 75%, then fade out.
            final opacity = val < 0.75
                ? 1.0
                : (1 - (val - 0.75) / 0.25).clamp(0.0, 1.0);
            return AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) =>
                  Transform.scale(scale: _scaleAnimation.value, child: child),
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.points > 0
                          ? '+${widget.points} • ${widget.message}'
                          : widget.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Animation 5: Tray piece drop-in — the newly refilled slot scales and
/// slides into place while the other two slots stay still.
class _TraySlotAppear extends StatefulWidget {
  const _TraySlotAppear({
    required this.slotIndex,
    required this.refillTrigger,
    required this.refillSlot,
    required this.reduceMotion,
    required this.child,
  });

  final int slotIndex;
  final int refillTrigger;
  final int refillSlot;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_TraySlotAppear> createState() => _TraySlotAppearState();
}

class _TraySlotAppearState extends State<_TraySlotAppear>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _offsetAnim;
  int _lastRefillTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastRefillTrigger = widget.refillTrigger;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.reduceMotion) {
      _scaleAnim = const AlwaysStoppedAnimation(1);
      _opacityAnim = const AlwaysStoppedAnimation(1);
      _offsetAnim = const AlwaysStoppedAnimation(0);
    } else {
      _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      );
      _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      );
      _offsetAnim = Tween<double>(begin: -18.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _TraySlotAppear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refillTrigger != _lastRefillTrigger) {
      _lastRefillTrigger = widget.refillTrigger;
      // Only the slot that actually received a new piece replays the drop-in.
      if (!widget.reduceMotion &&
          widget.refillSlot == widget.slotIndex &&
          widget.refillSlot >= 0) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, _offsetAnim.value),
      child: Transform.scale(
        scale: _scaleAnim.value,
        child: Opacity(opacity: _opacityAnim.value, child: child),
      ),
    ),
    child: widget.child,
  );
}
