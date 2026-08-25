# Leaderboards

One board, created by hand in Play Console. There is **no bulk CSV import for
leaderboards** the way there is for achievements, so this is one form.

## Why one, and why it is stars

Play allows seventy. Most runners spend them on times, and this game cannot:
every level in the pack takes **exactly 30.0 seconds**. Length is `runSpeed`
times 30 by construction and speed is fixed for the whole level, so a clean run
of level 1 and a clean run of level 9,999 both take 30.0, for every player on
every device. A "fastest time" board would be a wall of ties that actually
ranked people by how often they died — the opposite of what its name promises.

That leaves cumulative totals, and stars is the one worth ranking. It carries
progress and how cleanly it was made in a single number: three for finishing
with every life intact, two with one lost, one for finishing at all. Levels
cleared, coins collected and levels swept were all considered and dropped — they
are near duplicates of the same progress, and three more rows would have made
the feature look bigger than it is.

Only the **all time** span is offered. Play keeps the best score submitted in
each window, so a daily board of a running total would show a veteran's lifetime
figure on a day they never opened the game.

## What to create

Play Console → **Grow users → Play Games Services → Setup and management →
Leaderboards → Create leaderboard**.

| Field | Value |
| --- | --- |
| Name | `Stars Earned` |
| Icon | `stars_earned.png` |
| Ordering | Larger is better |
| Score format | Numeric, 0 decimal places |
| Upper score limit | `30000` |

The name must match the `name` of `Lb.starsEarned` in
`lib/data/leaderboards.dart` character for character, and the limit must match
its `max`. `test/leaderboards_test.dart` pins the maximum, since a wrong limit
either clips a legitimate player or lets a tampered score stand.

**Two of these are one-way doors.** *Ordering type* and *score format* cannot be
changed once the board is published. Get them right before publishing.

## Done

The board exists and its id is wired in:

```
Lb.starsEarned.androidId = 'CgkIsZW9kpIHEAIQIQ'
```

Same `CgkIsZW9kpIHEAIQ` project prefix as the 32 achievements, so it belongs to
the same Play Games Services project. `test/leaderboards_test.dart` now asserts
the id is present and looks like a Play id, rather than asserting it is empty.

What is still outstanding:

1. The board is a **draft** until it is published with the game.
2. Your account has to be on the **Testers** list (left sidebar, under Setup and
   management) or sign in fails and the board stays invisible, however correct
   everything else is.

`iosId` stays empty until the game is set up in App Store Connect; Game Center
assigns its own ids and a Play id means nothing to Apple. On iOS the board is
tracked and never submitted, which is the same thing that happens to a player
who never signs in, and deliberately silent rather than an error.

Tamper protection is on by default for new Android leaderboards and takes up to
24 hours to take effect.

## Icon

Drawn, not painted:

```
flutter test tool/make_achievement_icons.dart
```

Same tool and palette as the 32 achievement icons, so the two lists look like
the same game. The tool reads `Lb.all`, so adding a board without drawing its
icon fails there rather than halfway through a console form.
