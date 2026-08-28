import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import 'high_score_box.dart';

const validGameModes = {'classic', 'timed', 'rising'};
const maxAcceptedScore = 10000000;

class ScoreEntry {
  const ScoreEntry({
    required this.name,
    required this.score,
    required this.mode,
  });

  final String name;
  final int score;
  final String mode;
}

abstract interface class RemoteLeaderboardDataSource {
  Future<List<ScoreEntry>> fetchScores(String mode);
  Future<void> submit(ScoreEntry entry);
}

class FirestoreLeaderboardDataSource implements RemoteLeaderboardDataSource {
  FirestoreLeaderboardDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<List<ScoreEntry>> fetchScores(String mode) async {
    final snapshot = await _firestore
        .collection('scores')
        .where('mode', isEqualTo: mode)
        .orderBy('score', descending: true)
        .limit(20)
        .get();
    return parseLeaderboardEntries(
      snapshot.docs.map((document) => document.data()),
    );
  }

  @override
  Future<void> submit(ScoreEntry entry) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Firebase user is not signed in.');
    }
    await _firestore.collection('scores').add({
      'name': entry.name,
      'score': entry.score,
      'mode': entry.mode,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

enum LeaderboardSource { remote, localFallback }

class LeaderboardLoadResult {
  const LeaderboardLoadResult({
    required this.scores,
    required this.source,
    this.message,
  });

  final List<ScoreEntry> scores;
  final LeaderboardSource source;
  final String? message;
}

class ScoreSubmitResult {
  const ScoreSubmitResult({
    required this.savedLocally,
    required this.syncedRemotely,
    this.message,
  });

  final bool savedLocally;
  final bool syncedRemotely;
  final String? message;
}

class LeaderboardRepository {
  LeaderboardRepository(Box<dynamic> box,
      {required this.firebaseEnabled, this.remote})
      : _highScoreBox = HighScoreBox(box),
        _box = box;

  final HighScoreBox _highScoreBox;
  final Box<dynamic> _box;
  final bool firebaseEnabled;
  final RemoteLeaderboardDataSource? remote;

  List<ScoreEntry> localScores({String? mode}) {
    final items = _highScoreBox.all
        .where((entry) => mode == null || entry.mode == mode)
        .toList();
    items.sort((a, b) => b.score.compareTo(a.score));
    return items.take(20).toList();
  }

  Future<LeaderboardLoadResult> globalScores(String mode) async {
    _validateMode(mode);
    if (!firebaseEnabled) {
      return LeaderboardLoadResult(
        scores: localScores(mode: mode),
        source: LeaderboardSource.localFallback,
        message: 'Offline: showing local $mode scores.',
      );
    }
    try {
      return LeaderboardLoadResult(
        scores: await remote!.fetchScores(mode),
        source: LeaderboardSource.remote,
      );
    } catch (_) {
      return LeaderboardLoadResult(
        scores: localScores(mode: mode),
        source: LeaderboardSource.localFallback,
        message: 'Global scores unavailable; showing local scores.',
      );
    }
  }

  Future<ScoreSubmitResult> submit(
    int score,
    String mode, {
    String nickname = 'Player',
  }) async {
    _validateScore(score);
    _validateMode(mode);
    final entry = ScoreEntry(
      name: sanitizeNickname(nickname),
      score: score,
      mode: mode,
    );
    await _box.add({
      'name': entry.name,
      'score': entry.score,
      'mode': entry.mode,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (!firebaseEnabled) {
      return const ScoreSubmitResult(
        savedLocally: true,
        syncedRemotely: false,
        message: 'Score saved locally. Cloud leaderboard is offline.',
      );
    }
    try {
      await remote!.submit(entry);
      return const ScoreSubmitResult(savedLocally: true, syncedRemotely: true);
    } catch (_) {
      return const ScoreSubmitResult(
        savedLocally: true,
        syncedRemotely: false,
        message: 'Score saved locally, but cloud sync failed.',
      );
    }
  }
}

/// Parses persisted local entries and Firestore records using the same rules.
/// Invalid records are ignored so one corrupt record cannot fail a leaderboard.
List<ScoreEntry> parseLeaderboardEntries(
  Iterable<Map<dynamic, dynamic>> values,
) {
  return values.map(_parseLeaderboardEntry).whereType<ScoreEntry>().toList();
}

ScoreEntry? _parseLeaderboardEntry(Map<dynamic, dynamic> value) {
  final name = value['name'];
  final score = value['score'];
  final mode = value['mode'];

  if (name is! String || score is! num || mode is! String) return null;
  if (!_isValidNickname(name) || !validGameModes.contains(mode)) return null;
  if (!_isValidScore(score) || !_hasValidCreatedAt(value['createdAt'])) {
    return null;
  }

  return ScoreEntry(
    name: sanitizeNickname(name),
    score: score.toInt(),
    mode: mode,
  );
}

bool _isValidNickname(String nickname) =>
    _normalizeNickname(nickname).isNotEmpty;

bool _isValidScore(num score) {
  if (!score.isFinite || score != score.toInt()) return false;
  return score >= 0 && score <= maxAcceptedScore;
}

bool _hasValidCreatedAt(Object? value) {
  if (value == null) return true; // Supports legacy local records.
  if (value is Timestamp || value is DateTime) return true;
  return value is String && DateTime.tryParse(value) != null;
}

String sanitizeNickname(String nickname) {
  final sanitized = _normalizeNickname(nickname);
  if (sanitized.isEmpty) return 'Player';
  return sanitized.length <= 24 ? sanitized : sanitized.substring(0, 24);
}

String _normalizeNickname(String nickname) {
  return nickname
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

void _validateMode(String mode) {
  if (!validGameModes.contains(mode)) {
    throw ArgumentError.value(mode, 'mode', 'Unsupported game mode');
  }
}

void _validateScore(int score) {
  if (score < 0 || score > maxAcceptedScore) {
    throw ArgumentError.value(
      score,
      'score',
      'Score must be between 0 and $maxAcceptedScore',
    );
  }
}
