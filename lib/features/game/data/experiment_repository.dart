import 'dart:math';

import 'package:hive/hive.dart';

import '../domain/experiments/ab_testing.dart';

abstract interface class ExperimentRepository {
  String get bucketKey;
  ExperimentAssignment? assignment(String experimentId);
  Future<void> saveAssignment(ExperimentAssignment assignment);
  Future<void> recordOutcome(ExperimentOutcome outcome);
  List<ExperimentOutcome> outcomes(String experimentId);
  ExperimentReport report(String experimentId);
}

class HiveExperimentRepository implements ExperimentRepository {
  HiveExperimentRepository(this._box);

  final Box<dynamic> _box;
  static const _bucketKey = 'abBucketKey';
  final _engine = const ABTestingEngine();
  String? _cachedBucket;

  @override
  String get bucketKey {
    final cached = _cachedBucket;
    if (cached != null) return cached;
    final stored = _box.get(_bucketKey);
    if (stored is String && stored.isNotEmpty) {
      _cachedBucket = stored;
      return stored;
    }
    final generated =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
    _cachedBucket = generated;
    // Fire-and-forget: assignment stability only needs the first write to land.
    _box.put(_bucketKey, generated);
    return generated;
  }

  @override
  ExperimentAssignment? assignment(String experimentId) {
    final raw = _box.get('assignment:$experimentId');
    if (raw is! Map) return null;
    return ExperimentAssignment.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  Future<void> saveAssignment(ExperimentAssignment assignment) => _box.put(
    'assignment:${assignment.experimentId}',
    assignment.toJson(),
  );

  @override
  List<ExperimentOutcome> outcomes(String experimentId) {
    final raw = _box.get('outcomes:$experimentId');
    if (raw is! List) return const <ExperimentOutcome>[];
    return raw
        .whereType<Map>()
        .map(
          (e) => ExperimentOutcome.fromJson(Map<String, Object?>.from(e)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> recordOutcome(ExperimentOutcome outcome) async {
    final updated = <Object?>[
      ...outcomes(outcome.experimentId).map((o) => o.toJson()),
      outcome.toJson(),
    ];
    await _box.put('outcomes:${outcome.experimentId}', updated);
  }

  @override
  ExperimentReport report(String experimentId) =>
      _engine.summarize(outcomes(experimentId));
}

class InMemoryExperimentRepository implements ExperimentRepository {
  final Map<String, ExperimentAssignment> _assignments = {};
  final Map<String, List<ExperimentOutcome>> _outcomes = {};
  final _engine = const ABTestingEngine();
  String? _bucket;

  @override
  String get bucketKey => _bucket ??= 'test-bucket-${DateTime.now().microsecondsSinceEpoch}';

  @override
  ExperimentAssignment? assignment(String experimentId) =>
      _assignments[experimentId];

  @override
  Future<void> saveAssignment(ExperimentAssignment assignment) async =>
      _assignments[assignment.experimentId] = assignment;

  @override
  Future<void> recordOutcome(ExperimentOutcome outcome) async => _outcomes
      .putIfAbsent(outcome.experimentId, () => <ExperimentOutcome>[])
      .add(outcome);

  @override
  List<ExperimentOutcome> outcomes(String experimentId) => List.unmodifiable(
    _outcomes[experimentId] ?? const <ExperimentOutcome>[],
  );

  @override
  ExperimentReport report(String experimentId) =>
      _engine.summarize(outcomes(experimentId));
}
