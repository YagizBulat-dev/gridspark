import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/game_store.dart';
import '../../domain/game_models.dart' show CellOffset;
import '../widgets/block_shape_view.dart' show blockColors;
import '../widgets/game_grid.dart' show GameGridState;
import 'effects_controller.dart';

/// Are we running inside `flutter test`?  Effects are skipped there so the
/// ticker never keeps `pumpAndSettle` spinning.
bool get _isFlutterTest => WidgetsBinding
    .instance
    .runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

/// Gold streak tint colors.
const _gold3 = Color(0xFFF5C542);
const _gold5 = Color(0xFFFFD166);
const _gold10 = Color(0xFFFFB300);
const _iceWhite = Color(0xFFEAF4FF);

/// Determines the active tint color based on the current streak.
Color _streakTint(int streak, Color base) {
  if (streak >= 10) return Color.lerp(base, _gold10, 0.50)!;
  if (streak >= 5) return Color.lerp(base, _gold5, 0.40)!;
  if (streak >= 3) return Color.lerp(base, _gold3, 0.30)!;
  return base;
}

/// A polished, hand-painted effects layer that sits exactly on top of the
/// game grid. It replaces the old physics-particle burst with a custom
/// "energy" system: soft blooms, light beams, expanding rings and shards.
///
/// The layer is visual-only and never blocks the grid's DragTarget.
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
    with SingleTickerProviderStateMixin {
  late final EffectsController _controller;
  late final EffectsCallbacks _callbacks;
  late final Ticker _ticker;

  final List<_Burst> _bursts = [];
  final math.Random _rng = math.Random();
  Duration _lastTick = Duration.zero;

  /// Snapshot of grid values from the previous build, so we can look up
  /// cell colours BEFORE they were cleared.
  List<List<int>> _prevGridSnapshot = [];

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
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  // -- Geometry helpers ---------------------------------------------------

  double get _cellPitch =>
      (widget.size - 2 * GameGridState.gridPadding) / widget.gridSize;

  Offset _cellCenter(int row, int col) => Offset(
    GameGridState.gridPadding + (col + 0.5) * _cellPitch,
    GameGridState.gridPadding + (row + 0.5) * _cellPitch,
  );

  Offset _centroid(List<CellOffset> cells) {
    var x = 0.0;
    var y = 0.0;
    for (final cell in cells) {
      final point = _cellCenter(cell.row, cell.col);
      x += point.dx;
      y += point.dy;
    }
    return Offset(x / cells.length, y / cells.length);
  }

  Color _cellColor(int row, int col, int fallbackColorIndex) {
    var index = -1;
    if (row < _prevGridSnapshot.length &&
        col < _prevGridSnapshot[row].length) {
      index = _prevGridSnapshot[row][col];
    }
    if (index < 0) index = fallbackColorIndex;
    if (index >= 0 && index < blockColors.length) return blockColors[index];
    return _gold5;
  }

  // -- Ticker -------------------------------------------------------------

  void _ensureTicking() {
    if (_isFlutterTest || widget.reduceMotion) return;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    var dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Clamp large gaps (e.g. after a dropped frame) so effects don't jump.
    dt = math.min(dt, 0.05);

    for (final burst in _bursts) {
      burst.advance(dt);
    }
    _bursts.removeWhere((burst) => burst.isDead);
    if (_bursts.isEmpty) {
      _ticker.stop();
    }
    setState(() {});
  }

  void _addBurst(_Burst burst) {
    _bursts.add(burst);
    // Keep the effect stack bounded during very fast play.
    while (_bursts.length > 6) {
      _bursts.removeAt(0);
    }
    _ensureTicking();
    if (mounted) setState(() {});
  }

  // -- Placement: soft impact bloom + rising sparks -----------------------

  void _onPlace() {
    if (widget.reduceMotion || _isFlutterTest) return;
    final cells = widget.store.lastPlacedCells.toList(growable: false);
    if (cells.isEmpty) return;

    final colorIndex = widget.store.lastPlacedColorIndex.value;
    final baseColor = (colorIndex >= 0 && colorIndex < blockColors.length)
        ? blockColors[colorIndex]
        : blockColors.first;
    final tint = _streakTint(widget.store.streak.value, baseColor);

    final burst = _Burst(duration: 0.65);
    for (final cell in cells) {
      final center = _cellCenter(cell.row, cell.col);
      burst.glows.add(
        _Glow(
          center: center,
          color: tint,
          radius: _cellPitch * 1.25,
          delay: 0,
          life: 0.42,
          intensity: 0.55,
        ),
      );
      burst.sparks.addAll(
        _radialSparks(
          center,
          tint,
          count: 4,
          speedMin: 55,
          speedMax: 150,
          lifeMin: 0.28,
          lifeMax: 0.5,
          sizeMin: 1.4,
          sizeMax: 3.0,
          gravity: 140,
          drag: 3.4,
          additive: true,
        ),
      );
    }

    final centroid = _centroid(cells);
    final spread = _cellPitch * (1.35 + cells.length * 0.22);
    burst.rings.add(
      _Ring(
        center: centroid,
        color: tint,
        maxRadius: spread,
        width: 2.6,
        delay: 0,
        life: 0.42,
        intensity: 0.9,
      ),
    );
    burst.rings.add(
      _Ring(
        center: centroid,
        color: Colors.white,
        maxRadius: spread * 1.45,
        width: 1.4,
        delay: 0.06,
        life: 0.5,
        intensity: 0.55,
      ),
    );

    _addBurst(burst);
  }

  // -- Line clear: beams, shards, shockwaves ------------------------------

  void _onClear() {
    if (widget.reduceMotion || _isFlutterTest) return;
    final cells = widget.store.lastClearedCells.toList(growable: false);
    if (cells.isEmpty) return;

    final rowCounts = <int, int>{};
    final colCounts = <int, int>{};
    for (final cell in cells) {
      rowCounts.update(cell.row, (value) => value + 1, ifAbsent: () => 1);
      colCounts.update(cell.col, (value) => value + 1, ifAbsent: () => 1);
    }
    final fullRows = rowCounts.entries
        .where((entry) => entry.value >= widget.gridSize)
        .map((entry) => entry.key)
        .toList(growable: false);
    final fullCols = colCounts.entries
        .where((entry) => entry.value >= widget.gridSize)
        .map((entry) => entry.key)
        .toList(growable: false);

    final streak = widget.store.streak.value;
    final tint = streak >= 10
        ? _gold10
        : streak >= 5
        ? _gold5
        : streak >= 3
        ? _gold3
        : _iceWhite;
    final fallbackColorIndex = widget.store.lastPlacedColorIndex.value;

    final burst = _Burst(duration: 1.0);
    for (final cell in cells) {
      final center = _cellCenter(cell.row, cell.col);
      final color = _cellColor(cell.row, cell.col, fallbackColorIndex);
      final rect = Rect.fromCenter(
        center: center,
        width: _cellPitch * 0.94,
        height: _cellPitch * 0.94,
      );

      burst.flashes.add(
        _CellFlash(
          rect: rect,
          color: Color.lerp(color, Colors.white, 0.55)!,
          delay: 0,
          life: 0.18,
        ),
      );
      burst.glows.add(
        _Glow(
          center: center,
          color: color,
          radius: _cellPitch * 1.9,
          delay: 0.02,
          life: 0.55,
          intensity: 0.62,
        ),
      );
      burst.shards.addAll(
        _shards(center, color, count: 7, fallbackColor: tint),
      );
      burst.sparks.addAll(
        _radialSparks(
          center,
          Color.lerp(color, Colors.white, 0.65)!,
          count: 5,
          speedMin: 160,
          speedMax: 360,
          lifeMin: 0.25,
          lifeMax: 0.5,
          sizeMin: 1.2,
          sizeMax: 2.6,
          gravity: 220,
          drag: 2.2,
          additive: true,
        ),
      );
    }

    final gridSpan = widget.gridSize * _cellPitch;
    final gridCenter = GameGridState.gridPadding + gridSpan / 2;
    for (final row in fullRows) {
      burst.beams.add(
        _Beam(
          center: Offset(
            gridCenter,
            GameGridState.gridPadding + (row + 0.5) * _cellPitch,
          ),
          length: gridSpan,
          thickness: _cellPitch * 0.9,
          horizontal: true,
          color: tint,
          delay: 0,
          life: 0.55,
        ),
      );
    }
    for (final col in fullCols) {
      burst.beams.add(
        _Beam(
          center: Offset(
            GameGridState.gridPadding + (col + 0.5) * _cellPitch,
            gridCenter,
          ),
          length: gridSpan,
          thickness: _cellPitch * 0.9,
          horizontal: false,
          color: tint,
          delay: 0,
          life: 0.55,
        ),
      );
    }

    final centroid = _centroid(cells);
    final minCol = cells.map((cell) => cell.col).reduce(math.min);
    final maxCol = cells.map((cell) => cell.col).reduce(math.max);
    final minRow = cells.map((cell) => cell.row).reduce(math.min);
    final maxRow = cells.map((cell) => cell.row).reduce(math.max);
    final spanX = (maxCol - minCol + 1) * _cellPitch;
    final spanY = (maxRow - minRow + 1) * _cellPitch;
    final maxSpan = math.max(spanX, spanY);

    burst.rings.add(
      _Ring(
        center: centroid,
        color: tint,
        maxRadius: maxSpan * 0.85,
        width: 3.2,
        delay: 0,
        life: 0.5,
        intensity: 1.0,
      ),
    );
    burst.rings.add(
      _Ring(
        center: centroid,
        color: Colors.white,
        maxRadius: maxSpan * 1.15,
        width: 1.8,
        delay: 0.06,
        life: 0.65,
        intensity: 0.7,
      ),
    );
    burst.rings.add(
      _Ring(
        center: centroid,
        color: tint,
        maxRadius: maxSpan * 1.5,
        width: 1.2,
        delay: 0.14,
        life: 0.75,
        intensity: 0.45,
      ),
    );
    burst.glows.add(
      _Glow(
        center: centroid,
        color: tint,
        radius: maxSpan * 0.8,
        delay: 0,
        life: 0.3,
        intensity: 0.35,
      ),
    );

    _addBurst(burst);
  }

  // -- Particle factories -------------------------------------------------

  List<_Spark> _radialSparks(
    Offset center,
    Color color, {
    required int count,
    required double speedMin,
    required double speedMax,
    required double lifeMin,
    required double lifeMax,
    required double sizeMin,
    required double sizeMax,
    required double gravity,
    required double drag,
    required bool additive,
  }) {
    final sparks = <_Spark>[];
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = speedMin + _rng.nextDouble() * (speedMax - speedMin);
      final life = lifeMin + _rng.nextDouble() * (lifeMax - lifeMin);
      final size = sizeMin + _rng.nextDouble() * (sizeMax - sizeMin);
      final start =
          center +
          Offset(
            (_rng.nextDouble() - 0.5) * _cellPitch * 0.35,
            (_rng.nextDouble() - 0.5) * _cellPitch * 0.35,
          );
      sparks.add(
        _Spark(
          position: start,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          life: life,
          size: size,
          color: color,
          spin: 0,
          spinSpeed: 0,
          drag: drag,
          gravity: gravity,
          additive: additive,
          shard: false,
        ),
      );
    }
    return sparks;
  }

  List<_Spark> _shards(
    Offset center,
    Color color, {
    required int count,
    required Color fallbackColor,
  }) {
    final shards = <_Spark>[];
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 90 + _rng.nextDouble() * 210;
      final life = 0.5 + _rng.nextDouble() * 0.35;
      final size = _cellPitch * (0.16 + _rng.nextDouble() * 0.14);
      final start =
          center +
          Offset(
            (_rng.nextDouble() - 0.5) * _cellPitch * 0.5,
            (_rng.nextDouble() - 0.5) * _cellPitch * 0.5,
          );
      shards.add(
        _Spark(
          position: start,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          life: life,
          size: size,
          color: _rng.nextDouble() < 0.25
              ? fallbackColor
              : Color.lerp(color, Colors.white, 0.22)!,
          spin: _rng.nextDouble() * math.pi,
          spinSpeed: (_rng.nextDouble() - 0.5) * 16,
          drag: 0.9,
          gravity: 640,
          additive: false,
          shard: true,
        ),
      );
    }
    return shards;
  }

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Capture the grid as it is *now*. When the store clears lines it does so
    // inside an action, and the clear reaction fires before the next rebuild,
    // so it still sees this pre-clear snapshot.
    _prevGridSnapshot = widget.store.engine.grid
        .map((row) => List<int>.from(row))
        .toList(growable: false);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _EffectsPainter(_bursts),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Effect data
