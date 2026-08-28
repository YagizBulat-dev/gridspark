import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:newton_particles/newton_particles.dart';

import '../widgets/block_shape_view.dart' show blockColors;
import '../widgets/game_grid.dart' show GameGridState;
import '../../application/game_store.dart';
import 'effects_controller.dart';

/// Are we running inside `flutter test`?  Newton uses Chipmunk2D FFI which
/// can crash in the test environment, so we guard all `addEffect` calls.
bool get _isFlutterTest => WidgetsBinding
    .instance
    .runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

/// Gold streak tint colors.
const _gold3 = Color(0xFFF5C542);
const _gold5 = Color(0xFFFFD166);
const _gold10 = Color(0xFFFFB300);

/// Determines the active tint color based on the current streak.
Color _streakTint(int streak, Color base) {
  if (streak >= 10) return Color.lerp(base, _gold10, 0.50)!;
  if (streak >= 5) return Color.lerp(base, _gold5, 0.40)!;
  if (streak >= 3) return Color.lerp(base, _gold3, 0.30)!;
  return base;
}

/// A visual-only overlay that sits exactly on top of the game grid.
///
/// Contains the [Newton] particle canvas and a custom-painted shockwave ring
/// layer. Grid interaction (DragTarget) must pass through -- hence [IgnorePointer].
class EffectsOverlay extends StatefulWidget {
  const EffectsOverlay({
    super.key,
    required this.store,
    required this.size,
    required this.gridSize,
    required this.reduceMotion,
  });

  final GameStore store;
  final double size;
  final int gridSize;
  final bool reduceMotion;

  @override
  State<EffectsOverlay> createState() => _EffectsOverlayState();
}

