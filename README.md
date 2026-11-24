# GridSpark

GridSpark is an 8×8 Flutter block-placement puzzle with **Classic**, **Time Attack** and **Rising Difficulty** modes. Game rules live in a framework-independent Dart engine; MobX drives game and leaderboard state, Hive stores settings/local scores, and Firebase adds an optional anonymous global leaderboard.

## Features

- Pure Dart placement, collision, line-clear, scoring and game-over logic.
- Three game modes: Classic (endless), Time Attack (2-minute countdown), Rising Difficulty (gets harder as your score climbs).
- Difficulty level indicator in Rising Difficulty mode (L1 → L3).
- Local score history split by game mode; global Firestore leaderboard with mode filter.
- Automatic local fallback when Firebase is unavailable or a global query fails.
- Full-piece drag preview with valid/invalid placement feedback.
- Accessible piece/cell labels and a select-piece, tap-cell alternative to drag.
- Lifecycle-aware timed games with manual pause/resume.
- Score/line-clear animation, combo popup, shockwave ring, and Newton particle bursts.
- Replay/menu game-over actions with share sheet.
- Nickname entry on game-over for personalised leaderboard entries.
- Local in-progress game snapshots saved on placement, pause, and app background.
- Material 3 light/dark themes; reduce-motion and haptics accessibility controls.
- Per-mode background music and 8 SFX tracks (place, clear, combo, game-over, etc.).
- Daily Sparks — three rotating daily challenges (clear lines, place pieces, score in Time Attack).

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
`(mode ASC, score DESC)` composite index is included in `firestore.indexes.json`.

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

These controls protect data shape; they **cannot prove that a score was earned
by an untampered game client**. A modified client can still submit a plausible
score within the allowed range. Production-grade anti-cheat requires a trusted
backend/Cloud Function that verifies signed game sessions or computes/approves
scores server-side.

## Development

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