// ---------------------------------------------------------------------------

class _Burst {
  _Burst({required this.duration});

  final double duration;
  double age = 0;

  final List<_Glow> glows = [];
  final List<_Ring> rings = [];
  final List<_Beam> beams = [];
  final List<_CellFlash> flashes = [];
  final List<_Spark> sparks = [];
  final List<_Spark> shards = [];

  bool get isDead => age >= duration;

  void advance(double dt) {
    age += dt;
    for (final glow in glows) {
      glow.age += dt;
    }
    for (final ring in rings) {
      ring.age += dt;
    }
    for (final beam in beams) {
      beam.age += dt;
    }
    for (final flash in flashes) {
      flash.age += dt;
    }
    for (final spark in sparks) {
      spark.advance(dt);
    }
    for (final shard in shards) {
      shard.advance(dt);
    }
  }
}

class _Glow {
  _Glow({
    required this.center,
    required this.color,
    required this.radius,
    required this.delay,
    required this.life,
    required this.intensity,
  });

  final Offset center;
  final Color color;
  final double radius;
  final double delay;
  final double life;
  final double intensity;
  double age = 0;

  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
}

class _Ring {
  _Ring({
    required this.center,
    required this.color,
    required this.maxRadius,
    required this.width,
    required this.delay,
    required this.life,
    required this.intensity,
  });

