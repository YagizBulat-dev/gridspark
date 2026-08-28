import 'package:flutter/material.dart';

import '../../domain/game_engine.dart';
import '../../domain/game_models.dart';
import 'block_shape_view.dart';

class GameGrid extends StatefulWidget {
  const GameGrid({
    super.key,
    required this.engine,
    required this.size,
    required this.shapes,
    required this.onDrop,
    required this.clearedCells,
    required this.placedCells,
    required this.clearAnimationKey,
    required this.reduceMotion,
    required this.onInvalidDrop,
  });

  final GameEngine engine;
  final double size;
  final List<BlockShape?> shapes;
  final bool Function(int, int, int) onDrop;
  final List<CellOffset> clearedCells;
  final List<CellOffset> placedCells;
  final int clearAnimationKey;
  final bool reduceMotion;
  final void Function(int trayIndex) onInvalidDrop;

  @override
  State<GameGrid> createState() => GameGridState();
}

class GameGridState extends State<GameGrid> with TickerProviderStateMixin {
  int? hoverTrayIndex;
  int? hoverRow;
  int? hoverCol;
  bool hoverValid = false;
  bool showClearFlash = false;
  final Set<CellOffset> _appearingCells = {};

  /// Must match the `padding` used by the grid container in [build].
  static const double gridPadding = 3.0;

  final GlobalKey _gridContainerKey = GlobalKey();

  // --- Line-clear flash effect ---
  late final AnimationController _clearFlashController;
  late final Animation<double> _clearFlashAnimation;

  /// Sürüklenen bloğun parmaktan kaç hücre yukarıda gösterileceği.
  /// HEM render offset'i (game_screen'deki feedback) HEM ghost/snap hesaplaması
  /// (computeGhostCell) bu sabiti kullanmalı; iki yerde farklı değer kullanmak
  /// kalibrasyon kaymasına yol açar.
  static const double liftCells = 1.2;

  @override
  void initState() {
    super.initState();
    _clearFlashController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _clearFlashAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _clearFlashController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _clearFlashController.dispose();
    super.dispose();
  }

  /// Clears any active ghost preview. Safe to call when no preview is shown.
  void clearHover() => _clearHover();

