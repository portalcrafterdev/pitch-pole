# Pitchpole

A real time gravity flip runner. The character runs forward by itself and
never stops. One button flips gravity so it falls to the ceiling and runs
upside down; another jumps off whichever surface it is standing on. Reach the
door at the end.

## Run it

Android and iOS only. The desktop and web targets were removed on purpose:
the game is landscape, touch first and built around a phone's frame timing, so
shipping a build nobody would play only meant four more platform folders to
keep working.

```bash
flutter pub get
flutter run            # a connected phone or an emulator
flutter test           # 182 tests: physics, levels, scene, controls, layout
flutter build apk      # or: flutter build ipa
```

The keyboard controls below still work, on an emulator or a phone with a
keyboard attached, and they are what the tests drive.

| Input | Action |
| --- | --- |
| Arrow Up / W | Set gravity up, go to the ceiling |
| Arrow Down / S | Set gravity down, go to the floor |
| Space | Jump off the current surface |
| R | Restart the level |
| Esc | Pause |

Up and Down are absolute, never a toggle: pressing Up while already on the
ceiling does nothing.

## Touch

Landscape only, both ways round — the play field is 560 by 220, so portrait
would letterbox it into a strip. The app sets the orientation itself, which
overrides a device rotation lock on purpose.

Two schemes, picked in settings:

| | How it works |
| --- | --- |
| **Screen halves** (default) | Left half flips, right half jumps. Nothing small to miss. The flip is a toggle, because a half cannot say which way it goes. |
| **Buttons** | Two pads bottom left for ceiling and floor, one bottom right for jump. Absolute flips, exactly like the arrow keys. |

They are exclusive, and `test/touch_controls_test.dart` holds them to it: with
buttons on, a tap anywhere but a pad does nothing; with halves on, there are no
buttons on screen. If both were live, a thumb resting on what looks like empty
screen would flip you into a blade.

## How it is put together

Every rule lives in pure Dart under [lib/game/logic/](lib/game/logic/), and a
test asserts none of it imports Flame, Flutter or `dart:ui`. The scene, the
tests, and the level validator all drive the *same* functions, so what the
tests prove is what the player gets.

```
lib/
  game/
    pitchpole_game.dart      FlameGame subclass: fixed step loop, camera, feel
    components/              player, bolted_enemy, hopper_enemy, blade,
                             stone, fire, bat_enemy, spider_enemy,
                             surface_strip, door, parallax_backdrop
    logic/
      physics.dart           constants and integration helpers
      level_model.dart       parsed level data
      run_state.dart         x, y, vy, gravityUp, lives, status
      level_simulator.dart   headless run, solver and validator
      level_generator.dart   builds levels 6 to 10000, authoring time only
      level_pack.dart        where the shards live and what is in each
  ui/
    screens/                 home, level select, game
    overlays/                hud, level complete, level failed, pause
    widgets/                 touch controls, star row, sign in button
  data/
    level_repository.dart    reads one shard of assets/levels/ at a time
    progress_store.dart      stars, best times and settings
    games_auth.dart          Play Games / Game Center sign in, optional
```

### Fixed timestep

The simulation always advances in 1/120 second steps out of an accumulator,
whatever the frame rate. A variable step would make the same level behave
differently on a 60 and a 120 hertz phone, which would break every tuned hop
window. `test/physics_test.dart` runs the same level one step and two steps per
frame and asserts the results are identical to 1e-4.

### Everything follows from x

Forward speed is constant, so level time is just `x / runSpeed`. Hopper phases
are computed from that rather than from a wall clock, which is what makes a
checkpoint respawn put every hopper back exactly where it was the first time.

## The seven obstacles

| | Belongs to | Moves | How you beat it |
| --- | --- | --- | --- |
| **Bolted** (red) | one surface | never | flip to the other surface |
| **Hopper** (yellow) | one surface | bounces off it on a rhythm | run under it mid hop, or jump it while it rests |
| **Blade** (steel) | neither | sweeps the whole band, ceiling to floor and back | be on the surface it is furthest from |
| **Stone** (sandstone) | one surface | drops across the band, then is winched back | wait out the slam, or be past before it lets go |
| **Fire** (vent) | one surface | dark, glows, erupts, dies | be on the other surface *while it burns* |
| **Bat** (violet) | neither | hovers in the middle of the band | already be on a surface, and stay on it |
| **Spider** (magenta) | the ceiling | drops on a thread, hangs, climbs back | be on the floor, and do not jump |

