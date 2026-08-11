/// Headless simulation of a run, plus the solver and validator built on it.
///
/// This file must never import Flame, Flutter or dart:ui. The scene drives the
/// exact same functions, so what the tests prove is what the player gets.
library;

import 'level_model.dart';
import 'physics.dart';
import 'run_state.dart';

/// A level with its enemies sorted by x, so a collision check only looks at
/// the handful of enemies near the character.
class LevelIndex {
  LevelIndex(this.level)
      : _bolted = [...level.bolted]..sort((a, b) => a.x.compareTo(b.x)),
        _hoppers = [...level.hoppers]..sort((a, b) => a.x.compareTo(b.x)),
        _blades = [...level.blades]..sort((a, b) => a.x.compareTo(b.x)),
        _stones = [...level.stones]..sort((a, b) => a.x.compareTo(b.x)),
        _fires = [...level.fires]..sort((a, b) => a.x.compareTo(b.x)),
        _bats = [...level.bats]..sort((a, b) => a.x.compareTo(b.x)),
        _spiders = [...level.spiders]..sort((a, b) => a.x.compareTo(b.x)) {
    _bladeX = [for (final e in _blades) e.x];
    _stoneX = [for (final e in _stones) e.x];
    _fireX = [for (final e in _fires) e.x];
    _boltedX = [for (final e in _bolted) e.x];
    _hopperX = [for (final e in _hoppers) e.x];
    for (final enemy in _bolted) {
      final box = enemy.box.deflate(kHitboxShrink);
      _boltedLeft.add(box.left);
      _boltedRight.add(box.right);
      _boltedTop.add(box.top);
      _boltedBottom.add(box.bottom);
    }
    for (final enemy in _hoppers) {
      _hopperCeiling.add(enemy.surface.isCeiling);
      _hopperPhase.add(enemy.phase);
      _hopperLeft.add(enemy.x - kHopperSize / 2 + kHitboxShrink);
      _hopperRight.add(enemy.x + kHopperSize / 2 - kHitboxShrink);
    }
    for (final blade in _blades) {
      _bladeLeft.add(blade.x - kBladeWidth / 2 + kHitboxShrink);
      _bladeRight.add(blade.x + kBladeWidth / 2 - kHitboxShrink);
    }
    for (final stone in _stones) {
      _stoneCeiling.add(stone.surface.isCeiling);
      _stoneLeft.add(stone.x - kStoneSize / 2 + kHitboxShrink);
      _stoneRight.add(stone.x + kStoneSize / 2 - kHitboxShrink);
    }
    for (final fire in _fires) {
      _fireCeiling.add(fire.surface.isCeiling);
      _fireLeft.add(fire.x - kFireWidth / 2 + kHitboxShrink);
      _fireRight.add(fire.x + kFireWidth / 2 - kHitboxShrink);
    }
    for (final bat in _bats) {
      _batLeft.add(bat.x - kBatWidth / 2 + kHitboxShrink);
      _batRight.add(bat.x + kBatWidth / 2 - kHitboxShrink);
    }
    for (final spider in _spiders) {
      _spiderLeft.add(spider.x - kSpiderSize / 2 + kHitboxShrink);
      _spiderRight.add(spider.x + kSpiderSize / 2 - kHitboxShrink);
    }
    _batX = [for (final e in _bats) e.x];
    _spiderX = [for (final e in _spiders) e.x];
  }

  final LevelModel level;
  final List<Bolted> _bolted;
  final List<Hopper> _hoppers;
  final List<Blade> _blades;
  final List<Stone> _stones;
  final List<Fire> _fires;
  final List<Bat> _bats;
  final List<Spider> _spiders;
  late final List<double> _boltedX;
  late final List<double> _hopperX;
  late final List<double> _bladeX;
  late final List<double> _stoneX;
  late final List<double> _fireX;
  late final List<double> _batX;
  late final List<double> _spiderX;

  // Flat hit box edges. The solver calls this hundreds of thousands of times
  // per level, so nothing here allocates.
  final List<double> _boltedLeft = [];
  final List<double> _boltedRight = [];
  final List<double> _boltedTop = [];
  final List<double> _boltedBottom = [];

  final List<bool> _hopperCeiling = [];
  final List<double> _hopperPhase = [];
  final List<double> _hopperLeft = [];
  final List<double> _hopperRight = [];

