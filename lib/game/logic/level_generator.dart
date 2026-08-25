/// Builds levels from a seed.
///
/// This file must never import Flame, Flutter or dart:ui.
///
/// Levels are still pure, static, repeatable data: this runs once at authoring
/// time and its output is committed to `assets/levels/` as shards. Nothing
/// here ever runs on a player's phone. Level 847 is the same level for
/// everybody, forever, because it is the same bytes for everybody.
///
/// The generator is built to be *correct by construction* rather than to guess
/// and retry. Spacing, clearances and phases are all chosen so the level obeys
/// the rules before the validator ever sees it — the solver is a check, not a
/// filter. That matters because solving a level costs seconds and there are
/// ten thousand of them: at roughly a second each the authoring run is hours,
/// and a generate-and-retry loop would make it days.
library;

import 'dart:math';

import 'level_model.dart';
import 'level_pack.dart' show kTotalLevels;
import 'level_simulator.dart';
import 'physics.dart';
import 'run_state.dart';

export 'level_pack.dart' show kTotalLevels;

/// Levels 1 to 5 are hand placed and stay that way.
///
/// Five is enough to teach the original five types, one per level, each met
/// completely alone. Any longer and the player is ten minutes into a ten
/// thousand level game before anything new happens.
///
/// They live in `assets/levels/taught.json`, which is the hand edited source for
/// them. The tool copies them into the shipped shards next to the generated
/// levels, so the game reads all ten thousand the same way.
const int kFirstGeneratedLevel = 6;

// [kTotalLevels] is a fact about the pack rather than about the generator, so
// it lives in level_pack.dart. It is re-exported from here because the tools
// read it alongside the difficulty dials below and there is no reason to make
// them import two files to get one span.

/// Where the first, steep climb ends and the twelve archetypes take over.
///
/// Difficulty does **not** stop here. It used to: everything past this point
/// was flat, and the note that used to sit here said there was a hard ceiling
/// and nowhere left to go. That described the settings rather than the game.
/// The real ceilings are the readability rule in [runSpeedFor] and the bat
/// clearance behind [_hardMinSpacing], and the first ramp stops well short of
/// both — so [lateRampAt] spends what is left over the rest of the pack.
///
/// What this constant still marks is the change in *kind*. Up to here a level
/// is a lesson, built from a mix that leans on what the player has just been
/// taught. Past it every level is one of [kArchetypes], so what a level asks
/// for rotates while how much it asks keeps rising.
const int kRampEndLevel = 300;

/// The bat and the spider each get a level of their own to be met in, right
/// after the taught five, so a new type is never learned under pressure but
/// the player does not wait long for one either.
const int kBatIntroLevel = 6;
const int kSpiderIntroLevel = 9;

/// Obstacle spacing at the start and the end of the ramp.
///
/// The start picks up exactly where level 5 leaves off: 498 units puts twelve
/// obstacles in a 6000 unit level, which is what level 5 has. The lower bound
/// is set by [kBatCommitGap] — a bat needs room either side to be fair, so
/// nothing may ever be packed tighter than that plus a margin.
const double _startSpacing = 498;
const double _endSpacing = 186;

/// How much clear track a generated level leaves at each end. Comfortably
/// inside [kMaxOpeningRun] and [kMaxRunOut], and outside every clearance.
const double _openingRun = 250;
const double _runOut = 265;

/// Spacing the generator will not go below, whatever the jitter rolls. Above
/// [kBatCommitGap] so a bat always has room to be flipped around.
const double _hardMinSpacing = 150;

enum ObstacleKind { bolted, hopper, blade, stone, fire, bat, spider }

/// A named mix of obstacle types.
///
/// Past [kRampEndLevel] what a level asks for rotates through these while how
/// much it asks keeps climbing, so two levels a thousand apart differ in both.
/// Weights are relative.
class Archetype {
  const Archetype(this.name, this.weights);

  final String name;
  final Map<ObstacleKind, double> weights;
}

