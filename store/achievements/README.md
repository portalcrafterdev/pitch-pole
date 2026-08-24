# Achievements

Source for the Play Console achievements import
(Play Console → Grow → Play Games Services → Achievements → Import achievements).

Play Games project: **Pitch Pole**, project ID `245388757681`.

Upload a single ZIP containing the three CSVs in this folder plus one icon per
achievement. That is **35 files** for the 32 achievements below.

```
achievements.zip
  AchievementsMetadata.csv
  AchievementsLocalizations.csv
  AchievementsIconsMappings.csv
  first_steps.png ... stubborn.png                 (32 files, 512x512 PNG)
```

The CSVs carry no image data. `AchievementsIconsMappings.csv` is a manifest: it
says `first_steps,first_steps.png`, and the importer looks for a file of exactly
that name **inside the same ZIP**. So the PNGs sit flat at the root, next to the
CSVs, named exactly as the mapping file spells them — not in an `icons/`
subfolder, because the mapping carries a bare filename and not a path. A missing
or misnamed file is a missing icon.

## Verify the headers before the first import

The three header rows here are written from the fields a Play Games achievement
actually has, but Google does not publish the importer's exact column spelling
and it has changed before. **A wrong header is a rejected import, not a warning.**

Sixty seconds of insurance, once:

1. Create a single achievement by hand in the console.
2. Export achievements.
3. Diff the exported header rows against the ones here and fix any mismatch.

Everything else in these files — ids, points, types, order — is correct
regardless of what the headers turn out to be called.

## The point budget

Play Games allows **1000 points total** across all achievements, each 5 to 200
and a multiple of 5, up to 100 achievements. This set spends **exactly 1000**
across 32. Adding one means taking points off another.

| Group | Achievements | Points |
| --- | --- | --- |
| Progression | 9 | 350 |
| Mastery | 8 | 300 |
| Coins | 5 | 135 |
| Skill | 6 | 155 |
| Persistence | 4 | 60 |
| **Total** | **32** | **1000** |

## Why these, for this game

Two whole categories are impossible here and are deliberately absent:

- **No speedrun achievements.** Run speed is fixed per level and every level is
  30 seconds of running, so finishing time is really a death counter. "Under X
  seconds" would just be a worse way of saying three stars.
- **No endless or distance achievements.** The pack is finite and there is no
  endless mode.

And one is deliberately refused: **nothing is tied to watching an ad.** An
achievement obtainable only through the rewarded life would be content gated
behind an ad, which breaks rule 4 in CLAUDE.md.

`every_flavour` is the one that carries its weight hardest. Levels 301 to 10,000
all sit at the same difficulty and differ only in which of the twelve obstacle
mixes they were built from, so this is the achievement that turns that variety
into something a player chases rather than something they never notice.

## Numbers these depend on

| Quantity | Value |
| --- | --- |
| Levels | 10,000 |
| Stars available | 30,000 |
| Coins available | ~465,000 (estimate — pin once the pack is generated) |
| Obstacle mixes (archetypes) | 12 |

`coin_baron` and `all_that_glitters` are set against the estimate. Recheck them
against the real total when `tool/generate_levels.dart` finishes.

## Before any of this ships

1. **CLAUDE.md section 15 currently forbids achievements outright** — "No
   leaderboard, no achievements, no cloud save". Shipping these is a deliberate
   rule change, not an oversight to work around.
2. **`featherfoot` and `held_ground` are unverified.** Run the solver across the
   pack asking whether any level is completable with zero jumps, and with three
   flips or fewer, and delete whichever has no answer. An achievement nobody can
   earn is worse than no achievement.
3. **Buffer unlocks locally and flush them on sign-in.** Otherwise a signed out
   player earns nothing and signing in later gives nothing back, which makes
   signed out the worse way to play — the exact line section 15 says not to
   cross.

## What the game does not track yet

Most of these read straight off `ProgressStore`, which already keeps stars, best
times and best coins per level. Four need new counters:

| Achievement | Needs |
| --- | --- |
| `featherfoot` | jump count for the current run, in `RunState` |
| `held_ground` | flip count for the current run, in `RunState` |
| `ten_in_a_row`, `marathon` | levels cleared this session, in memory |
| `stubborn` | deaths per level, persisted |

`range` and `every_flavour` need no new storage: `archetypeFor(id)` in
`lib/game/logic/level_generator.dart` is a pure function of the level id.

## Icons

32 PNGs at 512x512. The launcher icon is drawn in code by `tool/make_icon.dart`
rather than painted by hand, and these should be drawn the same way, off the
same palette and the same character proportions — 32 consistent icons out of a
tool beats 32 trips to an image editor.