class _EffectsOverlayState extends State<EffectsOverlay>
    with TickerProviderStateMixin {
  late final EffectsController _controller;
  late final EffectsCallbacks _callbacks;

  // Shockwave ring animation controllers -- one per active ring.
  final List<_ShockwaveRing> _rings = [];
  int _nextRingId = 0;

  /// Snapshot of grid values from the previous build, so we can look up
  /// cell colours BEFORE they were cleared.
  List<List<int>> _prevGridSnapshot = [];

  // Newton key -- for accessing NewtonState at runtime.
  final GlobalKey<NewtonState> _newtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _callbacks = EffectsCallbacks();
    _callbacks.onClear = _onClear;
    _callbacks.onPlace = _onPlace;
    _controller = EffectsController(
      store: widget.store,
      callbacks: _callbacks,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final ring in _rings) {
      ring.controller.dispose();
    }
    _rings.clear();
    super.dispose();
  }

  // -- Cell geometry helpers ----------------------------------------------

  double get _cellPitch =>
      (widget.size - 2 * GameGridState.gridPadding) / widget.gridSize;

  Offset _cellCenter(int row, int col) => Offset(
        GameGridState.gridPadding + (col + 0.5) * _cellPitch,
        GameGridState.gridPadding + (row + 0.5) * _cellPitch,
      );

  /// Normalised origin for the Newton widget (0-1 range).
  Offset _normalisedOrigin(Offset pixel) => Offset(
        pixel.dx / widget.size,
        pixel.dy / widget.size,
      );

  // -- Clear burst -------------------------------------------------------

  void _onClear() {
    if (widget.reduceMotion || _isFlutterTest) return;
    final clearedCells = widget.store.lastClearedCells;
    if (clearedCells.isEmpty) return;

    final streak = widget.store.streak.value;
    final newtonState = _newtonKey.currentState;
    if (newtonState == null) return;

    for (final cell in clearedCells) {
      if (!_controller.canAddEffect) break;

      // Read colour from snapshot BEFORE clear.
      final colorIdx = (cell.row < _prevGridSnapshot.length &&
              cell.col < _prevGridSnapshot[cell.row].length)
          ? _prevGridSnapshot[cell.row][cell.col]
          : -1;
      if (colorIdx < 0 || colorIdx >= blockColors.length) continue;

      final baseColor = blockColors[colorIdx];
      final tintedColor = _streakTint(streak, baseColor);
      final center = _cellCenter(cell.row, cell.col);
      final origin = _normalisedOrigin(center);

      // Coloured burst particles (15-20 per cell).
      final particleCount = 15 + math.Random().nextInt(6);
      _controller.adjustParticleCount(particleCount);

      newtonState.addEffect(
        PhysicsEffectConfiguration(
          particleConfiguration: ParticleConfiguration(
            shape: const CircleShape(),
            size: const Size(10, 10),
            color: LinearInterpolationParticleColor(
              colors: [
                tintedColor,
                Color.lerp(tintedColor, Colors.white, 0.50)!,
              ],
            ),
          ),
          emissionProperties: EmissionProperties(
            origin: origin,
            minOriginOffset: const Offset(-0.012, -0.012),
            maxOriginOffset: const Offset(0.012, 0.012),
            particleCount: particleCount,
            particlesPerEmit: particleCount,
            emitDuration: Duration.zero,
            particleLifespan: const DurationRange.between(
              Duration(milliseconds: 350),
              Duration(milliseconds: 450),
            ),
          ),
          physicsProperties: PhysicsProperties(
            gravity: const Gravity(0, 5.5),
            angle: const NumRange<double>.between(0, 360),
            velocity: const NumRange<double>.between(2.5, 5.5),
            friction: const NumRange<double>.between(
              Friction.ice,
              Friction.teflon,
            ),
            restitution: const NumRange<double>.between(
              Restitution.rubberBall,
              Restitution.basketball,
            ),
          ),
          visualProperties: VisualProperties(
            beginScale: const NumRange<double>.between(0.6, 1.4),
            endScale: const NumRange<double>.between(0.0, 0.3),
            fadeInThreshold: NumRange.single(0.0),
            fadeOutThreshold: const NumRange<double>.between(0.45, 0.75),
            fadeOutCurve: Curves.easeOut,
            scaleCurve: Curves.easeOut,
          ),
          animationProperties: const AnimationProperties(
            startDelay: Duration(milliseconds: 90),
          ),
        ),
      );

      // White sparkle burst (6 particles, smaller & faster fade).
      const sparkleCount = 6;
      _controller.adjustParticleCount(sparkleCount);

      newtonState.addEffect(
        PhysicsEffectConfiguration(
          particleConfiguration: ParticleConfiguration(
            shape: const CircleShape(),
            size: const Size(6, 6),
            color: const SingleParticleColor(color: Colors.white),
          ),
          emissionProperties: EmissionProperties(
            origin: origin,
            minOriginOffset: const Offset(-0.008, -0.008),
            maxOriginOffset: const Offset(0.008, 0.008),
            particleCount: sparkleCount,
            particlesPerEmit: sparkleCount,
            emitDuration: Duration.zero,
            particleLifespan: const DurationRange.between(
              Duration(milliseconds: 200),
              Duration(milliseconds: 300),
            ),
          ),
          physicsProperties: PhysicsProperties(
            gravity: const Gravity(0, 3.0),
            angle: const NumRange<double>.between(0, 360),
            velocity: const NumRange<double>.between(1.5, 3.5),
            friction: const NumRange<double>.between(
              Friction.ice,
              Friction.ice,
            ),
            restitution: const NumRange<double>.between(
              Restitution.rubberBall,
              Restitution.rubberBall,
            ),
          ),
          visualProperties: VisualProperties(
            beginScale: const NumRange<double>.between(0.5, 1.0),
            endScale: const NumRange<double>.between(0.0, 0.1),
            fadeInThreshold: NumRange.single(0.0),
            fadeOutThreshold: const NumRange<double>.between(0.3, 0.5),
            fadeOutCurve: Curves.easeIn,
            scaleCurve: Curves.easeOut,
          ),
          animationProperties: const AnimationProperties(
            startDelay: Duration(milliseconds: 90),
          ),
        ),
      );
    }

    // Shockwave ring.
    _spawnShockwave();
  }

  // -- Placement micro-burst ----------------------------------------------

  void _onPlace() {
    if (widget.reduceMotion || _isFlutterTest) return;
    final placedCells = widget.store.lastPlacedCells;
    if (placedCells.isEmpty) return;

    final newtonState = _newtonKey.currentState;
    if (newtonState == null) return;

    final rng = math.Random();
    for (final cell in placedCells) {
      if (!_controller.canAddEffect) break;

      final colorIdx = (cell.row < widget.store.engine.grid.length &&
              cell.col < widget.store.engine.grid[cell.row].length)
          ? widget.store.engine.grid[cell.row][cell.col]
          : -1;
      if (colorIdx < 0 || colorIdx >= blockColors.length) continue;

      final baseColor = blockColors[colorIdx];
      final center = _cellCenter(cell.row, cell.col);
      final origin = _normalisedOrigin(center);

      final particleCount = 3 + rng.nextInt(3); // 3-5 particles
      _controller.adjustParticleCount(particleCount);

      newtonState.addEffect(
        PhysicsEffectConfiguration(
          particleConfiguration: ParticleConfiguration(
            shape: const CircleShape(),
            size: const Size(6, 6),
            color: SingleParticleColor(
              color: baseColor.withValues(alpha: 0.7),
            ),
          ),
          emissionProperties: EmissionProperties(
            origin: origin,
            minOriginOffset: const Offset(-0.005, -0.005),
            maxOriginOffset: const Offset(0.005, 0.005),
            particleCount: particleCount,
            particlesPerEmit: particleCount,
            emitDuration: Duration.zero,
            particleLifespan: const DurationRange.between(
              Duration(milliseconds: 100),
              Duration(milliseconds: 140),
            ),
          ),
          physicsProperties: PhysicsProperties(
            gravity: const Gravity(0, 2.0),
            angle: const NumRange<double>.between(0, 360),
            velocity: const NumRange<double>.between(1.0, 2.5),
            friction: const NumRange<double>.single(Friction.ice),
            restitution: const NumRange<double>.single(Restitution.rubberBall),
          ),
          visualProperties: VisualProperties(
            beginScale: const NumRange<double>.between(0.5, 0.9),
            endScale: const NumRange<double>.between(0.0, 0.1),
            fadeInThreshold: NumRange.single(0.0),
            fadeOutThreshold: const NumRange<double>.between(0.4, 0.6),
            fadeOutCurve: Curves.easeOut,
            scaleCurve: Curves.easeOut,
          ),
        ),
      );
    }
  }

  // -- Shockwave ring ----------------------------------------------------

  void _spawnShockwave() {
    // Compute bounding box of cleared cells.
    final cleared = widget.store.lastClearedCells;
    if (cleared.isEmpty) return;

    double minR = double.infinity, minC = double.infinity;
    double maxR = double.negativeInfinity, maxC = double.negativeInfinity;
    for (final cell in cleared) {
      if (cell.row < minR) minR = cell.row.toDouble();
      if (cell.col < minC) minC = cell.col.toDouble();
      if (cell.row > maxR) maxR = cell.row.toDouble();
      if (cell.col > maxC) maxC = cell.col.toDouble();
    }

    final center = Offset(
      GameGridState.gridPadding + ((minC + maxC) / 2 + 0.5) * _cellPitch,
      GameGridState.gridPadding + ((minR + maxR) / 2 + 0.5) * _cellPitch,
    );

    final streak = widget.store.streak.value;
    Color ringColor;
    if (streak >= 10) {
      ringColor = const Color(0xFFFFB300);
    } else if (streak >= 5) {
      ringColor = const Color(0xFFFFD166);
    } else if (streak >= 3) {
      ringColor = const Color(0xFFF5C542);
    } else {
      ringColor = Colors.white;
    }

    final controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    final ring = _ShockwaveRing(
      id: _nextRingId++,
      center: center,
      color: ringColor,
      controller: controller,
    );
    _rings.add(ring);

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _rings.removeWhere((r) => r.id == ring.id);
        if (mounted) setState(() {});
      }
    });
    controller.forward();
  }

  // -- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Update prev-grid snapshot at the END of build so it reflects the
    // current state (which will become "previous" by the next clear).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prevGridSnapshot = widget.store.engine.grid
            .map((row) => List<int>.from(row))
            .toList();
      }
    });

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IgnorePointer(
        child: Stack(
          children: [
            // Newton particle canvas (skip in tests — its FFI ticker
            // would cause pumpAndSettle to never settle).
            if (_isFlutterTest)
              const SizedBox.expand()
            else
              Newton(
                key: _newtonKey,
                onEffectStateChanged: (effect, state) {
                  if (state == EffectState.killed) {
                    // Estimate: a physics effect's active particles are
                    // all gone when it's killed.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _controller.adjustParticleCount(
                          -(effect.totalEmittedCount),
                        );
                      }
                    });
                  }
                },
                child: const SizedBox.expand(),
              ),

            // Shockwave ring overlay.
            if (_rings.isNotEmpty)
              AnimatedBuilder(
                animation: Listenable.merge(
                  _rings.map((r) => r.controller),
                ),
                builder: (context, _) => CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ShockwavePainter(rings: _rings),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -- Shockwave ring data -------------------------------------------------

class _ShockwaveRing {
  _ShockwaveRing({
    required this.id,
    required this.center,
    required this.color,
    required this.controller,
  });

  final int id;
  final Offset center;
  final Color color;
  final AnimationController controller;
}

// -- Shockwave painter ---------------------------------------------------

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter({required this.rings});

  final List<_ShockwaveRing> rings;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ring in rings) {
      final t = ring.controller.value;
      final maxRadius = size.shortestSide * 0.6;
      final radius = maxRadius * Curves.easeOut.transform(t);
      final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = ring.color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - t * 0.5);

      canvas.drawCircle(ring.center, radius, paint);
    }
  }

  @override
  // Always repaint: AnimatedBuilder already limits rebuilds to active
  // animation frames, so this is only called when a ring is actually
  // animating. The _rings list is a shared mutable reference on the
  // State, so an identity check would always be false and break rendering.
  bool shouldRepaint(covariant _ShockwavePainter old) => true;
}