  final List<double> _bladeLeft = [];
  final List<double> _bladeRight = [];

  final List<bool> _stoneCeiling = [];
  final List<double> _stoneLeft = [];
  final List<double> _stoneRight = [];

  final List<bool> _fireCeiling = [];
  final List<double> _fireLeft = [];
  final List<double> _fireRight = [];

  final List<double> _batLeft = [];
  final List<double> _batRight = [];

  final List<double> _spiderLeft = [];
  final List<double> _spiderRight = [];

  static const double _reach = kBoltedWidth;
  static const double _hopperInnerSize = kHopperSize - kHitboxShrink * 2;
  static const double _bladeInnerHeight = kBladeHeight - kHitboxShrink * 2;
  static const double _stoneInnerSize = kStoneSize - kHitboxShrink * 2;
  static const double _batInnerHeight = kBatHeight - kHitboxShrink * 2;
  static const double _spiderInnerSize = kSpiderSize - kHitboxShrink * 2;

  bool hits(RunState state) {
    final left = state.x + kHitboxShrink;
    final right = state.x + kPlayerSize - kHitboxShrink;
    final top = state.y + kHitboxShrink;
    final bottom = state.y + kPlayerSize - kHitboxShrink;
    final from = left - _reach;
    final to = right + _reach;

    for (var i = _lowerBound(_boltedX, from);
        i < _bolted.length && _boltedX[i] <= to;
        i++) {
      if (left < _boltedRight[i] &&
          _boltedLeft[i] < right &&
          top < _boltedBottom[i] &&
          _boltedTop[i] < bottom) {
        return true;
      }
    }

    if (_hoppers.isEmpty &&
        _blades.isEmpty &&
        _stones.isEmpty &&
        _fires.isEmpty &&
        _bats.isEmpty &&
        _spiders.isEmpty) {
      return false;
    }
    final levelTime = state.x / level.runSpeed;

    final period = level.hopPeriod;
    for (var i = _lowerBound(_hopperX, from);
        i < _hoppers.length && _hopperX[i] <= to;
        i++) {
      if (left >= _hopperRight[i] || _hopperLeft[i] >= right) continue;
      final height = hopHeightAt((levelTime + _hopperPhase[i]) % period);
      final enemyTop = _hopperCeiling[i]
          ? kCeilingSurfaceY + height + kHitboxShrink
          : kFloorSurfaceY - height - kHopperSize + kHitboxShrink;
      if (top < enemyTop + _hopperInnerSize && enemyTop < bottom) return true;
    }

    for (var i = _lowerBound(_bladeX, from);
        i < _blades.length && _bladeX[i] <= to;
        i++) {
      if (left >= _bladeRight[i] || _bladeLeft[i] >= right) continue;
      final bladeTop = _blades[i].topAt(levelTime) + kHitboxShrink;
      if (top < bladeTop + _bladeInnerHeight && bladeTop < bottom) return true;
    }

    for (var i = _lowerBound(_stoneX, from);
        i < _stones.length && _stoneX[i] <= to;
        i++) {
      if (left >= _stoneRight[i] || _stoneLeft[i] >= right) continue;
      final offset = _stones[i].offsetAt(levelTime);
      final stoneTop = _stoneCeiling[i]
          ? kCeilingSurfaceY + offset + kHitboxShrink
          : kFloorSurfaceY - offset - kStoneSize + kHitboxShrink;
      if (top < stoneTop + _stoneInnerSize && stoneTop < bottom) return true;
    }

    for (var i = _lowerBound(_fireX, from);
        i < _fires.length && _fireX[i] <= to;
        i++) {
      if (left >= _fireRight[i] || _fireLeft[i] >= right) continue;
      // The flame is the hit box, so a dark vent cannot kill anything and a
      // short one only catches you low down.
      final height = _fires[i].heightAt(levelTime) - kHitboxShrink * 2;
      if (height <= 0) continue;
      final fireTop = _fireCeiling[i]
          ? kCeilingSurfaceY + kHitboxShrink
          : kFloorSurfaceY - kHitboxShrink - height;
      if (top < fireTop + height && fireTop < bottom) return true;
    }

    // A bat sits in the middle of the band and touches neither surface, so
    // this can only fire while the character is off a surface.
    for (var i = _lowerBound(_batX, from);
        i < _bats.length && _batX[i] <= to;
        i++) {
      if (left >= _batRight[i] || _batLeft[i] >= right) continue;
      final batTop = _bats[i].centreAt(levelTime) -
          kBatHeight / 2 +
          kHitboxShrink;
      if (top < batTop + _batInnerHeight && batTop < bottom) return true;
    }

    for (var i = _lowerBound(_spiderX, from);
        i < _spiders.length && _spiderX[i] <= to;
        i++) {
      if (left >= _spiderRight[i] || _spiderLeft[i] >= right) continue;
      final spiderTop =
          kCeilingSurfaceY + _spiders[i].dropAt(levelTime) + kHitboxShrink;
      if (top < spiderTop + _spiderInnerSize && spiderTop < bottom) return true;
    }

    return false;
  }