  final Offset center;
  final Color color;
  final double maxRadius;
  final double width;
  final double delay;
  final double life;
  final double intensity;
  double age = 0;

  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
}

class _Beam {
  _Beam({
    required this.center,
    required this.length,
    required this.thickness,
    required this.horizontal,
    required this.color,
    required this.delay,
    required this.life,
  });

  final Offset center;
  final double length;
  final double thickness;
  final bool horizontal;
  final Color color;
  final double delay;
  final double life;
  double age = 0;

  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
}

class _CellFlash {
  _CellFlash({
    required this.rect,
    required this.color,
    required this.delay,
    required this.life,
  });

  final Rect rect;
  final Color color;
  final double delay;
  final double life;
  double age = 0;

  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
}

class _Spark {
  _Spark({
    required this.position,
    required this.velocity,
    required this.life,
    required this.size,
    required this.color,
    required this.spin,
    required this.spinSpeed,
    required this.drag,
    required this.gravity,
    required this.additive,
    required this.shard,
  });

  Offset position;
  Offset velocity;
  final double life;
  final double size;
  final Color color;
  double spin;
  final double spinSpeed;
  final double drag;
  final double gravity;
  final bool additive;
  final bool shard;
  double age = 0;

  double get progress => (age / life).clamp(0.0, 1.0);