A blade is only 26 units wide, so it threatens for about a tenth of a second —
the skill is reading which side is open on approach, not reacting. A stone at
full extension closes the whole column for about half a second, so it is a hard
gate rather than a choice.

A fire reaches 70 units, above the 60 unit jump peak, so it cannot be hopped —
and far enough short of the 120 unit band that the opposite surface really is
clear. That is the point of it: a bolted enemy is a flip you must *make*, a
fire is a flip you must *time*. The 0.45 second warning glow before it lights
is what keeps that fair, and the flame itself is the hit box, so a cold vent
is harmless.

The **bat** is the odd one out, and deliberately so. Every other obstacle is
answered by flipping or jumping; a bat closes both, because a jump peaks
inside it and a flip crosses straight through it. It never touches either
surface, so standing still is always safe — with 23 units of margin at the
worst of its drift. That makes it the first obstacle in the game that has to
be decided *before* you reach it. It gets 130 units of clear track either side
for exactly that reason: anything closer would be demanding a flip inside the
span where a flip is fatal, which is impossible rather than hard.

A **spider** shuts the ceiling on the way down, then the air while it hangs,
and never the floor. It cannot be jumped from the floor either — the peak of a
jump clears a hanging spider, but the arc into it does not, which is the sort
of thing that is much easier to assert in a test than to notice by eye.

## Coins

Coins sit along the run and are picked up on the way past. They never kill and
never block — they are the one thing in the world whose box is **grown** by 3
units rather than shrunk by 3. Every lethal box comes in a little because a
generous threat feels unfair; a generous reward feels good, so the rule is
inverted here and nowhere else.

They are **green, not gold**, and that is not a style choice. Gold would sit
within a shade of the yellow hopper, which is a thing that kills you. In a game
running at 280 units a second, colour is how the player tells safe from lethal,
and it cannot be spent on making a coin look the way coins usually look.

Coins are laid along the route the solver proved for each level, so every coin
sits on a line the level can genuinely be run along — none is ever stranded
inside a blade's sweep or behind a bolted enemy. A row of them is a hint:
follow it and you are on a line that finishes. Take a different valid route and
you simply miss some.

A death gives back the coins past the last checkpoint and keeps the ones behind
it, so a respawn never asks you to sweep the same stretch twice. Collection
runs in `LevelSimulator.step` and never inside `advance`, because the solver
drives `advance` directly hundreds of thousands of times per level and must not
pay for something that cannot change whether a level is completable.

They are collectible, not currency. There is nothing to spend them on, and per
CLAUDE.md §15 there never will be.

## The cast

All of them are drawn in code, not sprites, so they animate off the simulation
rather than off a frame counter.

- **The runner** has legs that cycle out of its stride, and the stride comes
  from distance rather than from a clock, so the steps always match the speed.
  Airborne the legs tuck, which is what sells a jump without any extra
  animation. It blinks, its pupils lean into the run and drift with the fall,
  and its ears lie back so a flipped character reads as upside down.
- **The bolted enemy** scowls: angled brows, a gritted mouth, pupils tucked
  towards the oncoming run, and visible bolts so it reads as fixed to its
  surface rather than resting on it.
- **The hopper** screws its eyes shut as it crouches to launch, then goes
  wide eyed and open mouthed in the air. Both are tells, not decoration: the
  crouch is the player's warning that it is about to leave the ground.
- **The bat** beats its wings faster than anything else on screen, which is
  what makes it the first thing the eye finds in an otherwise empty band. The
  wingbeat is cosmetic and never touches the hit box, so a bat with its wings
  out is no wider than one with them tucked.
- **The spider** hangs off a thread drawn from the ceiling line down to its
  body, with eight legs working slightly out of step. The thread is never part
  of the hit box — only the body kills.

Everything is drawn inside the hit box, which is itself 3 units smaller per
side than the sprite. A spike can never look like it reached further than it
kills.

## The forest

The setting is a forest at dusk: two receding tree lines on parallax, light
through the canopy, low mist, and fireflies drifting in the view so an empty
stretch still has something moving in it. The floor is earth under a moss cap
with grass leaning past; the ceiling is the underside of the canopy.

It is also inhabited. Deer stand in the far treeline and graze, each on its own
slow clock so the herd is never in step with itself; birds cross behind the
trees; moths flutter in the light, paler than a firefly and never pulsing, so
the two read as different animals rather than one drawn twice. The deer scroll
with the far trees, which is what makes them part of the forest rather than
something coming towards you.