  static int _lowerBound(List<double> sorted, double value) {
    var low = 0;
    var high = sorted.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (sorted[mid] < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

/// Applies one input. Flips are absolute, jumps only work when grounded.
void applyInput(RunState state, RunInput input) {
  if (!state.isRunning) return;
  switch (input) {
    case RunInput.none:
      break;
    case RunInput.flipUp:
      _flip(state, up: true);
    case RunInput.flipDown:
      _flip(state, up: false);
    case RunInput.jump:
      // No double jump, no jump while airborne.
      if (!state.grounded) return;
      state.vy = state.gravityUp ? kJumpVelocity : -kJumpVelocity;
      state.grounded = false;
  }
}

void _flip(RunState state, {required bool up}) {
  // Pressing the surface it is already on does nothing.
  if (state.gravityUp == up) return;
  state.gravityUp = up;
  state.vy = up ? -kFlipImpulse : kFlipImpulse;
  state.grounded = false;
}

/// Advances one fixed step. Forward motion is automatic and constant.
void advance(LevelIndex index, RunState state, [double dt = kFixedStep]) {
  if (!state.isRunning) return;
  final level = index.level;

  state.x += level.runSpeed * dt;
  state.elapsed += dt;

  state.vy += gravityFor(gravityUp: state.gravityUp) * dt;
  state.y += state.vy * dt;

  // Clamp to the band on both sides, however fast the fall.
  if (state.y <= kMinPlayerY) {
    state.y = kMinPlayerY;
    if (state.vy < 0) state.vy = 0;
    state.grounded = state.gravityUp;
  } else if (state.y >= kMaxPlayerY) {
    state.y = kMaxPlayerY;
    if (state.vy > 0) state.vy = 0;
    state.grounded = !state.gravityUp;
  } else {
    state.grounded = false;
  }

  if (state.x >= level.length) {
    state.x = level.length;
    state.status = RunStatus.won;
    return;
  }

  if (index.hits(state)) state.status = RunStatus.dead;
}

/// Drives one level. The scene owns one of these; so do the tests.
class LevelSimulator {
  LevelSimulator(LevelModel level)
      : index = LevelIndex(level),
        state = RunState() {
    _taken = List<bool>.filled(this.level.coins.length, false);
  }

  final LevelIndex index;
  RunState state;

  /// Which coins have been picked up, by index into `level.coins`.
  ///
  /// Held here rather than on [RunState] so that copying a state stays cheap.
  late List<bool> _taken;

  /// Coins collected since the last step, for the scene to animate. Cleared
  /// every step, so the caller reads it immediately or not at all.
  final List<int> justCollected = [];

  LevelModel get level => index.level;

  bool isCollected(int coin) => _taken[coin];

  void restart({int lives = kStartingLives}) {
    state = RunState(lives: lives);
    _taken.fillRange(0, _taken.length, false);
    justCollected.clear();
  }

  void input(RunInput input) => applyInput(state, input);

  void step([double dt = kFixedStep]) {
    justCollected.clear();
    advance(index, state, dt);
    _collect();
  }

  /// Picks up any coin the character is touching.
  ///
  /// Runs after the step rather than inside [advance], because the solver
  /// drives [advance] directly and coins neither block nor kill — they must
  /// not cost anything in the search.
  void _collect() {
    if (level.coins.isEmpty || !state.isRunning) return;
    final coins = level.coins;
    final left = state.x;
    final right = state.x + kPlayerSize;

    for (var i = 0; i < coins.length; i++) {
      if (_taken[i]) continue;
      final coin = coins[i];
      // Coins are sorted by x, so once one is beyond reach so is the rest.
      if (coin.x - kCoinSize > right) break;
      if (coin.x + kCoinSize < left) continue;

      // Grown rather than shrunk: a generous reward box feels good, where a
      // generous lethal one would feel unfair.
      final box = coin.box.deflate(-kCoinReach);
      if (state.box.overlaps(box)) {
        _taken[i] = true;
        state.coins++;
        justCollected.add(i);
      }
    }
  }

  /// True when the death being handled is the last life.
  bool get outOfLives => state.lives <= 1;

  /// Takes a life and puts the character back at the last checkpoint. When the
  /// last life goes, the level restarts from the beginning with three again.
  void respawn() {
    final remaining = state.lives - 1;
    final elapsed = state.elapsed;
    justCollected.clear();

    if (remaining <= 0) {
      _taken.fillRange(0, _taken.length, false);
      state = RunState(elapsed: elapsed);
      return;
    }

    _restoreAtCheckpoint(lives: remaining, elapsed: elapsed);
  }

  /// Puts the character back at the last checkpoint with one life, without
  /// taking one away.
  ///
  /// This is the extra life a player can earn, and it deliberately does not go
  /// through [respawn]: that counts the death, and on the last life it throws
  /// the whole run away and starts the level again. What is being bought here
  /// is precisely the run that would otherwise have been lost.
  void revive() {
    justCollected.clear();
    _restoreAtCheckpoint(lives: 1, elapsed: state.elapsed);
  }

  void _restoreAtCheckpoint({required int lives, required double elapsed}) {
    final checkpoint = level.checkpointBehind(state.x);
    // Coins past the checkpoint go back, since that stretch is about to be
    // run again. Everything already banked behind it stays banked.
    var kept = 0;
    for (var i = 0; i < _taken.length; i++) {
      if (level.coins[i].x >= checkpoint) {
        _taken[i] = false;
      } else if (_taken[i]) {
        kept++;
      }
    }

    state = RunState(
      x: checkpoint,
      lives: lives,
      elapsed: elapsed,
      checkpointX: checkpoint,
      coins: kept,
    );
  }
}

/// A sequence of inputs that finishes a level, one entry per decision tick.
class RunPlan {
  const RunPlan(this.inputs, this.stepsPerDecision);

  final List<RunInput> inputs;
  final int stepsPerDecision;

  int get actions => inputs.where((i) => i != RunInput.none).length;

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      if (input == RunInput.none) continue;
      final seconds = i * stepsPerDecision * kFixedStep;
      buffer.write('${seconds.toStringAsFixed(2)}:'
          '${switch (input) {
        RunInput.flipUp => 'UP',
        RunInput.flipDown => 'DOWN',
        RunInput.jump => 'JUMP',
        RunInput.none => '',
      }} ');
    }
    return buffer.toString().trim();
  }
}

