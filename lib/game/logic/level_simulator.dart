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
        _stones = [...level.stones]..sort((a, b) => a.x.compareTo(b.x)) {
    _bladeX = [for (final e in _blades) e.x];
    _stoneX = [for (final e in _stones) e.x];
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
  }

  final LevelModel level;
  final List<Bolted> _bolted;
  final List<Hopper> _hoppers;
  final List<Blade> _blades;
  final List<Stone> _stones;
  late final List<double> _boltedX;
  late final List<double> _hopperX;
  late final List<double> _bladeX;
  late final List<double> _stoneX;

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

  static const double _reach = kBoltedWidth;
  static const double _hopperInnerSize = kHopperSize - kHitboxShrink * 2;
  static const double _bladeInnerHeight = kBladeHeight - kHitboxShrink * 2;
  static const double _stoneInnerSize = kStoneSize - kHitboxShrink * 2;

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

    if (_hoppers.isEmpty && _blades.isEmpty && _stones.isEmpty) return false;
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
        state = RunState();

  final LevelIndex index;
  RunState state;

  LevelModel get level => index.level;

  void restart({int lives = kStartingLives}) {
    state = RunState(lives: lives);
  }

  void input(RunInput input) => applyInput(state, input);

  void step([double dt = kFixedStep]) => advance(index, state, dt);

  /// True when the death being handled is the last life.
  bool get outOfLives => state.lives <= 1;

  /// Takes a life and puts the character back at the last checkpoint. When the
  /// last life goes, the level restarts from the beginning with three again.
  void respawn() {
    final remaining = state.lives - 1;
    final elapsed = state.elapsed;
    if (remaining <= 0) {
      state = RunState(elapsed: elapsed);
    } else {
      final checkpoint = level.checkpointBehind(state.x);
      state = RunState(
        x: checkpoint,
        lives: remaining,
        elapsed: elapsed,
        checkpointX: checkpoint,
      );
    }
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
  String toString() => ok
      ? 'Level ${level.id}: ok (${plan!.actions} inputs)'
      : 'Level ${level.id}: ${problems.join('; ')}';
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

LevelValidation validateLevel(LevelModel level) {
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

  problems.addAll(pacingProblems(level));

  var previous = 0.0;
  for (final checkpoint in level.checkpoints) {
    if (checkpoint <= previous || checkpoint >= level.length) {
      problems.add('checkpoint $checkpoint is out of order or out of bounds');
    }
    previous = checkpoint;
  }

  RunPlan? plan;
  if (problems.isEmpty) {
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
