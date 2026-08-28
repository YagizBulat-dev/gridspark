import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

import '../../application/game_store.dart';

/// Maximum simultaneous particles across all active effects.
const int kMaxParticles = 550;

/// Callbacks fired by [EffectsController] so the overlay can act.
class EffectsCallbacks {
  VoidCallback? onClear;
  VoidCallback? onPlace;
}

/// Controls when Newton effects should be triggered based on store state.
///
/// Holds MobX [ReactionDisposer]s and delegates visual work to the overlay
/// via [EffectsCallbacks]. It never owns an AnimationController or Ticker.
class EffectsController {
  EffectsController({
    required this.store,
    required this.callbacks,
  }) {
    _setupReactions();
  }

  final GameStore store;
  final EffectsCallbacks callbacks;
  final List<ReactionDisposer> _disposers = [];

  int _activeParticleCount = 0;

  /// Whether an effect can be added without exceeding the particle budget.
  bool get canAddEffect => _activeParticleCount < kMaxParticles;

  void _setupReactions() {
    // Line-clear burst: triggers when comboPopupTrigger increments.
    _disposers.add(
      reaction(
        (_) => store.comboPopupTrigger.value,
        (trigger) {
          if (trigger > 0) {
            callbacks.onClear?.call();
          }
        },
      ),
    );

    // Micro-burst on placement (no clear).
    _disposers.add(
      reaction(
        (_) => store.lastPlacedCells.length,
        (_) {
          if (store.lastClearedLines.value == 0 &&
              store.lastPlacedCells.isNotEmpty) {
            callbacks.onPlace?.call();
          }
        },
      ),
    );
  }

  /// Adjusts the internal particle budget by [delta].
  void adjustParticleCount(int delta) {
    _activeParticleCount = math.max(0, _activeParticleCount + delta);
  }

  /// Returns the remaining particle budget.
  int get remainingBudget => math.max(0, kMaxParticles - _activeParticleCount);

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
  }
}