class _Node {
  _Node(this.state, this.parent, this.input);

  final RunState state;
  final int parent;
  final RunInput input;
}

/// Searches for an input sequence that finishes the level without dying.
///
/// Decisions are only allowed every [stepsPerDecision] fixed steps, which is
/// far coarser than a human plays, so anything this finds is comfortably
/// reachable. States are deduplicated on a quantised grid, so the search can
/// miss a solution but can never invent one: the plan it returns is replayed
/// exactly by [runPlan].
RunPlan? solveLevel(
  LevelModel level, {
  int stepsPerDecision = 4,
  int frontierCap = 4000,
}) {
  final index = LevelIndex(level);
  final totalSteps = (level.seconds / kFixedStep).ceil() + stepsPerDecision;
  final decisions = (totalSteps / stepsPerDecision).ceil();

  var layer = <_Node>[_Node(RunState(), -1, RunInput.none)];
  final layers = <List<_Node>>[layer];

  for (var decision = 0; decision < decisions; decision++) {
    final next = <_Node>[];
    final seen = <int>{};

    for (var n = 0; n < layer.length; n++) {
      final node = layer[n];
      final options = <RunInput>[
        RunInput.none,
        node.state.gravityUp ? RunInput.flipDown : RunInput.flipUp,
        if (node.state.grounded) RunInput.jump,
      ];

      for (final option in options) {
        final candidate = node.state.copy();
        applyInput(candidate, option);
        for (var s = 0; s < stepsPerDecision && candidate.isRunning; s++) {
          advance(index, candidate);
        }

        if (candidate.status == RunStatus.dead) continue;
        if (candidate.status == RunStatus.won) {
          layers.add([...next, _Node(candidate, n, option)]);
          return _reconstruct(layers, next.length, stepsPerDecision);
        }
        if (!seen.add(_key(candidate))) continue;
        if (next.length >= frontierCap) break;
        next.add(_Node(candidate, n, option));
      }
    }

    if (next.isEmpty) return null;
    layers.add(next);
    layer = next;
  }
  return null;
}