const List<Archetype> kArchetypes = [
  Archetype('swarm', {
    ObstacleKind.hopper: 5,
    ObstacleKind.bat: 3,
    ObstacleKind.bolted: 2,
    ObstacleKind.blade: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.stone: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('furnace', {
    ObstacleKind.fire: 5,
    ObstacleKind.stone: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.hopper: 1,
    ObstacleKind.blade: 1,
    ObstacleKind.bat: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('canopy', {
    ObstacleKind.spider: 5,
    ObstacleKind.blade: 4,
    ObstacleKind.hopper: 2,
    ObstacleKind.bolted: 2,
    ObstacleKind.bat: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.stone: 1,
  }),
  Archetype('gauntlet', {
    ObstacleKind.bolted: 5,
    ObstacleKind.blade: 4,
    ObstacleKind.stone: 2,
    ObstacleKind.hopper: 2,
    ObstacleKind.fire: 1,
    ObstacleKind.bat: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('balanced', {
    ObstacleKind.bolted: 2,
    ObstacleKind.hopper: 2,
    ObstacleKind.blade: 2,
    ObstacleKind.stone: 2,
    ObstacleKind.fire: 2,
    ObstacleKind.bat: 2,
    ObstacleKind.spider: 2,
  }),
  Archetype('commitment', {
    ObstacleKind.bat: 5,
    ObstacleKind.fire: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.spider: 2,
    ObstacleKind.hopper: 1,
    ObstacleKind.blade: 1,
    ObstacleKind.stone: 1,
  }),
  // The six below exist because the back of the pack is 9,700 levels long. The
  // six above were written for a pack a sixth of this size, and at this length
  // each of them would come round about 1,600 times. Difficulty does keep
  // rising past level 300, but slowly — what is left after the first ramp is
  // real and finite — so variety has to carry most of the distance.
  //
  // Each one pairs two types the first six never lean on together, so it is a
  // new question rather than a reshuffle of an old one.
  Archetype('cavein', {
    // Both of these drop across the band on their own clock, one from each
    // surface. The whole level is gates that slam rather than a surface to
    // pick.
    ObstacleKind.stone: 5,
    ObstacleKind.spider: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.hopper: 1,
    ObstacleKind.blade: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.bat: 1,
  }),
  Archetype('crossfire', {
    // Neither belongs to a surface. A blade says be at the far end of the
    // band, a bat says do not move — so the reading has to happen early and
    // the answer is where you already are.
    ObstacleKind.blade: 5,
    ObstacleKind.bat: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.hopper: 2,
    ObstacleKind.stone: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('scramble', {
    // Hoppers are the one obstacle with two right answers, fires are the one
    // that takes the choice away for a moment. Together they are a rhythm
    // with holes punched in it.
    ObstacleKind.hopper: 5,
    ObstacleKind.fire: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.blade: 1,
    ObstacleKind.stone: 1,
    ObstacleKind.bat: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('pinch', {
    // Bolted enemies demand a flip; spiders keep shutting the surface a flip
    // would go to. The ceiling is a place you visit, never a place you stay.
    ObstacleKind.bolted: 5,
    ObstacleKind.spider: 4,
    ObstacleKind.hopper: 2,
    ObstacleKind.blade: 1,
    ObstacleKind.stone: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.bat: 1,
  }),
  Archetype('anvil', {
    // A bat is answered a second early, a stone is answered on the exact
    // beat. Alternating between the two is the hardest reading in the game
    // that does not need a new obstacle to exist.
    ObstacleKind.bat: 5,
    ObstacleKind.stone: 4,
    ObstacleKind.bolted: 2,
    ObstacleKind.hopper: 1,
    ObstacleKind.blade: 1,
    ObstacleKind.fire: 1,
    ObstacleKind.spider: 1,
  }),
  Archetype('flashpoint', {
    // A fire closes one surface on a timer, a blade crosses both. The gap
    // between them is the level.
    ObstacleKind.fire: 5,
    ObstacleKind.blade: 4,
    ObstacleKind.hopper: 2,
    ObstacleKind.bolted: 2,
    ObstacleKind.stone: 1,
    ObstacleKind.bat: 1,
    ObstacleKind.spider: 1,
  }),
];

/// 0 at the first generated level, 1 once the first ramp is over.
double rampAt(int id) {
  if (id <= kFirstGeneratedLevel) return 0;
  if (id >= kRampEndLevel) return 1;
  return (id - kFirstGeneratedLevel) / (kRampEndLevel - kFirstGeneratedLevel);
}

/// 0 at [kRampEndLevel], 1 at the last level in the pack.
///
/// The second climb. The first ramp spends most of what the physics allows in
/// 300 levels, and this spends what is left over the other 9,700 — so a level
/// is always a little harder than the one before it, all the way to the end of
/// the pack.
///
/// It is deliberately slow. What is left after level 300 is real but finite,
/// and stretched across 9,700 levels one step is around a hundredth of a
/// percent: level 5,000 and level 5,001 are the same level to play. The climb
/// is only legible across hundreds of levels, and nobody should pretend
/// otherwise. What it buys is that the back of the pack is genuinely harder
/// than the middle rather than flat.
double lateRampAt(int id) {
  if (id <= kRampEndLevel) return 0;
  if (id >= kTotalLevels) return 1;
  return (id - kRampEndLevel) / (kTotalLevels - kRampEndLevel);
}

/// Speed steps rather than a slope, so a level feels authored at one pace
/// instead of drifting. Every step is a noticeable change in reading time.
///
/// The ceiling is 310 and it is not a taste: the camera shows 470 units ahead
/// of the character, and section 5 requires every obstacle to be visible for
/// at least 1.5 seconds before it is reached. 470 / 1.5 is 313, so 310 is the
/// fastest this game can run and still be fair. Past it the pack would stop
/// being rhythm and start being reflex.
double runSpeedFor(int id) {
  final t = rampAt(id);
  if (t < 1) {
    if (t < 0.25) return 200;
    if (t < 0.50) return 220;
    if (t < 0.72) return 240;
    if (t < 0.88) return 260;
    return 280;
  }
  // The second climb, over the remaining 9,700 levels.
  final late = lateRampAt(id);
  if (late < 0.34) return 280;
  if (late < 0.67) return 295;
  return 310;
}

/// Picks up where the hand placed levels left off and tightens to the floor
/// the hop air time allows.
double hopPeriodFor(int id) {
  final period = 2.0 - 1.0 * rampAt(id) - 0.05 * lateRampAt(id);
  // Never so tight that a hop cannot finish inside its own period. This is
  // what stops the second climb from making hoppers *easier*: past the floor
  // a hopper is airborne almost always, and a hopper in the air is something
  // you run underneath.
  return max(period, kHopAirTime + 0.25);
}

/// Obstacle spacing, and through it how many a level holds.
///
/// The second climb takes this from the first ramp's 186 down to
/// [_hardMinSpacing]. Together with the speed rise that is the largest change
/// available after level 300: a 9,300 unit level packed at 150 holds around
/// 60 obstacles where a 8,400 unit one at 186 holds 43.
double spacingFor(int id) {
  final first = _startSpacing - (_startSpacing - _endSpacing) * rampAt(id);
  return first - (_endSpacing - _hardMinSpacing) * lateRampAt(id);
}

/// How often a timed obstacle is in its dangerous state as the character
/// arrives. Rises with the ramp, so early levels mostly wave you through and
/// late ones mostly do not.
///
/// Stops at 0.95 rather than 1. At 1 every blade, stone, fire and spider in
/// the pack is lethal at the exact moment you reach it, which stops being a
/// timing window and becomes a wall.
double _threatChanceFor(int id) =>
    0.35 + 0.45 * rampAt(id) + 0.15 * lateRampAt(id);

/// The mix a level is built from.
Archetype archetypeFor(int id) {
  // Teaching levels for the two new types. The new one dominates, but every
  // type already taught still turns up: a level that drops the things the
  // player just learned reads as a different, emptier game.
  if (id == kBatIntroLevel) {
    return const Archetype('first bats', {
      ObstacleKind.bat: 5,
      ObstacleKind.bolted: 2,
      ObstacleKind.hopper: 2,
      ObstacleKind.blade: 1.5,
      ObstacleKind.stone: 1.5,
      ObstacleKind.fire: 1.5,
    });
  }
  if (id == kSpiderIntroLevel) {
    return const Archetype('first spiders', {
      ObstacleKind.spider: 5,
      ObstacleKind.bolted: 2,
      ObstacleKind.hopper: 2,
      ObstacleKind.blade: 1.5,
      ObstacleKind.stone: 1.5,
      ObstacleKind.fire: 1.5,
    });
  }
  // Right after each introduction, keep the new type present but no longer
  // the point of the level, so it is practised rather than crammed.
  if (id > kBatIntroLevel && id < kSpiderIntroLevel) {
    return const Archetype('settling in', {
      ObstacleKind.bolted: 3,
      ObstacleKind.hopper: 3,
      ObstacleKind.bat: 2,
      ObstacleKind.blade: 2,
      ObstacleKind.stone: 2,
      ObstacleKind.fire: 2,
    });
  }
  // Through the ramp, lean on the types the player already knows and let the
  // two animals arrive gradually.
  if (id < kRampEndLevel) {
    final t = rampAt(id);
    return Archetype('ramp', {
      ObstacleKind.bolted: 3,
      ObstacleKind.hopper: 3,
      ObstacleKind.blade: 1.5 + t,
      ObstacleKind.stone: 1.5 + t,
      ObstacleKind.fire: 1.5 + 1.5 * t,
      ObstacleKind.bat: 0.4 + 2.1 * t,
      ObstacleKind.spider: 0.4 + 2.1 * t,
    });
  }
  return kArchetypes[Random(id * 7919 + 17).nextInt(kArchetypes.length)];
}

/// Builds level [id]. Deterministic: the same id always gives the same level.
LevelModel generateLevel(int id) {
  final random = Random(id * 92821 + 7);
  final runSpeed = runSpeedFor(id);
  final hopPeriod = hopPeriodFor(id);
  final length = runSpeed * kLevelSeconds;
  final threat = _threatChanceFor(id);

  final xs = _slots(id, length, random);
  final kinds = _assign(id, xs.length, random);

  final bolted = <Bolted>[];
  final hoppers = <Hopper>[];
  final blades = <Blade>[];
  final stones = <Stone>[];
  final fires = <Fire>[];
  final bats = <Bat>[];
  final spiders = <Spider>[];

  // Remembers the last fire so two facing each other are never crowded
  // together, which would close the band with no way through.
  double? lastFireX;
  Surface lastFireSurface = Surface.floor;

  for (var i = 0; i < xs.length; i++) {
    final x = xs[i];
    final arrival = x / runSpeed;
    final dangerous = random.nextDouble() < threat;

    switch (kinds[i]) {
      case ObstacleKind.bolted:
        bolted.add(Bolted(x: x, surface: _surface(random)));

      case ObstacleKind.hopper:
        hoppers.add(Hopper(
          x: x,
          surface: _surface(random),
          phase: _phase(
            arrival,
            hopPeriod,
            dangerous
                // Resting on its surface: it has to be jumped or flipped away
                // from, which is the harder of the hopper's two answers.
                ? _pick(random, kHopAirTime + 0.08, hopPeriod - 0.08)
                // Mid hop, so the character runs underneath it.
                : _pick(random, 0.12, kHopAirTime - 0.12),
          ),
        ));

      case ObstacleKind.blade:
        final period = _round(_pick(random, 1.4, 2.4));
        blades.add(Blade(
          x: x,
          period: period,
          // A blade is read by which end it is at. Park it against one surface
          // so the other one is genuinely open.
          phase: _phase(
            arrival,
            period,
            random.nextBool() ? 0 : period / 2,
          ),
        ));

      case ObstacleKind.stone:
        final period = _round(_pick(random, 2.0, 3.2));
        stones.add(Stone(
          x: x,
          surface: _surface(random),
          period: _phaseSafePeriod(period),
          phase: _phase(
            arrival,
            _phaseSafePeriod(period),
            dangerous
                // Part way through the winch back: it still blocks its own
                // side, so the character has to be on the other one.
                ? kStoneFallTime + kStoneHoldTime + kStoneRiseTime * 0.45
                // Resting. A stone at full stretch closes the whole band, so
                // it is never left extended on arrival — that is not a hard
                // gate, it is an unavoidable death.
                : _pick(
                    random,
                    kStoneCycleTime + 0.1,
                    _phaseSafePeriod(period) - 0.1,
                  ),
          ),
        ));

      case ObstacleKind.fire:
        final period = _round(_pick(random, 2.6, 3.6));
        // Two vents facing each other need room, or both can be lit as the
        // character arrives.
        var surface = _surface(random);
        final previous = lastFireX;
        if (previous != null && x - previous < kOppositeFireGap + 20) {
          surface = lastFireSurface;
        }
        fires.add(Fire(
          x: x,
          surface: surface,
          period: period,
          phase: _phase(
            arrival,
            period,
            dangerous
                // Fully alight: the flip has to already have happened.
                ? kFireWarnTime + kFireRiseTime + kFireHoldTime * 0.5
                : _pick(random, kFireCycleTime + 0.15, period - 0.15),
          ),
        ));
        lastFireX = x;
        lastFireSurface = surface;

      case ObstacleKind.bat:
        final period = _round(_pick(random, 1.8, 2.8));
        bats.add(Bat(
          x: x,
          period: period,
          // A bat is dangerous whatever its phase, because it is the air that
          // is closed, not a surface. The drift only changes how it looks.
          phase: _wrap(_round(random.nextDouble() * period), period),
        ));

      case ObstacleKind.spider:
        final period = _round(_pick(random, 3.4, 4.6));
        spiders.add(Spider(
          x: x,
          period: period,
          phase: _phase(
            arrival,
            period,
            dangerous
                // Hanging: the ceiling is shut and so is the air under it.
                ? kSpiderDropTime + kSpiderHangTime * 0.5
                // Tucked up in the canopy, harmless.
                : _pick(random, kSpiderCycleTime + 0.15, period - 0.15),
          ),
        ));
    }
  }

  return LevelModel(
    id: id,
    length: length,
    runSpeed: runSpeed,
    hopPeriod: hopPeriod,
    bolted: bolted,
    hoppers: hoppers,
    blades: blades,
    stones: stones,
    fires: fires,
    bats: bats,
    spiders: spiders,
    checkpoints: _checkpoints(length),
  );
}

/// How far apart coins are laid along one surface. Both surfaces get a row,
/// so a level carries roughly twice this many.
const double kCoinSpacing = 340;

/// Coins are kept this far from any obstacle, so a row of them never reads as
/// pointing into something that kills.
const double kCoinObstacleGap = 55;

/// Lays a row of coins along each surface.
///
/// The two rows are offset by half a spacing, so the floor row and the ceiling
/// row never line up. Sweeping a level clean means flipping for them, which is
/// what turns the flip button into something you use for reward rather than
/// only to survive.
///
/// Every coin is checked before it is placed: a character resting on that
/// surface, at the moment it would arrive, must not be hit by anything. That
/// check is exact rather than approximate, because forward speed never changes
/// and so arrival time is always `x / runSpeed`. It means no coin is ever
/// stranded inside a blade's sweep, under a hanging spider, or in a flame.
///
/// Coins are a bonus, never a demand. Nothing here makes a level harder.
List<Coin> coinsFor(LevelModel level) {
  final index = LevelIndex(level);
  final obstacles = level.obstacleXs;
  final coins = <Coin>[];

  bool clearOfObstacles(double x) {
    for (final at in obstacles) {
      if ((at - x).abs() < kCoinObstacleGap) return false;
    }
    return true;
  }

  /// Would a character standing here, right now, still be alive?
  bool restingIsSafe(double centreX, {required bool gravityUp}) => !index.hits(
        RunState(
          x: centreX - kPlayerSize / 2,
          y: restingY(gravityUp: gravityUp),
          gravityUp: gravityUp,
        ),
      );

  void layRow({required bool gravityUp, required double from}) {
    final y = restingY(gravityUp: gravityUp) + kPlayerSize / 2;
    final last = level.length - kCoinSpacing / 2;

    for (var slot = from; slot < last; slot += kCoinSpacing) {
      // If the ideal spot is blocked, shuffle along a little rather than
      // losing the slot: a crowded level should not end up with fewer coins
      // than an empty one.
      for (var nudge = 0.0; nudge <= 120; nudge += 30) {
        final x = slot + nudge;
        if (x >= last) break;
        if (!clearOfObstacles(x)) continue;
        if (!restingIsSafe(x, gravityUp: gravityUp)) continue;
        coins.add(Coin(x: _round(x), y: _round(y)));
        break;
      }
    }
  }

  layRow(gravityUp: false, from: kCoinSpacing);
  layRow(gravityUp: true, from: kCoinSpacing * 1.5);

  // The collection loop stops at the first coin out of reach, so the two rows
  // have to be merged into one ordered list.
  coins.sort((a, b) => a.x.compareTo(b.x));
  return coins;
}

/// Evenly spaced positions with a little jitter, inside every clearance.
List<double> _slots(int id, double length, Random random) {
  final spacing = spacingFor(id);
  final first = _openingRun;
  final last = length - _runOut;
  final span = last - first;

  final count = max(2, (span / spacing).round() + 1);
  final step = span / (count - 1);

  // Never let jitter close a gap past what a bat needs either side.
  final jitter = max(0.0, min(22.0, (step - _hardMinSpacing) / 2));

  return [
    for (var i = 0; i < count; i++)
      _round(first + step * i + (random.nextDouble() * 2 - 1) * jitter),
  ];
}

/// Every type the player has met by level [id].
///
/// A level is never allowed to drop one of these. Weights alone would let a
/// roll come up with no blades at all, and a level missing a type the player
/// already learned reads as a different, emptier game than the one before it.
List<ObstacleKind> taughtBy(int id) => [
      ObstacleKind.bolted,
      ObstacleKind.hopper,
      ObstacleKind.blade,
      ObstacleKind.stone,
      ObstacleKind.fire,
      if (id >= kBatIntroLevel) ObstacleKind.bat,
      if (id >= kSpiderIntroLevel) ObstacleKind.spider,
    ];

/// Draws [count] obstacle kinds from the level's archetype.
///
/// One of every taught type is reserved first, then the rest are drawn by
/// weight, then the whole lot is shuffled so the guaranteed ones are not all
/// bunched at the start of the level.
List<ObstacleKind> _assign(int id, int count, Random random) {
  final weights = archetypeFor(id).weights;
  final kinds = weights.keys.toList();
  final total = weights.values.fold(0.0, (a, b) => a + b);

  final chosen = <ObstacleKind>[...taughtBy(id).take(count)];

  while (chosen.length < count) {
    var roll = random.nextDouble() * total;
    var picked = kinds.last;
    for (final kind in kinds) {
      roll -= weights[kind]!;
      if (roll <= 0) {
        picked = kind;
        break;
      }
    }
    chosen.add(picked);
  }

  chosen.shuffle(random);
  return chosen;
}

List<double> _checkpoints(double length) => [
      for (var x = 2000.0; x < length - 200; x += 2000) x,
    ];

Surface _surface(Random random) =>
    random.nextBool() ? Surface.ceiling : Surface.floor;

double _pick(Random random, double from, double to) =>
    from + random.nextDouble() * (to - from);

/// A stone's period has to outlast one whole slam.
double _phaseSafePeriod(double period) =>
    max(period, kStoneCycleTime + kStoneCycleTime * 0.25);

/// The phase that puts [targetCycle] under the character at [arrival].
///
/// This is what makes generated levels playable rather than lucky: every timed
/// obstacle is aimed at the moment the character actually gets there, and
/// arrival is exact because forward speed never changes.
double _phase(double arrival, double period, double targetCycle) {
  var phase = (targetCycle - arrival) % period;
  if (phase < 0) phase += period;
  // Round first, then guard. Rounding can land exactly on the period, and the
  // valid range is half open, so guarding before rounding lets that through.
  return _wrap(_round(phase), period);
}

/// Keeps a phase inside the half open range the validator checks.
double _wrap(double phase, double period) => phase >= period ? 0 : phase;

/// Three decimals. Keeps the JSON small and keeps a level byte identical
/// however it was rebuilt.
double _round(double value) => (value * 1000).roundToDouble() / 1000;