  @override
  void didUpdateWidget(covariant GameGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Track newly placed cells for drop/settle animation (Animation 1).
    if (widget.clearAnimationKey != oldWidget.clearAnimationKey &&
        widget.placedCells.isNotEmpty) {
      if (widget.reduceMotion) {
        // Immediately add then remove — no animation.
      } else {
        _appearingCells.addAll(widget.placedCells);
        final animKey = widget.clearAnimationKey;
        Future<void>.delayed(const Duration(milliseconds: 130), () {
          if (mounted && widget.clearAnimationKey == animKey) {
            setState(() {
              for (final cell in widget.placedCells) {
                _appearingCells.remove(cell);
              }
            });
          }
        });
        setState(() {});
      }
    }

    // Line-clear flash + scale-down (Animation 3): 250ms timer.
    if (widget.clearAnimationKey != oldWidget.clearAnimationKey &&
        widget.clearedCells.isNotEmpty) {
      if (widget.reduceMotion) {
        showClearFlash = false;
        return;
      }

      // --- Flash effect ---
      final flashKey = widget.clearAnimationKey;
      showClearFlash = true;
      _clearFlashController.forward(from: 0).then((_) {
        // Flash done — keep showClearFlash true so the scale-down/fade
        // (Animation 3) still renders for the remaining 150 ms.
      });
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted && widget.clearAnimationKey == flashKey) {
          setState(() => showClearFlash = false);
        }
      });
    }
  }

  // --- ghost position computation ---
  (int, int) _ghostPosition(Offset globalOffset) {
    final gridBox =
        _gridContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return (0, 0);
    final local = gridBox.globalToLocal(globalOffset);
    return computeGhostCell(
      local,
      size: widget.size,
      gridSize: widget.engine.size,
      padding: gridPadding,
    );
  }

  /// Pure snap math used by [_ghostPosition]. Given a pointer position in the
  /// grid container's *local* coordinate space (which already includes the
  /// [padding] border), returns the grid (row, col) the block's anchor cell
  /// should snap to. The block is rendered [liftCells] cells ABOVE the finger.
  ///
  /// Uses [liftCells] constant so the drag feedback offset in game_screen
  /// and this function always stay in sync. The `.round()` method rounds to the
  /// nearest integer (halfway cases round away from zero), ensuring consistent
  /// snapping behavior without systematic floor bias.
  static (int, int) computeGhostCell(
    Offset local, {
    required double size,
    required int gridSize,
    required double padding,
  }) {
    // The grid container has [padding] on every side, so the actual cell
    // pitch is (size - 2*padding) / gridSize, and cell coordinates are offset
    // by that padding inside the container's local space.
    final pitch = cellPitch(size, padding, gridSize);
    // Block is rendered liftCells cells ABOVE the finger.
    final offsetY = pitch * liftCells;
    final localX = local.dx - padding;
    final localY = local.dy - padding - offsetY;
    final ghostCol = (localX / pitch).round();
    final ghostRow = (localY / pitch).round();
    return (ghostRow, ghostCol);
  }

  /// The size of a single grid cell in logical pixels. This is the
  /// *padding-aware* pitch (the cell area is [size] minus the [padding] border
  /// on both sides), NOT the naive [size]/[gridSize]. Both the ghost preview
  /// ([computeGhostCell]) and the drag feedback in [game_screen] must use this
  /// exact value so the floating piece aligns with the snapped preview.
  static double cellPitch(double size, double padding, int gridSize) =>
      (size - 2 * padding) / gridSize;

  void _updateHover(int trayIndex, int row, int col) {
    final validIndex = trayIndex >= 0 && trayIndex < widget.shapes.length;
    setState(() {
      hoverTrayIndex = trayIndex;
      hoverRow = row;
      hoverCol = col;
      hoverValid =
          validIndex &&
          widget.shapes[trayIndex] != null &&
          widget.engine.canPlace(widget.shapes[trayIndex]!, row, col);
    });
  }

  void _clearHover() {
    if (hoverTrayIndex == null) return;
    setState(() {
      hoverTrayIndex = null;
      hoverRow = null;
      hoverCol = null;
      hoverValid = false;
    });
  }

  BlockShape? get hoverShape {
    if (hoverTrayIndex == null ||
        hoverTrayIndex! < 0 ||
        hoverTrayIndex! >= widget.shapes.length) {
      return null;
    }
    return widget.shapes[hoverTrayIndex!];
  }

  bool _isInPreview(int row, int col) {
    final shape = hoverShape;
    final anchorRow = hoverRow;
    final anchorCol = hoverCol;
    if (shape == null || anchorRow == null || anchorCol == null) return false;
    return shape.cells.any(
      (cell) => anchorRow + cell.row == row && anchorCol + cell.col == col,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cell = cellPitch(widget.size, gridPadding, widget.engine.size);

    // Update previous-grid snapshot at the END of build so it reflects the
    // current state (which will become "previous" by the next didUpdateWidget).
    // We copy it AFTER rendering so didUpdateWidget still sees the old values
    // for colour look-up.
    final children = <Widget>[
      Container(
        key: _gridContainerKey,
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(gridPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.engine.size * widget.engine.size,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.engine.size,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ widget.engine.size;
            final col = index % widget.engine.size;
            final value = widget.engine.grid[row][col];
            final inPreview = _isInPreview(row, col);
            final clearing =
                showClearFlash &&
                widget.clearedCells.contains(CellOffset(row, col));
            final appearing = _appearingCells.contains(CellOffset(row, col));
            return Semantics(
              label: value >= 0
                  ? 'Row ${row + 1}, column ${col + 1}, occupied'
                  : inPreview
                  ? (hoverValid
                        ? 'Row ${row + 1}, column ${col + 1}, valid placement'
                        : 'Row ${row + 1}, column ${col + 1}, invalid placement')
                  : 'Row ${row + 1}, column ${col + 1}, empty',
              child: DragTarget<int>(
                onWillAcceptWithDetails: (details) {
                  final (gr, gc) = _ghostPosition(details.offset);
                  _updateHover(details.data, gr, gc);
                  return hoverValid;
                },
                onMove: (details) {
                  final (gr, gc) = _ghostPosition(details.offset);
                  _updateHover(details.data, gr, gc);
                },
                onLeave: (_) => _clearHover(),
                onAcceptWithDetails: (details) {
                  final (gr, gc) = _ghostPosition(details.offset);
                  final accepted = widget.onDrop(details.data, gr, gc);
                  if (!accepted) widget.onInvalidDrop(details.data);
                  _clearHover();
                },
                builder: (context, candidates, rejects) {
                  Widget cellDecoration = Container(
                    decoration: BoxDecoration(
                      color: clearing
                          ? Theme.of(context).colorScheme.tertiary
                          : value >= 0
                          ? blockColors[value]
                          : inPreview
                          ? (hoverValid
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .42)
                                : Theme.of(
                                    context,
                                  ).colorScheme.error.withValues(alpha: .42))
                          : Theme.of(context).colorScheme.surface,
                      border: inPreview
                          ? Border.all(
                              color: hoverValid
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                              width: 1.5,
                            )
                          : Border.all(
                              color: Colors.black.withValues(alpha: .08),
                              width: 1,
                            ),
                      borderRadius: BorderRadius.circular(cell * .16),
                    ),
                  );

                  // Animation 1: drop/settle for newly placed cells —
                  // enhanced pop: scale 0.2→1.3→1.0 with overshoot.
                  if (appearing && !widget.reduceMotion) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOutBack,
                      builder: (context, val, _) {
                        // Enhanced pop: overshoot then settle
                        final scale = 0.2 + 1.1 * val;
                        final opacity = val.clamp(0.0, 1.0);
                        final offset = (1 - val) * 8.0;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: cellDecoration,
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // Animation 3: line-clear flash with scale-down + fade.
                  if (clearing && !widget.reduceMotion) {
                    return AnimatedScale(
                      scale: clearing ? 0.4 : 1,
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeInOut,
                      child: AnimatedOpacity(
                        opacity: clearing ? 0 : 1,
                        duration: const Duration(milliseconds: 110),
                        child: cellDecoration,
                      ),
                    );
                  }

                  return cellDecoration;
                },
              ),
            );
          },
        ),
      ),
    ];

    // Flash overlay — white highlight on cleared cells during the first 100ms.
    if (showClearFlash && !widget.reduceMotion) {
      children.add(
        AnimatedBuilder(
          animation: _clearFlashAnimation,
          builder: (context, _) {
            final flashValue = (1.0 - _clearFlashAnimation.value).clamp(
              0.0,
              1.0,
            );
            return IgnorePointer(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _FlashPainter(
                    clearedCells: widget.clearedCells,
                    cellSize: cell,
                    gridPadding: gridPadding,
                    flashAlpha: flashValue * 0.6,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(children: children);
  }
}

/// Custom painter that draws a white flash overlay on cleared cells.
class _FlashPainter extends CustomPainter {
  _FlashPainter({
    required this.clearedCells,
    required this.cellSize,
    required this.gridPadding,
    required this.flashAlpha,
  });

  final List<CellOffset> clearedCells;
  final double cellSize;
  final double gridPadding;
  final double flashAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (flashAlpha <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final cell in clearedCells) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          gridPadding + cell.col * cellSize,
          gridPadding + cell.row * cellSize,
          cellSize,
          cellSize,
        ),
        Radius.circular(cellSize * 0.16),
      );
      paint.color = Colors.white.withValues(alpha: flashAlpha);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlashPainter old) =>
      old.flashAlpha != flashAlpha;
}