int _key(RunState state) {
  final y = ((state.y - kMinPlayerY) * 2).round().clamp(0, 511);
  final vy = ((state.vy / 8).round() + 96).clamp(0, 255);
  return (state.gravityUp ? 1 : 0) | (y << 1) | (vy << 10);
}

RunPlan _reconstruct(
  List<List<_Node>> layers,
  int goalIndex,
  int stepsPerDecision,
) {
  final inputs = <RunInput>[];
  var index = goalIndex;
  for (var depth = layers.length - 1; depth >= 1; depth--) {
    final node = layers[depth][index];
    inputs.add(node.input);
    index = node.parent;
  }
  return RunPlan(inputs.reversed.toList(), stepsPerDecision);
}

/// Replays a plan through the exact simulation and returns the final state.
RunState runPlan(LevelModel level, RunPlan plan) {
  final index = LevelIndex(level);
  final state = RunState();
  for (final input in plan.inputs) {
    applyInput(state, input);
    for (var s = 0; s < plan.stepsPerDecision && state.isRunning; s++) {
      advance(index, state);
    }
    if (!state.isRunning) break;
  }
  return state;
}

/// Result of checking a single level against the rules in CLAUDE.md.
class LevelValidation {
  const LevelValidation(this.level, this.problems, this.plan);

  final LevelModel level;
  final List<String> problems;
  final RunPlan? plan;

  bool get ok => problems.isEmpty;

  @override
  String toString() {
    if (!ok) return 'Level ${level.id}: ${problems.join('; ')}';
    final found = plan;
    // There is no plan when the level was checked without solving.
    return found == null
        ? 'Level ${level.id}: ok'
        : 'Level ${level.id}: ok (${found.actions} inputs)';
  }
}

/// Bolted enemies this close to the start or the door are unfair.
const double kBoltedClearance = 120;

/// Bolted enemies on opposite surfaces closer than this are impassable.
const double kOppositeBoltedGap = 60;

/// A blade blocks the whole band, so it needs even more room than a bolted
/// enemy at the start and the door.
const double kBladeClearance = 200;

/// Any faster than this and a blade cannot be read on approach.
const double kMinBladePeriod = 1.2;

/// A flame reaches most of the way across the band, so a vent needs room at
/// the start and the door like a blade does.
const double kFireClearance = 200;

/// How long a vent has to stay dark between burns. Without this a fire with a
/// short period is lit nearly all the time, which turns it into a bolted
/// enemy that happens to flicker.
const double kMinFireDarkTime = 0.9;

/// Two fires facing each other closer than this could both be lit as the
/// character arrives, which closes the band with no way through.
const double kOppositeFireGap = 260;

/// A bat needs room at the start and the door, because the character has to
/// already be on the right surface by the time it arrives.
const double kBatClearance = 200;

/// How much clear track a bat needs either side of any other obstacle.
///
/// This is the rule that makes bats fair. Inside a bat's span the character
/// can neither flip nor jump, so anything that *demands* a flip or a jump in
/// the same breath is impossible rather than hard. A flip takes about 0.27
/// seconds, which is 55 units at base speed, so this leaves room to commit
/// before the bat and to recover after it.
const double kBatCommitGap = 130;

/// A spider sweeps the ceiling on the way down and again on the way up, so its
/// period has to leave the ceiling open for at least this long in between.
/// Without it the ceiling is never usable and the spider is just a wall.
const double kMinSpiderClearTime = 0.8;

const double kSpiderClearance = 200;

/// No two obstacles of any kind may be closer than this. At base speed 60
/// units is under a third of a second, which is not a decision, it is a
/// coin toss.
const double kMinObstacleGap = 60;