None of it is allowed any real contrast. Wildlife is one shade up from the far
canopy and nothing more — it has to be findable against the trees and invisible
next to an obstacle, because scenery scrolls and anything brighter would read
as a threat.

All of it is near black green and brown, because the rule underneath has not
changed — the cast and the finish line must be the only high contrast things on
screen. Scenery scrolls, so anything bright in it would read as a threat.

Every shape is rolled once from a fixed seed and drawn in viewport space, so
the background costs the same however long the level is, and it is the same
forest on every device.

## Finishing

The door is a chequered finish line spanning the whole band, with the chequers
crawling downwards so it reads as alive from the moment it comes on screen.
Crossing it does not cut straight to the overlay: the simulation stops, but the
scene keeps running for `PitchpoleGame.kWinPause` while the line bursts confetti
and the character spins and bounces on the spot. Only then does the cleared
panel come up, with its own confetti fall and the stars popping in one by one.

## Levels

Levels are pure data in `assets/levels/`, sharded 250 to a file. No level logic
in code.

```json
{
  "id": 12, "length": 6000, "runSpeed": 200, "hopPeriod": 1.75,
  "bolted":  [ { "x": 620, "surface": "floor" } ],
  "hoppers": [ { "x": 880, "surface": "floor", "phase": 0.6 } ],
  "blades":  [ { "x": 1900, "period": 2.2, "phase": 0.3 } ],
  "stones":  [ { "x": 2400, "surface": "ceiling", "period": 2.4, "phase": 1.1 } ],
  "fires":   [ { "x": 2900, "surface": "floor", "period": 2.6, "phase": 0.4 } ],
  "bats":    [ { "x": 3400, "period": 2.2, "phase": 0.7 } ],
  "spiders": [ { "x": 3900, "period": 3.4, "phase": 1.2 } ],
  "coins":   [ { "x": 260, "y": 159 }, { "x": 520, "y": 61 } ],
  "checkpoints": [2000, 4000]
}
```

`x` is the centre of the obstacle in world units; coins carry a `y` too, since
they sit on the line the level is run on rather than against a surface. The
door sits at `length`,
which is always `runSpeed * 30`. Hoppers take their period from the level's
`hopPeriod`; blades, stones, fires, bats and spiders carry their own, so one
level can mix fast and slow ones.

No level is allowed dead track: at most 700 units between obstacles, 900 before
the first and 800 after the last. At base speed 700 units is 3.5 seconds of
holding still, which is the edge of what a runner can carry, and that rule is
what sets the floor of ten obstacles a level.

### 10,000 levels, in three parts

| Levels | | Speed | `hopPeriod` | Obstacles |
| --- | --- | --- | --- | --- |
| 1 to 5 | **taught** — hand placed, the original five types | 200 | 2.0 | 10 to 12 |
| 6 to 300 | **ramp** — generated, climbing the whole way | 200 to 280 | 2.0 to 1.0 | 12 to 43 |
| 301 to 10,000 | **plateau** — difficulty flat, composition rotating | 280 | 1.0 | 43 |

Levels 1 to 5 are hand placed and stay that way. Level 1 is two of each at 545
unit spacing, in the order bolted, hopper, blade, stone, fire, then round again
— 545 is wider than the 470 the camera shows ahead, so every type is still met
completely alone. The **bat arrives at level 6** and the **spider at level 9**,
each with a level built around it.

Five taught levels is deliberately short. Level 1 cannot hold a sixth or
seventh type — fourteen obstacles at 545 unit spacing would need 7,630 units in
a 6,000 unit level — so the new types come *after* the teaching rather than
inside it, and they come quickly.

**Difficulty cannot climb 10,000 times, and the pack does not pretend it does.**
A level is 30 seconds, obstacles cannot be closer than 60 units, and a bat
needs 130 either side. At the top speed of 280 that caps a level at about 43
obstacles, and there is nowhere further to go. So it ramps hard to level 300
and then holds, and past that what changes is *what a level asks for*: each one
is built from one of twelve archetypes — `swarm`, `furnace`, `canopy`,
`gauntlet`, `balanced`, `commitment`, `cavein`, `crossfire`, `scramble`,
`pinch`, `anvil`, `flashpoint` — picked from its own id. The first six were
written for a pack of 1,500; the second six were added at 10,000, each pairing
two obstacle types the first six never leaned on together.

