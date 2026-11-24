import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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

class GameGridState extends State<GameGrid> {
  int? hoverTrayIndex;
  int? hoverRow;
  int? hoverCol;
  bool hoverValid = false;
  final Set<CellOffset> _appearingCells = {};

  /// Must match the `padding` used by the grid container in [build].
  static const double gridPadding = 3.0;

  final GlobalKey _gridContainerKey = GlobalKey();

  /// In Block Blast, the bottom of the dragged piece is lifted above the touch point.
  static const double liftOffset = 60.0;

  Set<int> _previewRows = {};
  Set<int> _previewCols = {};

  /// Clears any active ghost preview. Safe to call when no preview is shown.
  void clearHover() => _clearHover();

  /// Updates hover from a global drag offset (used by external hit areas).
  void updateHoverFromGlobal(Offset globalOffset, int trayIndex) {
    final (gr, gc) = _ghostPosition(globalOffset);
    _updateHover(trayIndex, gr, gc);
  }

  /// Accepts a drop from a global drag offset. Returns whether placed.
  bool acceptDropFromGlobal(Offset globalOffset, int trayIndex) {
    final (gr, gc) = _ghostPosition(globalOffset);
    final accepted = widget.onDrop(trayIndex, gr, gc);
    if (!accepted) widget.onInvalidDrop(trayIndex);
    _clearHover();
    return accepted;
  }

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

  /// Pure snap math used by [_ghostPosition]. Given the top-left position of the
  /// floating piece in the grid container's local coordinate space,
  /// returns the grid (row, col) the block's anchor cell snaps to.
  static (int, int) computeGhostCell(
    Offset local, {
    required double size,
    required int gridSize,
    required double padding,
  }) {
    final pitch = cellPitch(size, padding, gridSize);
    final localX = local.dx - padding;
    // Partial lift compensation: makes bottom rows reachable while keeping
    // the ghost close to the lifted feedback.
    final localY = local.dy - padding + (liftOffset * 0.6);
    final ghostCol = (localX / pitch).round().clamp(0, gridSize - 1);
    final ghostRow = (localY / pitch).round().clamp(0, gridSize - 1);
    return (ghostRow, ghostCol);
  }

  /// The size of a single grid cell in logical pixels.
  static double cellPitch(double size, double padding, int gridSize) =>
      (size - 2 * padding) / gridSize;

  void _updateHover(int trayIndex, int row, int col) {
    final validIndex = trayIndex >= 0 && trayIndex < widget.shapes.length;
    final shape = validIndex ? widget.shapes[trayIndex] : null;
    final isValid =
        validIndex && shape != null && widget.engine.canPlace(shape, row, col);

    final pRows = <int>{};
    final pCols = <int>{};

    if (isValid) {
      final shapeCells = <CellOffset>{
        for (final c in shape.cells) CellOffset(row + c.row, col + c.col),
      };

      for (var r = 0; r < widget.engine.size; r++) {
        var full = true;
        for (var c = 0; c < widget.engine.size; c++) {
          if (widget.engine.grid[r][c] < 0 &&
              !shapeCells.contains(CellOffset(r, c))) {
            full = false;
            break;
          }
        }
        if (full) pRows.add(r);
      }

      for (var c = 0; c < widget.engine.size; c++) {
        var full = true;
        for (var r = 0; r < widget.engine.size; r++) {
          if (widget.engine.grid[r][c] < 0 &&
              !shapeCells.contains(CellOffset(r, c))) {
            full = false;
            break;
          }
        }
        if (full) pCols.add(c);
      }
    }

    setState(() {
      hoverTrayIndex = trayIndex;
      hoverRow = row;
      hoverCol = col;
      hoverValid = isValid;
      _previewRows = pRows;
      _previewCols = pCols;
    });
  }

  void _clearHover() {
    if (hoverTrayIndex == null) return;
    setState(() {
      hoverTrayIndex = null;
      hoverRow = null;
      hoverCol = null;
      hoverValid = false;
      _previewRows = {};
      _previewCols = {};
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

    final children = <Widget>[
      DragTarget<int>(
        onWillAcceptWithDetails: (details) => true,
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
          return Container(
            key: _gridContainerKey,
            width: widget.size,
            height: widget.size,
            padding: const EdgeInsets.all(gridPadding),
            decoration: BoxDecoration(
              color: AppColors.deck.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.22),
                  blurRadius: 28,
                ),
              ],
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
                final willBlast =
                    _previewRows.contains(row) || _previewCols.contains(col);
                final appearing = _appearingCells.contains(
                  CellOffset(row, col),
                );

                final isOccupied = value >= 0;
                final shapeColor = isOccupied
                    ? blockColors[value]
                    : (hoverShape != null
                          ? blockColors[hoverShape!.colorIndex]
                          : Theme.of(context).colorScheme.primary);

                Widget cellBody;

                if (isOccupied) {
                  // Premium 3D Candy/Jewel Block Tile
                  cellBody = Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cell * 0.20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(shapeColor, Colors.white, 0.30)!,
                                shapeColor,
                                Color.lerp(shapeColor, Colors.black, 0.28)!,
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.26),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: shapeColor.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Glassy highlight on top
                      Positioned(
                        top: 1.5,
                        left: 2.5,
                        right: 2.5,
                        height: cell * 0.35,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cell * 0.14),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (inPreview) {
                  // Hover Ghost Preview
                  cellBody = DecoratedBox(
                    decoration: BoxDecoration(
                      color: hoverValid
                          ? shapeColor.withValues(alpha: 0.65)
                          : Theme.of(context).colorScheme.error
                                .withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(cell * 0.20),
                      border: Border.all(
                        color: hoverValid
                            ? Colors.white.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.error,
                        width: 1.8,
                      ),
                      boxShadow: hoverValid
                          ? [
                              BoxShadow(
                                color: shapeColor.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  );
                } else if (willBlast) {
                  // Upcoming Line Clear Blast Highlight
                  cellBody = DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(cell * 0.18),
                      border: Border.all(color: AppColors.cyan, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                } else {
                  // Empty Sunken Board Slot
                  cellBody = DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.well,
                      borderRadius: BorderRadius.circular(cell * 0.2),
                      border: Border.all(
                        color: AppColors.cellBorder,
                        width: 1.0,
                      ),
                    ),
                  );
                }

                final Widget cellDecoration = Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: cellBody,
                );

                // Newly placed cells settle in with a soft, premium pop.
                if (appearing && !widget.reduceMotion) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      final pop = Curves.easeOutBack.transform(val);
                      final scale = 0.82 + 0.18 * pop;
                      final opacity = val.clamp(0.0, 1.0);
                      final offset = (1 - val) * 5.0;
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

                return cellDecoration;
              },
            ),
          );
        },
      ),
    ];

    return Stack(children: children);
  }
}
