import 'package:flutter/material.dart';

import '../../domain/game_models.dart';

const blockColors = [
  Color(0xFF7C5CFF),
  Color(0xFF26D7B7),
  Color(0xFFFFB84D),
  Color(0xFFFF6577),
  Color(0xFF4CB5FF),
  Color(0xFFC76CFF),
  Color(0xFF8AC926),
  Color(0xFFFF7A45),
];

class BlockShapeView extends StatelessWidget {
  const BlockShapeView({
    super.key,
    required this.shape,
    required this.cellSize,
    this.isDragging = false,
  });

  final BlockShape shape;
  final double cellSize;
  final bool isDragging;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: shape.width * cellSize,
    height: shape.height * cellSize,
    child: Stack(
      children: [
        for (final cell in shape.cells)
          Positioned(
            left: cell.col * cellSize,
            top: cell.row * cellSize,
            child: Container(
              width: cellSize,
              height: cellSize,
              padding: EdgeInsets.all(cellSize * 0.04),
              child: Stack(
                children: [
                  // Main 3D Gem Body
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cellSize * 0.22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(blockColors[shape.colorIndex], Colors.white, 0.32)!,
                            blockColors[shape.colorIndex],
                            Color.lerp(blockColors[shape.colorIndex], Colors.black, 0.28)!,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDragging ? 0.45 : 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: blockColors[shape.colorIndex].withValues(
                              alpha: isDragging ? 0.65 : 0.38,
                            ),
                            blurRadius: isDragging ? 12 : 5,
                            offset: isDragging ? const Offset(0, 6) : const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Glassy top-highlight gloss
                  Positioned(
                    top: 1.5,
                    left: 2.5,
                    right: 2.5,
                    height: cellSize * 0.35,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cellSize * 0.16),
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
              ),
            ),
          ),
      ],
    ),
  );
}
