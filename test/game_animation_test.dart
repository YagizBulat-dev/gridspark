import 'package:flutter_test/flutter_test.dart';
import 'package:gridspark/features/game/presentation/game_animation.dart';

void main() {
  test('reduce motion converts game transitions to zero duration', () {
    const normal = Duration(milliseconds: 250);
    expect(gameAnimationDuration(false, normal), normal);
    expect(gameAnimationDuration(true, normal), Duration.zero);
  });
}
