# Leaderboards

Four boards, created by hand in Play Console. There is **no bulk CSV import for
leaderboards** the way there is for achievements, so this is four forms.

## Why only four, and why none of them is a time

Every level in the pack takes **exactly 30.0 seconds**. Length is `runSpeed`
times 30 by construction and speed is fixed for the whole level, so a clean run
of level 1 and a clean run of level 9,999 both take 30.0, for every player on
every device. A "fastest time" board would be a wall of ties that actually
ranked people by how often they died — the opposite of what its name promises.

So all four are cumulative totals, and the game only ever opens them on the
**all time** span. Play keeps the best score submitted in each window, which
means the daily board of a running total shows a veteran's lifetime figure on a
day they never opened the game.

## What to create

Play Console → **Grow users → Play Games Services → Setup and management →
Leaderboards → Create leaderboard**, four times.

| Name | Icon | Ordering | Format | Upper score limit |
| --- | --- | --- | --- | --- |
| `Levels Cleared` | `levels_cleared.png` | Larger is better | Numeric, 0 dp | 10000 |
| `Stars Earned` | `stars_earned.png` | Larger is better | Numeric, 0 dp | 30000 |
| `Coins Collected` | `coins_collected.png` | Larger is better | Numeric, 0 dp | 467430 |
| `Levels Swept` | `levels_swept.png` | Larger is better | Numeric, 0 dp | 10000 |

The names must match the `name` of each `LeaderboardSpec` in
`lib/data/leaderboards.dart` character for character, and the limits must match
each spec's `max`. `test/leaderboards_test.dart` pins the maxima, since a wrong
limit either clips a legitimate player or lets a tampered score stand.

**Two of these are one-way doors.** *Ordering type* and *score format* cannot be
changed once the board is published. Get them right before publishing.

## Then

1. Save each as a **draft**, and publish them with the game.
2. Copy the generated ID for each board (they look like `CgkIsZW9kpIHEAIQBw`).
3. Paste them into the matching `LeaderboardSpec` in
   `lib/data/leaderboards.dart` as `androidId:`.

Until those ids are filled in, the game tracks all four totals and sends none of
them — the same thing that happens to a player who never signs in, and
deliberately silent rather than an error. `test/leaderboards_test.dart` asserts
they are still empty, so filling them in is a deliberate act that has to update
that test too.

`iosId` stays empty until the game is set up in App Store Connect; Game Center
assigns its own ids and a Play id means nothing to Apple.

Tamper protection is on by default for new Android leaderboards and takes up to
24 hours to take effect.

## Icons

Drawn, not painted:

```
flutter test tool/make_achievement_icons.dart
```

Same tool and same palette as the 32 achievement icons, so the two lists look
like the same game. Change a number there rather than opening an image editor.