### Generating and checking

```bash
dart run tool/generate_levels.dart --sample 40   # smoke test, writes nothing
dart run tool/generate_levels.dart               # build and write the pack
dart run tool/validate_levels.dart               # check what is on disk
```

Levels 6 and up are built by a seeded generator that runs at authoring time,
and its output is committed like any other asset. Nothing is ever rolled on a
phone: level 847 is the same bytes for everybody, forever. A test asserts the
committed pack still matches what the generator produces, so the asset can
never silently drift from the code that made it.

The generator is built to be correct by construction rather than to guess and
retry, because solving a level costs about a second and there are ten thousand
of them — a full authoring run is around four hours. Spacing, clearances and phases are all chosen up front — and phases in
particular are aimed at the exact moment the character arrives, which is
knowable because forward speed never changes and arrival is always
`x / runSpeed`. The solver is a check, not a filter.

The validator is a breadth first search over the real simulation. It only
allows a decision every 4 fixed steps, far coarser than a human plays, so
anything it finds is comfortably reachable. States are deduplicated on a
quantised grid, so it can miss a solution but can never invent one: whatever
plan it returns is replayed through the exact simulation before it passes.

It also enforces the layout rules: bolted enemies stay 120 units clear of the
start and the door, opposite surface bolted pairs stay 60 apart, bats stay 130
clear of anything else, a hop always fits inside its period, and no stretch of
track is left empty.

Solving is the only expensive part, so the work is split. `validateLevel(level,
solve: false)` checks every structural rule and runs over all 10,000 levels in
a unit test. The full solve runs across isolates in `tool/generate_levels.dart`,
which refuses to write the pack if a single level fails; the test suite solves
the five taught levels plus a spread of a dozen generated ones as a
regression net. Every level that ships has been solved — just not on every
`flutter test`.

## Watch out for

A hopper at full stretch is 90 units of hop plus a 26 unit body, which is 116
of the 120 unit band. So a hopper caught **mid hop threatens the opposite
surface too** — a ceiling hopper at its peak will kill a character running on
the floor. That falls straight out of the tuned constants and it is what makes
"arriving mid hop" the dangerous case, but it means hopper phases have to be
authored deliberately, not sprinkled.

## Sounds

`dart run tool/make_sounds.dart` synthesises the four sounds the design asks
for into `assets/audio` as 16 bit mono WAV: a click on jump, a whoosh on flip,
a soft thud on landing, a dull thump on death. Nobody recorded them, but they
are the real shipped assets and regeneration is deterministic. Tweak the
numbers in the tool rather than editing binaries.

Sounds play out of a warm `AudioPool` per effect, not through `FlameAudio.play`.
That call builds a fresh `AudioPlayer`, hands it an audio context, sets a
release mode and only then loads and plays the asset — four platform round
trips before a click that is supposed to land on the frame the button was
pressed, which is exactly why jumps used to sound late. A pool keeps the
players built with the source already set, so playing is a volume change and a
resume. The pools are static and warmed once during the menu, because building
them per level would only move the stutter to the start of every level.

It also writes `music.wav`, an eight second loop of A minor at 120 BPM: a bass
pulse on each beat and a pad, no melody, so it fills a quiet stretch without
competing with the sounds that carry information. The sustained tones are
nudged to whole cycles of the loop and the seam is crossfaded, so it repeats
forever without a click. It has its own toggle in settings, separate from
sound effects.

## Status

| Milestone | State |
| --- | --- |
| M1 playable core | done, every point in the definition of done is under test |
| M2 data driven levels, simulator, validator | done |
| M3 shell | home, level select with stars and best times, pause, settings, touch controls |
| M4 feel pass | flip rotation, squash and stretch, trail, shake, sound, haptics |
| M5 content | **10,000 levels**, all validated and all solved |

Level select opens on the level you are actually on rather than at the top,
which stops mattering at 20 levels and starts mattering a great deal at 10,000.

What has *not* been done is playtesting at this scale. The pack is proven
solvable — a breadth first search finished every one of the 10,000 — but "a
solver can finish it" and "it is fun" are different claims, and only the first
one is tested. The plateau in particular is 9,700 levels of flat difficulty
whose variety comes from twelve archetypes — about 800 levels each. Whether
that reads as varied or as samey over thousands of levels is a question for a
real phone and a real player, not for a test suite, and archetype count is
still the thing most likely to run out first.
