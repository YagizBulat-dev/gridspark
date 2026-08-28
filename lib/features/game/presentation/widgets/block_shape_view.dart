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
  });

  final BlockShape shape;
  final double cellSize;

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
              decoration: BoxDecoration(
                color: blockColors[shape.colorIndex],
                border: Border.all(
                  color: Colors.black.withValues(alpha: .18),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: blockColors[shape.colorIndex].withValues(alpha: .35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
