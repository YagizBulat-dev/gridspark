import 'package:share_plus/share_plus.dart';

abstract interface class ShareService {
  Future<ShareOutcome> shareScore({
    required int score,
    required String mode,
    required int bestStreak,
  });
}

/// App-level result that keeps a user dismissal distinct from a share failure.
enum ShareOutcome { success, dismissed, error }

ShareOutcome mapShareResultStatus(ShareResultStatus status) => switch (status) {
  ShareResultStatus.success => ShareOutcome.success,
  ShareResultStatus.dismissed => ShareOutcome.dismissed,
  ShareResultStatus.unavailable => ShareOutcome.error,
};

class NativeShareService implements ShareService {
  @override
  Future<ShareOutcome> shareScore({
    required int score,
    required String mode,
    required int bestStreak,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text:
              'I scored $score in GridSpark ${mode.toUpperCase()} '
              'with a best streak of ${bestStreak}x. Can you beat it?',
          subject: 'My GridSpark score',
        ),
      );
      return mapShareResultStatus(result.status);
    } catch (_) {
      return ShareOutcome.error;
    }
  }
}
