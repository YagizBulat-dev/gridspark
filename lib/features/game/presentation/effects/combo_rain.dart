import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobx/mobx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/game_store.dart';

/// Skip animation tickers under `flutter test` so pumpAndSettle can finish.
bool get _isFlutterTest => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

/// Full-screen celebration layer: every line clear makes confetti and sparks
/// rain down the screen. The shower grows with the number of lines cleared
/// and the current combo streak, so chaining combos feels better and better.
///
/// Visual only: never intercepts touches.
class ComboRain extends StatefulWidget {
  const ComboRain({super.key, required this.store, required this.reduceMotion});

  final GameStore store;
  final bool reduceMotion;

  @override
  State<ComboRain> createState() => _ComboRainState();
}

class _ComboRainState extends State<ComboRain>
    with SingleTickerProviderStateMixin {
  static const int _maxPieces = 320;
  static const _palette = <Color>[
    AppColors.cyan,
    AppColors.violet,
    AppColors.amber,
    AppColors.magenta,
    Color(0xFFFFFFFF),
    Color(0xFFFFD166),
    Color(0xFF3DDC97),
  ];

  late final Ticker _ticker;
  ReactionDisposer? _disposer;
  final math.Random _rng = math.Random();
  final List<_Piece> _pieces = [];
  Size _size = Size.zero;
  double _flash = 0;
  Color _flashColor = AppColors.cyan;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _subscribe();
  }

  @override
  void didUpdateWidget(ComboRain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      _disposer?.call();
      _pieces.clear();
      _subscribe();
    }
  }

  void _subscribe() {
    _disposer = reaction((_) => widget.store.comboPopupTrigger.value, (t) {
      if (t > 0) _emit();
    });
  }

  @override
  void dispose() {
    _disposer?.call();
    _ticker.dispose();
    super.dispose();
  }

  void _emit() {
    if (widget.reduceMotion || _isFlutterTest || _size.isEmpty) return;
    final lines = widget.store.lastClearedLines.value;
    final streak = widget.store.streak.value;
    if (lines <= 0) return;

    // More lines and a longer streak = a much bigger shower.
    final big = lines >= 3 || streak >= 5;
    final count = (26 + lines * 22 + streak * 9).clamp(30, 170);
    final goldBias = big ? 0.45 : 0.15;

    for (var i = 0; i < count; i++) {
      final spark = _rng.nextDouble() < 0.28;
      final gold = _rng.nextDouble() < goldBias;
      final color = gold
          ? const Color(0xFFFFD166)
          : _palette[_rng.nextInt(_palette.length)];
      _pieces.add(
        _Piece(
          delay: _rng.nextDouble() * (big ? 0.7 : 0.45),
          x: _rng.nextDouble() * _size.width,
          y: -16 - _rng.nextDouble() * 80,
          vx: (_rng.nextDouble() - 0.5) * 140,
          vy: 240 + _rng.nextDouble() * 360,
          size: spark
              ? 2.2 + _rng.nextDouble() * 3.2
              : 6 + _rng.nextDouble() * 7,
          rot: _rng.nextDouble() * math.pi * 2,
          rotSpeed: (_rng.nextDouble() - 0.5) * 14,
          swayPhase: _rng.nextDouble() * math.pi * 2,
          swayFreq: 2 + _rng.nextDouble() * 3,
          swayAmp: 12 + _rng.nextDouble() * 26,
          color: color,
          spark: spark,
        ),
      );
    }
    while (_pieces.length > _maxPieces) {
      _pieces.removeAt(0);
    }
    if (lines >= 2) {
      _flash = math.max(_flash, math.min(0.34, 0.12 * lines));
      _flashColor = big ? const Color(0xFFFFD166) : AppColors.cyan;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    var dt = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 0.05);

    for (final p in _pieces) {
      p.advance(dt);
    }
    _pieces.removeWhere((p) => p.y > _size.height + 40 || p.age > 3.2);
    _flash = math.max(0, _flash - dt * 1.7);

    if (_pieces.isEmpty && _flash <= 0) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      return IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: _size,
            painter: _RainPainter(_pieces, _flash, _flashColor),
          ),
        ),
      );
    },
  );
}

class _Piece {
  _Piece({
    required this.delay,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rot,
    required this.rotSpeed,
    required this.swayPhase,
    required this.swayFreq,
    required this.swayAmp,
    required this.color,
    required this.spark,
  });

  double delay;
  double x;
  double y;
  final double vx;
  double vy;
  final double size;
  double rot;
  final double rotSpeed;
  final double swayPhase;
  final double swayFreq;
  final double swayAmp;
  final Color color;
  final bool spark;
  double age = 0;

  bool get active => delay <= 0;

  void advance(double dt) {
    if (delay > 0) {
      delay -= dt;
      return;
    }
    age += dt;
    vy += 220 * dt; // gravity
    y += vy * dt;
    x += vx * dt + math.cos(age * swayFreq + swayPhase) * swayAmp * dt;
    rot += rotSpeed * dt;
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.pieces, this.flash, this.flashColor);

  final List<_Piece> pieces;
  final double flash;
  final Color flashColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (flash > 0) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.1),
            radius: 1.0,
            colors: [
              flashColor.withValues(alpha: flash),
              flashColor.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final fill = Paint();
    final glow = Paint()..blendMode = BlendMode.plus;
    for (final p in pieces) {
      if (!p.active) continue;
      // Fade in quickly, fade out near the end of life.
      final fadeIn = math.min(1.0, p.age / 0.12);
      final fadeOut = p.age > 2.4 ? math.max(0.0, (3.2 - p.age) / 0.8) : 1.0;
      final alpha = (fadeIn * fadeOut).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      if (p.spark) {
        glow.color = p.color.withValues(alpha: 0.85 * alpha);
        canvas.drawCircle(Offset(p.x, p.y), p.size, glow);
        glow.color = Colors.white.withValues(alpha: 0.9 * alpha);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 0.45, glow);
      } else {
        fill.color = p.color.withValues(alpha: alpha);
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rot);
        // Tumbling confetti: squash the rectangle as it "flips".
        final flip = math.cos(p.rot * 1.7).abs() * 0.8 + 0.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55 * flip,
            ),
            const Radius.circular(1.5),
          ),
          fill,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => true;
}