  void advance(double dt) {
    if (age >= life) return;
    age += dt;
    final damp = math.exp(-drag * dt);
    velocity = Offset(
      velocity.dx * damp,
      velocity.dy * damp + gravity * dt,
    );
    position += velocity * dt;
    spin += spinSpeed * dt;
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _EffectsPainter extends CustomPainter {
  _EffectsPainter(this.bursts);

  final List<_Burst> bursts;

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in bursts) {
      for (final glow in burst.glows) {
        _paintGlow(canvas, glow);
      }
      for (final beam in burst.beams) {
        _paintBeam(canvas, beam);
      }
      for (final flash in burst.flashes) {
        _paintFlash(canvas, flash);
      }
      for (final ring in burst.rings) {
        _paintRing(canvas, ring);
      }
      for (final shard in burst.shards) {
        _paintShard(canvas, shard);
      }
      for (final spark in burst.sparks) {
        _paintSpark(canvas, spark);
      }
    }
  }

  void _paintGlow(Canvas canvas, _Glow glow) {
    final t = glow.progress;
    if (t <= 0 || t >= 1) return;
    final fade = math.pow(1 - t, 1.7).toDouble();
    final radius = glow.radius * (0.5 + 0.7 * Curves.easeOutQuad.transform(t));
    if (radius <= 0) return;
    final core = Color.lerp(glow.color, Colors.white, 0.45)!;
    final shader = ui.Gradient.radial(
      glow.center,
      radius,
      [
        core.withValues(alpha: glow.intensity * fade),
        glow.color.withValues(alpha: glow.intensity * 0.45 * fade),
        glow.color.withValues(alpha: 0),
      ],
      const [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(
      glow.center,
      radius,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  void _paintBeam(Canvas canvas, _Beam beam) {
    final t = beam.progress;
    if (t <= 0 || t >= 1) return;
    final sweep = Curves.easeOutCubic.transform(math.min(1.0, t * 1.7));
    final fade = math.pow(1 - t, 1.6).toDouble();
    final length = beam.length * sweep;
    final thickness = beam.thickness * (0.55 + 0.45 * (1 - t));
    if (length < 1 || thickness <= 0) return;

    final rect = beam.horizontal
        ? Rect.fromCenter(
            center: beam.center,
            width: length,
            height: thickness,
          )
        : Rect.fromCenter(
            center: beam.center,
            width: thickness,
            height: length,
          );
    final from = beam.horizontal ? rect.centerLeft : rect.topCenter;
    final to = beam.horizontal ? rect.centerRight : rect.bottomCenter;
    final core = Color.lerp(beam.color, Colors.white, 0.65)!;

    final shader = ui.Gradient.linear(from, to, [
      beam.color.withValues(alpha: 0),
      beam.color.withValues(alpha: 0.35 * fade),
      core.withValues(alpha: 0.95 * fade),
      beam.color.withValues(alpha: 0.35 * fade),
      beam.color.withValues(alpha: 0),
    ], const [0.0, 0.2, 0.5, 0.8, 1.0]);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final coreThickness = math.max(1.0, thickness * 0.28);
    final coreRect = beam.horizontal
        ? Rect.fromCenter(
            center: beam.center,
            width: length,
            height: coreThickness,
          )
        : Rect.fromCenter(
            center: beam.center,
            width: coreThickness,
            height: length,
          );
    final coreShader = ui.Gradient.linear(from, to, [
      Colors.white.withValues(alpha: 0),
      Colors.white.withValues(alpha: 0.9 * fade),
      Colors.white.withValues(alpha: 0),
    ], const [0.0, 0.5, 1.0]);
    canvas.drawRect(
      coreRect,
      Paint()
        ..shader = coreShader
        ..blendMode = BlendMode.plus,
    );
  }

  void _paintFlash(Canvas canvas, _CellFlash flash) {
    final t = flash.progress;
    if (t <= 0 || t >= 1) return;
    final fade = math.pow(1 - t, 2.0).toDouble();
    final scale = 1.0 + 0.18 * Curves.easeOut.transform(t);
    final rect = Rect.fromCenter(
      center: flash.rect.center,
      width: flash.rect.width * scale,
      height: flash.rect.height * scale,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(flash.rect.width * 0.22),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = flash.color.withValues(alpha: 0.85 * fade)
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _paintRing(Canvas canvas, _Ring ring) {
    final t = ring.progress;
    if (t <= 0 || t >= 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final radius = ring.maxRadius * eased;
    if (radius <= 0) return;
    final fade = (1 - t) * (1 - t);
    final alpha = fade * ring.intensity;
    final strokeWidth = ring.width * (1 - 0.6 * t);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.6
      ..color = ring.color.withValues(alpha: alpha * 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..blendMode = BlendMode.plus;
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Color.lerp(
        ring.color,
        Colors.white,
        0.45,
      )!.withValues(alpha: alpha)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(ring.center, radius, glowPaint);
    canvas.drawCircle(ring.center, radius, corePaint);
  }

  void _paintSpark(Canvas canvas, _Spark spark) {
    final t = spark.progress;
    if (t <= 0 || t >= 1) return;
    final fade = math.pow(1 - t, 1.5).toDouble();
    final radius = spark.size * (0.7 + 0.5 * t);
    final paint = Paint()
      ..color = spark.color.withValues(alpha: fade)
      ..blendMode = spark.additive ? BlendMode.plus : BlendMode.srcOver;
    if (spark.additive) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    }
    canvas.drawCircle(spark.position, radius, paint);
  }

  void _paintShard(Canvas canvas, _Spark spark) {
    final t = spark.progress;
    if (t <= 0 || t >= 1) return;
    final fade = math.pow(1 - t, 1.8).toDouble();

    canvas.save();
    canvas.translate(spark.position.dx, spark.position.dy);
    canvas.rotate(spark.spin);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: spark.size * 1.5,
      height: spark.size * 0.8,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(spark.size * 0.28),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = spark.color.withValues(alpha: 0.95 * fade),
    );

    final highlight = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -spark.size * 0.18),
        width: spark.size * 1.1,
        height: spark.size * 0.24,
      ),
      Radius.circular(spark.size * 0.12),
    );
    canvas.drawRRect(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.55 * fade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EffectsPainter oldDelegate) => true;
}
