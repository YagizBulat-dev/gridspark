# GridSpark

GridSpark is an 8x8 Flutter block-placement puzzle with Classic, Timed and Zen
modes. Game rules live in a framework-independent Dart engine; MobX drives game
and leaderboard state, Hive stores settings/local scores, and Firebase can add
an anonymous global leaderboard.

## Features

- Pure Dart placement, collision, line-clear, scoring and game-over logic.
- Local score history split by game mode.
- Global Firestore leaderboard split by mode and ordered by score.
- Automatic local fallback when Firebase is unavailable or a global query fails.
- Full-piece drag preview with valid/invalid placement feedback.
- Accessible piece/cell labels and a select-piece, tap-cell alternative to drag.
- Lifecycle-aware timed games with manual pause/resume.
- Lightweight score/line-clear animation and replay/menu game-over actions.
- Local in-progress game snapshots saved on placement, pause, and app background.
- Material 3 light/dark themes.

Sound and haptic controls are deliberately not advertised in the current UI:
this version does not emit audio or vibration effects.

Game snapshots restore the grid, score, remaining tray, move count, and timed
mode countdown from Hive. They are intentionally local and best-effort: an OS
process kill can occur before a pending Hive write is flushed. Writes are queued
in creation order so an older in-process autosave cannot overtake a newer one.
Malformed, inconsistent, completed, or unplayable snapshots are rejected and a
clean game is created. Elapsed wall time while the app is closed is not deducted
because inactive games are paused. A future version may add versioned snapshot
migrations and explicit cloud sync.

## Firebase setup

Firebase is optional. The repository intentionally does **not** contain guessed
or placeholder native configuration. To enable global scores, add the real
Firebase configuration generated for `com.yagiz.gridspark`:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Use FlutterFire configuration where required by your target platforms.
- Enable Anonymous Authentication and Cloud Firestore.
- Deploy `firestore.rules` and `firestore.indexes.json` from this repository.

The global query filters by `mode` and orders by descending `score`. The required
`(mode ASC, score DESC)` composite index is included in
`firestore.indexes.json`.

Without valid native configuration, startup safely enters offline mode and only
local leaderboard data is shown.

## Score validation and security limitations

The client validates the mode, requires a score between 0 and 10,000,000, and
normalizes nicknames by removing control characters, collapsing whitespace and
limiting names to 24 characters. It also ignores malformed persisted or remote
records individually, rather than discarding an otherwise valid leaderboard.
`firestore.rules` repeats the enforceable shape/range checks, requires
authenticated ownership, uses server timestamps, denies client updates/deletes,
and requires a non-whitespace nickname of at most 24 characters.

Firestore Rules regular-expression support is deliberately limited compared to
the client: the rules reject ASCII control characters (`U+0000`–`U+001F` and
`U+007F`), but do not provide complete Unicode control-character classification
or client-equivalent whitespace normalization. The client remains the final
normalizer, while the rules enforce the practical server-side subset.

These controls protect data shape; they **cannot prove that a score was earned
by an untampered game client**. A modified client can still submit a plausible
score within the allowed range. Production-grade anti-cheat requires a trusted
backend/Cloud Function that verifies signed game sessions or computes/approves
scores server-side. Per-user rate limiting also belongs on that backend (or via
App Check plus server enforcement), because Firestore rules alone are not a
reliable rate limiter.

## Development

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```
