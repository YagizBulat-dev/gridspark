import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/domain/block_generator.dart';
import 'package:gridspark/features/game/domain/game_models.dart';

void main() {
  group('BlockGenerator', () {
    test('generates three shapes for classic mode', () {
      final generator = BlockGenerator(random: Random(42));
      final tray = generator.generateTray(GameMode.classic);
      expect(tray, hasLength(3));
      expect(tray.map((s) => s.id).toSet(), hasLength(3));
    });

    test('generates three shapes for time attack mode', () {
      final generator = BlockGenerator(random: Random(42));
      final tray = generator.generateTray(GameMode.timed);
      expect(tray, hasLength(3));
      // Timed mode requires >= 2 cells
      expect(tray.every((s) => s.cells.length >= 2), isTrue);
    });

    test('rising mode at default maxCells filters by maxCells', () {
      final generator = BlockGenerator(random: Random(42));
      final tray = generator.generateTray(GameMode.rising, maxCells: 2);
      expect(tray, hasLength(3));
      expect(tray.every((s) => s.cells.length <= 2), isTrue);
    });

    test('rising mode at high maxCells generates all shapes', () {
      final generator = BlockGenerator(random: Random(42));
      final tray = generator.generateTray(GameMode.rising, maxCells: 5);
      expect(tray, hasLength(3));
      // Should be able to generate shapes with more than 2 cells
      expect(tray.any((s) => s.cells.length > 2), isTrue);
    });

    test('tray shapes are unique (no duplicates)', () {
      final generator = BlockGenerator(random: Random(42));
      final tray = generator.generateTray(GameMode.classic);
      expect(tray.map((s) => s.id).toSet(), hasLength(tray.length));
    });

    test('generatePlayableShape returns a valid shape', () {
      final generator = BlockGenerator(random: Random(42));
      final shape = generator.generatePlayableShape(GameMode.classic);
      expect(shape, isNotNull);
      expect(shape!.cells, isNotEmpty);
    });

    test('generatePlayableShape excludes given IDs', () {
      final generator = BlockGenerator(random: Random(42));
      final allIds = ShapeCatalog.all.map((s) => s.id).toList();
      final shape = generator.generatePlayableShape(
        GameMode.classic,
        excludingIds: allIds,
      );
      expect(shape, isNull);
    });

    test('generatePlayableShape respects maxCells', () {
      final generator = BlockGenerator(random: Random(42));
      final shape = generator.generatePlayableShape(
        GameMode.rising,
        maxCells: 2,
      );
      if (shape != null) {
        expect(shape.cells.length, lessThanOrEqualTo(2));
      }
    });

    test('generatePlayableShape excludes single-cell shapes in timed mode',
        () {
      final generator = BlockGenerator(random: Random(99));
      final shape = generator.generatePlayableShape(
        GameMode.timed,
        maxCells: 5,
      );
      if (shape != null) {
        expect(shape.cells.length, greaterThanOrEqualTo(2));
      }
    });
  });
}