/// The longest empty stretch allowed once a level is under way. At base speed
/// this is 3.5 seconds of holding still, which is already the edge of dead
/// time; anything more and the player is watching rather than playing.
const double kMaxObstacleGap = 700;

/// How much clear track a level may open with, before the first obstacle.
/// Longer than a normal gap, so the player can settle into the run.
const double kMaxOpeningRun = 900;

/// How much clear track may be left between the last obstacle and the door.
const double kMaxRunOut = 800;

/// Where the level leaves the player with nothing to do. Separate from
/// [validateLevel] so a test can report it on its own.
List<String> pacingProblems(LevelModel level) {
  final problems = <String>[];
  final xs = level.obstacleXs;

  if (xs.isEmpty) {
    problems.add('the level is empty');
    return problems;
  }

  if (xs.first > kMaxOpeningRun) {
    problems.add('it opens with ${xs.first.toStringAsFixed(0)} units of empty '
        'track, more than the $kMaxOpeningRun allowed');
  }

  for (var i = 1; i < xs.length; i++) {
    final gap = xs[i] - xs[i - 1];
    if (gap > kMaxObstacleGap) {
      problems.add('${gap.toStringAsFixed(0)} units of nothing between '
          '${xs[i - 1].toStringAsFixed(0)} and ${xs[i].toStringAsFixed(0)}');
    }
  }

  final runOut = level.length - xs.last;
  if (runOut > kMaxRunOut) {
    problems.add('${runOut.toStringAsFixed(0)} units of nothing between the '
        'last obstacle and the door');
  }

  return problems;
}

