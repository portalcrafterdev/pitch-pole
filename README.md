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
    components/              player, bolted_enemy, hopper_enemy,
                             surface_strip, door, parallax_backdrop
    logic/
      physics.dart           constants and integration helpers
      level_model.dart       parsed level data
      run_state.dart         x, y, vy, gravityUp, lives, status
      level_simulator.dart   headless run, solver and validator
  ui/
    screens/                 home, level select, game
    overlays/                hud, level complete, level failed, pause
    widgets/                 touch controls, star row
  data/
    level_repository.dart    loads assets/levels/levels.json
    progress_store.dart      stars, best times and settings
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

## The five obstacles

| | Belongs to | Moves | How you beat it |
| --- | --- | --- | --- |
| **Bolted** (red) | one surface | never | flip to the other surface |
| **Hopper** (yellow) | one surface | bounces off it on a rhythm | run under it mid hop, or jump it while it rests |
| **Blade** (steel) | neither | sweeps the whole band, ceiling to floor and back | be on the surface it is furthest from |
| **Stone** (sandstone) | one surface | drops across the band, then is winched back | wait out the slam, or be past before it lets go |
| **Fire** (vent) | one surface | dark, glows, erupts, dies | be on the other surface *while it burns* |

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

## The cast

All three are drawn in code, not sprites, so they animate off the simulation
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

Everything is drawn inside the hit box, which is itself 3 units smaller per
side than the sprite. A spike can never look like it reached further than it
kills.

## The forest

The setting is a forest at dusk: two receding tree lines on parallax, light
through the canopy, low mist, and fireflies drifting in the view so an empty
stretch still has something moving in it. The floor is earth under a moss cap
with grass leaning past; the ceiling is the underside of the canopy.

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

Levels are pure data in `assets/levels/levels.json`. No level logic in code.

```json
{
  "id": 12, "length": 6000, "runSpeed": 200, "hopPeriod": 1.75,
  "bolted":  [ { "x": 620, "surface": "floor" } ],
  "hoppers": [ { "x": 880, "surface": "floor", "phase": 0.6 } ],
  "blades":  [ { "x": 1900, "period": 2.2, "phase": 0.3 } ],
  "stones":  [ { "x": 2400, "surface": "ceiling", "period": 2.4, "phase": 1.1 } ],
  "fires":   [ { "x": 2900, "surface": "floor", "period": 2.6, "phase": 0.4 } ],
  "checkpoints": [2000, 4000]
}
```

`x` is the centre of the obstacle in world units. The door sits at `length`,
which is always `runSpeed * 30`. Hoppers take their period from the level's
`hopPeriod`; blades and stones carry their own, so one level can mix fast and
slow ones.

All five types appear from level 1 and every count only grows, so the pack
never gets easier. Level 1 is two of each at 545 unit spacing, in the order
bolted, hopper, blade, stone, fire, then round again — 545 is wider than the
470 the camera shows ahead, so every type is still met completely alone. Level
20 has twenty three obstacles at about 250 units apart.

No level is allowed dead track: at most 700 units between obstacles, 900 before
the first and 800 after the last. At base speed 700 units is 3.5 seconds of
holding still, which is the edge of what a runner can carry, and that rule is
what sets the floor of ten obstacles a level.

```bash
dart run tool/validate_levels.dart            # check every level
dart run tool/validate_levels.dart --verbose  # and print the inputs it found
```

The validator is a breadth first search over the real simulation. It only
allows a decision every 4 fixed steps, far coarser than a human plays, so
anything it finds is comfortably reachable. States are deduplicated on a
quantised grid, so it can miss a solution but can never invent one: whatever
plan it returns is replayed through the exact simulation before it passes.

It also enforces the layout rules: bolted enemies stay 120 units clear of the
start and the door, opposite surface bolted pairs stay 60 apart, a hop always
fits inside its period, and no stretch of track is left empty.

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
| M2 data driven levels, simulator, validator | done, **20 of 60 levels** |
| M3 shell | home, level select with stars and best times, pause, settings, touch controls |
| M4 feel pass | flip rotation, squash and stretch, trail, shake, sound, haptics |
| M5 content | 20 levels, bands 1 to 20 only |

Levels 21 to 60 are not authored yet. The bands still to build are the mixed
band past level 20, `runSpeed` 240 from 31, `hopPeriod` 1.2 from 43, and
`runSpeed` 280 from 55. The validator and the tooling are ready for them.