/// Checks [level] against every rule in CLAUDE.md.
///
/// With [solve] left on it also searches for an input sequence that finishes
/// the level, which is the only part that costs real time. Turn it off to
/// check the cheap structural rules over a whole pack — the exhaustive solve
/// belongs in `tool/generate_levels.dart`, which runs it across isolates at
/// authoring time.
LevelValidation validateLevel(LevelModel level, {bool solve = true}) {
  final problems = <String>[];

  final expectedLength = level.runSpeed * kLevelSeconds;
  if ((level.length - expectedLength).abs() > 0.5) {
    problems.add('length ${level.length} should be $expectedLength for a '
        '${level.runSpeed} unit per second level');
  }
  if (level.hopPeriod <= kHopAirTime) {
    problems.add('hopPeriod ${level.hopPeriod} is shorter than the '
        '${kHopAirTime.toStringAsFixed(2)}s a hop takes');
  }

  for (final enemy in level.bolted) {
    if (enemy.x < kBoltedClearance) {
      problems.add('bolted at ${enemy.x} is inside the start clearance');
    }
    if (enemy.x > level.length - kBoltedClearance) {
      problems.add('bolted at ${enemy.x} is inside the door clearance');
    }
  }

  for (var i = 0; i < level.bolted.length; i++) {
    for (var j = i + 1; j < level.bolted.length; j++) {
      final a = level.bolted[i];
      final b = level.bolted[j];
      final gap = (a.x - b.x).abs();
      if (a.surface != b.surface && gap < kOppositeBoltedGap) {
        problems.add('bolted at ${a.x} and ${b.x} are on opposite surfaces '
            '${gap.toStringAsFixed(0)} apart, which is impassable');
      }
      if (a.surface == b.surface && gap < kBoltedWidth) {
        problems.add('bolted at ${a.x} and ${b.x} overlap');
      }
    }
  }

  for (final hopper in level.hoppers) {
    if (hopper.x <= 0 || hopper.x >= level.length) {
      problems.add('hopper at ${hopper.x} is outside the level');
    }
    if (hopper.phase < 0 || hopper.phase >= level.hopPeriod) {
      problems.add('hopper phase ${hopper.phase} is outside '
          '0 to ${level.hopPeriod}');
    }
  }

  for (final blade in level.blades) {
    if (blade.x <= kBladeClearance ||
        blade.x >= level.length - kBladeClearance) {
      problems.add('blade at ${blade.x} is inside a clearance');
    }
    if (blade.period < kMinBladePeriod) {
      problems.add('blade period ${blade.period} is too fast to read');
    }
    if (blade.phase < 0 || blade.phase >= blade.period) {
      problems.add('blade phase ${blade.phase} is outside 0 to '
          '${blade.period}');
    }
  }

  for (final stone in level.stones) {
    if (stone.x <= 0 || stone.x >= level.length) {
      problems.add('stone at ${stone.x} is outside the level');
    }
    if (stone.period <= kStoneCycleTime) {
      problems.add('stone period ${stone.period} is shorter than the '
          '${kStoneCycleTime.toStringAsFixed(2)}s a slam takes');
    }
    if (stone.phase < 0 || stone.phase >= stone.period) {
      problems.add('stone phase ${stone.phase} is outside 0 to '
          '${stone.period}');
    }
  }

  for (final fire in level.fires) {
    if (fire.x <= kFireClearance ||
        fire.x >= level.length - kFireClearance) {
      problems.add('fire at ${fire.x} is inside a clearance');
    }
    if (fire.period <= kFireCycleTime + kMinFireDarkTime) {
      problems.add('fire period ${fire.period} leaves less than '
          '${kMinFireDarkTime}s of dark track to run through');
    }
    if (fire.phase < 0 || fire.phase >= fire.period) {
      problems.add('fire phase ${fire.phase} is outside 0 to ${fire.period}');
    }
  }

  // Two fires on opposite surfaces close together could both be lit as the
  // character arrives, which closes the band with no way through.
  for (var i = 0; i < level.fires.length; i++) {
    for (var j = i + 1; j < level.fires.length; j++) {
      final a = level.fires[i];
      final b = level.fires[j];
      if (a.surface == b.surface) continue;
      if ((a.x - b.x).abs() < kOppositeFireGap) {
        problems.add('fires at ${a.x} and ${b.x} face each other closer than '
            '$kOppositeFireGap apart');
      }
    }
  }

  for (final bat in level.bats) {
    if (bat.x <= kBatClearance || bat.x >= level.length - kBatClearance) {
      problems.add('bat at ${bat.x} is inside a clearance');
    }
    if (bat.period <= 0) {
      problems.add('bat period ${bat.period} is not positive');
    }
    if (bat.phase < 0 || bat.phase >= bat.period) {
      problems.add('bat phase ${bat.phase} is outside 0 to ${bat.period}');
    }
  }

  // A bat closes the air, so nothing may sit close enough to force the
  // character off a surface while it is passing one.
  for (final bat in level.bats) {
    for (final x in level.obstacleXs) {
      if (x == bat.x) continue;
      final gap = (x - bat.x).abs();
      if (gap < kBatCommitGap) {
        problems.add('bat at ${bat.x} is ${gap.toStringAsFixed(0)} from the '
            'obstacle at $x, closer than the $kBatCommitGap a flip needs');
      }
    }
  }

  for (final spider in level.spiders) {
    if (spider.x <= kSpiderClearance ||
        spider.x >= level.length - kSpiderClearance) {
      problems.add('spider at ${spider.x} is inside a clearance');
    }
    if (spider.period <= kSpiderCycleTime + kMinSpiderClearTime) {
      problems.add('spider period ${spider.period} leaves less than '
          '${kMinSpiderClearTime}s with the ceiling open');
    }
    if (spider.phase < 0 || spider.phase >= spider.period) {
      problems.add('spider phase ${spider.phase} is outside 0 to '
          '${spider.period}');
    }
  }

  final xs = level.obstacleXs;
  for (var i = 1; i < xs.length; i++) {
    final gap = xs[i] - xs[i - 1];
    if (gap < kMinObstacleGap) {
      problems.add('obstacles at ${xs[i - 1]} and ${xs[i]} are only '
          '${gap.toStringAsFixed(0)} apart, under the $kMinObstacleGap '
          'minimum');
    }
  }

  problems.addAll(pacingProblems(level));

  var previous = 0.0;
  for (final checkpoint in level.checkpoints) {
    if (checkpoint <= previous || checkpoint >= level.length) {
      problems.add('checkpoint $checkpoint is out of order or out of bounds');
    }
    previous = checkpoint;
  }

  RunPlan? plan;
  if (solve && problems.isEmpty) {
    plan = solveLevel(level);
    if (plan == null) {
      problems.add('no input sequence finishes this level');
    } else {
      final end = runPlan(level, plan);
      if (end.status != RunStatus.won) {
        problems.add('the solver plan does not replay to a win, it '
            '${end.status.name}');
      }
    }
  }

  return LevelValidation(level, problems, plan);
}
