import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';
import 'package:pitchpole/game/logic/physics.dart';
import 'package:pitchpole/game/logic/run_state.dart';

LevelModel level({
  double length = 6000,
  double runSpeed = kRunSpeed,
  double hopPeriod = kHopPeriod,
  List<Bolted> bolted = const [],
  List<Hopper> hoppers = const [],
  List<Blade> blades = const [],
  List<Stone> stones = const [],
  List<Fire> fires = const [],
  List<double> checkpoints = const [2000, 4000],
}) =>
    LevelModel(
      id: 1,
      length: length,
      runSpeed: runSpeed,
      hopPeriod: hopPeriod,
      bolted: bolted,
      hoppers: hoppers,
      blades: blades,
      stones: stones,
      fires: fires,
      checkpoints: checkpoints,
    );

/// Runs [seconds] of simulation, calling [onStep] after each fixed step.
RunState run(
  LevelModel model,
  double seconds, {
  RunState? from,
  void Function(RunState state, int step)? onStep,
}) {
  final index = LevelIndex(model);
  final state = from ?? RunState();
  final steps = (seconds / kFixedStep).round();
  for (var i = 0; i < steps && state.isRunning; i++) {
    advance(index, state);
    onStep?.call(state, i);
  }
  return state;
}

void main() {
  group('the numbers the doc pins down', () {
    test('a jump peaks at about 60 units', () {
      expect(kJumpPeak, closeTo(60, 1));
    });

    test('a hop peaks at about 90 units', () {
      expect(kHopPeak, closeTo(90, 1));
    });

    test('a hop stays airborne for about 0.69 seconds', () {
      expect(kHopAirTime, closeTo(0.69, 0.01));
    });

    test('the playable band is 120 tall', () {
      expect(kBandHeight, 120);
      expect(kMaxPlayerY - kMinPlayerY, 120 - kPlayerSize);
    });

    test('a level is 30 seconds of running at its own speed', () {
      expect(level().seconds, closeTo(kLevelSeconds, 0.001));
      expect(level(length: 7200, runSpeed: 240).seconds,
          closeTo(kLevelSeconds, 0.001));
    });
  });

  group('forward motion', () {
    test('runs at exactly runSpeed and never changes', () {
      final end = run(level(), 5);
      expect(end.x, closeTo(kRunSpeed * 5, 0.5));
    });

    test('no input changes the forward speed', () {
      for (final input in RunInput.values) {
        final state = RunState();
        applyInput(state, input);
        final end = run(level(), 3, from: state);
        expect(end.x, closeTo(kRunSpeed * 3, 0.5),
            reason: '${input.name} changed the forward speed');
      }
    });

    test('reaching the length wins', () {
      final end = run(level(), kLevelSeconds + 0.1);
      expect(end.status, RunStatus.won);
      expect(end.x, closeTo(6000, 0.001));
    });
  });

  group('flip', () {
    test('up puts the character on the ceiling', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);
      expect(state.gravityUp, isTrue);
      expect(state.grounded, isFalse);

      final end = run(level(), 1, from: state);
      expect(end.y, closeTo(restingY(gravityUp: true), 0.001));
      expect(end.grounded, isTrue);
    });

    test('down puts it back on the floor', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);
      run(level(), 1, from: state);
      applyInput(state, RunInput.flipDown);

      final end = run(level(), 1, from: state);
      expect(end.y, closeTo(restingY(gravityUp: false), 0.001));
      expect(end.grounded, isTrue);
    });

    test('pressing the surface it is already on does nothing', () {
      final state = RunState();
      applyInput(state, RunInput.flipDown);

      expect(state.gravityUp, isFalse);
      expect(state.grounded, isTrue, reason: 'a toggle would have lifted it');
      expect(state.vy, 0);
    });

    test('works mid jump', () {
      final state = RunState();
      applyInput(state, RunInput.jump);
      run(level(), 0.1, from: state);
      expect(state.grounded, isFalse);

      applyInput(state, RunInput.flipUp);
      final end = run(level(), 1, from: state);

      expect(end.gravityUp, isTrue);
      expect(end.y, closeTo(restingY(gravityUp: true), 0.001));
    });

    test('the fall starts immediately, it does not hang', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);
      expect(state.vy, -kFlipImpulse);

      final after = run(level(), 0.05, from: state);
      expect(after.y, lessThan(restingY(gravityUp: false) - 1));
    });

    test('crossing the band takes well under a second', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);

      var crossed = -1;
      run(level(), 1, from: state, onStep: (s, step) {
        if (crossed < 0 && s.grounded) crossed = step;
      });

      expect(crossed, greaterThan(0));
      expect(crossed * kFixedStep, lessThan(0.4));
    });
  });

  group('jump', () {
    test('only works when grounded', () {
      final state = RunState();
      applyInput(state, RunInput.jump);
      final firstVy = state.vy;
      expect(firstVy, -kJumpVelocity);

      run(level(), 0.1, from: state);
      applyInput(state, RunInput.jump);

      expect(state.vy, isNot(-kJumpVelocity),
          reason: 'a second jump must not fire while airborne');
    });

    test('never chains into a second jump', () {
      final state = RunState();
      var peak = state.y;
      applyInput(state, RunInput.jump);
      run(level(), 0.6, from: state, onStep: (s, _) {
        applyInput(s, RunInput.jump);
        if (s.y < peak) peak = s.y;
      });

      final rise = restingY(gravityUp: false) - peak;
      expect(rise, closeTo(kJumpPeak, 3),
          reason: 'holding jump must not climb higher than one jump');
    });

    test('peaks at the documented height from the floor', () {
      final state = RunState();
      applyInput(state, RunInput.jump);
      var peak = state.y;
      run(level(), 0.5, from: state, onStep: (s, _) {
        if (s.y < peak) peak = s.y;
      });

      // The stepped simulation lands a little under the analytic 60.3, which
      // is the discretisation of a 1/120 step, not a tuning error.
      expect(restingY(gravityUp: false) - peak, closeTo(kJumpPeak, 3));
    });

    test('from the ceiling it pushes towards the floor', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);
      run(level(), 1, from: state);

      applyInput(state, RunInput.jump);
      expect(state.vy, kJumpVelocity);

      var lowest = state.y;
      run(level(), 0.5, from: state, onStep: (s, _) {
        if (s.y > lowest) lowest = s.y;
      });
      expect(lowest - restingY(gravityUp: true), closeTo(kJumpPeak, 3));
    });

    test('clears a resting hopper on either surface', () {
      for (final surface in Surface.values) {
        // A hopper that never leaves its surface: phase parked at the rest.
        final model = level(
          hopPeriod: 2,
          hoppers: [Hopper(x: 1000, surface: surface, phase: 1.0)],
        );
        final index = LevelIndex(model);
        final state = RunState();

        // Get onto the hopper's surface, then run up to it. The hopper is at
        // x = 1000, so the character arrives at t = 5s.
        if (surface == Surface.ceiling) {
          applyInput(state, RunInput.flipUp);
        }
        for (var i = 0; i < (4.7 / kFixedStep).round(); i++) {
          advance(index, state);
        }

        // Jump just before arriving, then ride it out.
        expect(state.grounded, isTrue);
        applyInput(state, RunInput.jump);
        for (var i = 0; i < (0.6 / kFixedStep).round(); i++) {
          advance(index, state);
        }

        expect(state.status, RunStatus.running,
            reason: 'a jump should clear a resting ${surface.name} hopper');
        expect(state.x, greaterThan(1000 + kHopperSize));
      }
    });
  });

  group('the band', () {
    test('the character never leaves it, whatever the input', () {
      final state = RunState();
      var lowest = state.y;
      var highest = state.y;

      run(level(), 12, from: state, onStep: (s, step) {
        applyInput(s, RunInput.values[step % RunInput.values.length]);
        if (s.y < lowest) lowest = s.y;
        if (s.y > highest) highest = s.y;
      });

      expect(lowest, greaterThanOrEqualTo(kMinPlayerY - 0.001));
      expect(highest, lessThanOrEqualTo(kMaxPlayerY + 0.001));
    });

    test('landing on either surface zeroes the fall', () {
      final state = RunState();
      applyInput(state, RunInput.flipUp);
      final end = run(level(), 1, from: state);
      expect(end.vy, 0);
      expect(end.y, kMinPlayerY);
    });
  });

  group('hoppers', () {
    test('rest, launch, and come back on their own period', () {
      const hopper = Hopper(x: 100, surface: Surface.floor);

      expect(hopper.heightAt(0, 2), 0);
      expect(hopper.heightAt(kHopAirTime / 2, 2), closeTo(kHopPeak, 0.5));
      expect(hopper.heightAt(kHopAirTime, 2), 0);
      expect(hopper.heightAt(1.5, 2), 0, reason: 'resting between hops');
      expect(hopper.heightAt(2 + kHopAirTime / 2, 2), closeTo(kHopPeak, 0.5),
          reason: 'the cycle repeats');
    });

    test('phase offsets keep a row of them out of sync', () {
      const a = Hopper(x: 100, surface: Surface.floor);
      const b = Hopper(x: 200, surface: Surface.floor, phase: 0.9);

      expect(a.heightAt(0.2, 2), isNot(closeTo(b.heightAt(0.2, 2), 1)));
    });

    test('a hopper at full stretch reaches almost across the band', () {
      // 90 units of hop plus a 26 unit body is 116 of the 120 unit band, so a
      // hopper caught mid hop threatens the opposite surface too. That is the
      // "arriving mid hop" danger, and it is why phases have to be authored.
      expect(kHopPeak + kHopperSize, greaterThan(kBandHeight - kPlayerSize));

      final model = level(
        hopPeriod: 2,
        hoppers: const [Hopper(x: 400, surface: Surface.ceiling)],
      );
      final index = LevelIndex(model);

      // Standing on the floor, directly under a ceiling hopper at its peak.
      final atPeak = RunState(x: 400 - kPlayerSize / 2);
      expect(index.hits(atPeak), isFalse, reason: 'it is resting at t=0');

      final hopper = model.hoppers.first;
      expect(hopper.heightAt(kHopAirTime / 2, 2), closeTo(kHopPeak, 0.5));
    });

    test('a hopper cycle is independent of the player gravity', () {
      const hopper = Hopper(x: 100, surface: Surface.floor, phase: 0.3);
      final atTime = hopper.heightAt(4.2, 1.75);

      expect(hopper.heightAt(4.2, 1.75), atTime);
    });
  });

  group('blades', () {
    test('sweep the whole band, ceiling to floor and back', () {
      const period = 2.0;

      expect(bladeSweepAt(0, period), closeTo(0, 0.001));
      expect(bladeSweepAt(period / 2, period), closeTo(1, 0.001));
      expect(bladeSweepAt(period, period), closeTo(0, 0.001),
          reason: 'the sweep repeats');

      expect(bladeTopAt(0, period), kCeilingSurfaceY);
      expect(bladeTopAt(period / 2, period),
          closeTo(kFloorSurfaceY - kBladeHeight, 0.001));
    });

    test('there is always a surface a blade is not at', () {
      const period = 2.0;
      for (var t = 0.0; t < period; t += period / 24) {
        final top = bladeTopAt(t, period);
        final clearsFloor = top + kBladeHeight < kMaxPlayerY + kHitboxShrink;
        final clearsCeiling = top > kMinPlayerY + kPlayerSize - kHitboxShrink;
        expect(clearsFloor || clearsCeiling, isTrue,
            reason: 'a blade at $top blocks both surfaces at once');
      }
    });

    test('kill on contact and miss when they are away', () {
      final model = level(blades: const [Blade(x: 400, period: 2.0)]);
      final index = LevelIndex(model);

      // At level time 0 the blade is parked at the ceiling, so the floor is
      // clear. x = 400 is reached at t = 2s, a whole sweep later.
      final onFloor = RunState(x: 400 - kPlayerSize / 2);
      expect(index.hits(onFloor), isFalse);

      final onCeiling = RunState(
        x: 400 - kPlayerSize / 2,
        y: restingY(gravityUp: true),
        gravityUp: true,
      );
      expect(index.hits(onCeiling), isTrue,
          reason: 'the blade is parked exactly there');
    });
  });

  group('stones', () {
    test('rest, slam across the band, and get winched back', () {
      const period = 2.4;

      expect(stoneOffsetAt(0, period), 0);
      expect(stoneOffsetAt(kStoneFallTime, period), closeTo(kStoneReach, 0.001));
      expect(stoneOffsetAt(kStoneFallTime + kStoneHoldTime / 2, period),
          closeTo(kStoneReach, 0.001));
      expect(stoneOffsetAt(kStoneCycleTime, period), closeTo(0, 0.001));
      expect(stoneOffsetAt(period - 0.01, period), 0, reason: 'resting again');
    });

    test('fall faster than they rise, so the tell is the slow return', () {
      const period = 2.4;
      final quarterDown = stoneOffsetAt(kStoneFallTime / 2, period);
      final quarterUp = stoneOffsetAt(
        kStoneFallTime + kStoneHoldTime + kStoneRiseTime / 2,
        period,
      );

      expect(quarterDown, lessThan(quarterUp),
          reason: 'the drop accelerates, the winch is steady');
    });

    test('a fully extended stone reaches the far surface', () {
      expect(kStoneReach + kStoneSize, kBandHeight);

      final model = level(
        stones: const [Stone(x: 400, surface: Surface.ceiling, period: 2.4)],
      );
      final index = LevelIndex(model);

      // x = 400 is reached at t = 2s, which is inside the resting stretch.
      expect(index.hits(RunState(x: 400 - kPlayerSize / 2)), isFalse);

      // Mid slam it owns the whole column.
      final slam = stoneBox(400, onCeiling: true, offset: kStoneReach);
      expect(slam.bottom, kFloorSurfaceY);
    });
  });

  group('fires', () {
    const period = 2.6;

    test('a vent is dark, warns, burns, and goes out', () {
      expect(fireHeightAt(0, period), 0, reason: 'dark');
      expect(fireHeightAt(kFireWarnTime - 0.01, period), 0,
          reason: 'still dark through the whole warning');
      expect(fireWarningAt(kFireWarnTime - 0.01, period), greaterThan(0.9),
          reason: 'but glowing, which is the tell');

      expect(fireHeightAt(kFireWarnTime + kFireRiseTime, period),
          closeTo(kFireReach, 0.001));
      expect(fireHeightAt(kFireCycleTime, period), closeTo(0, 0.001));
      expect(fireHeightAt(period - 0.01, period), 0, reason: 'dark again');
    });

    test('the warning glow is over before anything comes out', () {
      expect(fireWarningAt(kFireWarnTime, period), 0);
      expect(fireHeightAt(kFireWarnTime + 0.01, period), greaterThan(0));
    });

    test('a lit fire cannot be jumped, but the far surface is clear', () {
      final flame = fireBox(400, onCeiling: false, height: kFireReach);

      // At the peak of a jump the character is still inside the flame.
      final jumping = playerBox(400 - kPlayerSize / 2, kMaxPlayerY - kJumpPeak);
      expect(jumping.deflate(kHitboxShrink).overlaps(flame.deflate(kHitboxShrink)),
          isTrue,
          reason: 'a fire has to be flipped away from, not hopped');

      // On the ceiling it is nowhere near.
      final flipped = playerBox(400 - kPlayerSize / 2, kMinPlayerY);
      expect(flipped.deflate(kHitboxShrink).overlaps(flame.deflate(kHitboxShrink)),
          isFalse,
          reason: 'the other surface has to actually be safe');
    });

    test('running past a dark vent is free', () {
      // x = 400 is reached at t = 2s. With this phase the vent is dark then.
      final model = level(
        fires: const [
          Fire(x: 400, surface: Surface.floor, period: period, phase: 0.6),
        ],
      );
      final index = LevelIndex(model);

      expect(fireHeightAt(2.0 + 0.6, period), 0);
      expect(index.hits(RunState(x: 400 - kPlayerSize / 2)), isFalse);
    });

    test('running into a lit vent kills', () {
      final model = level(
        fires: const [
          Fire(x: 400, surface: Surface.floor, period: period, phase: 0.0),
        ],
      );
      final index = LevelIndex(model);

      // t = 2s into a cycle that warns for 0.45 then burns: fully alight.
      expect(fireHeightAt(2.0, period), 0,
          reason: '2.0 is past the burn, so pick a moment inside it');

      final lit = level(
        fires: [
          Fire(
            x: 400,
            surface: Surface.floor,
            period: period,
            // Lands the hold phase exactly on t = 2s.
            phase: period - 2.0 + kFireWarnTime + kFireRiseTime + 0.1,
          ),
        ],
      );
      expect(LevelIndex(lit).hits(RunState(x: 400 - kPlayerSize / 2)), isTrue);
      expect(index.hits(RunState(x: 400 - kPlayerSize / 2)), isFalse);
    });
  });

  group('hit boxes', () {
    test('come in 3 units on every side', () {
      final drawn = playerBox(100, 148);
      final hit = drawn.deflate(kHitboxShrink);

      expect(hit.left, drawn.left + 3);
      expect(hit.right, drawn.right - 3);
      expect(hit.width, kPlayerSize - 6);
    });

    test('grazing a bolted enemy by 2 units does not kill', () {
      final model = level(
        bolted: const [Bolted(x: 1000, surface: Surface.floor)],
      );
      final index = LevelIndex(model);

      // Sitting exactly where the drawn sprites touch but the hit boxes do not.
      final state = RunState(x: 1000 - kBoltedWidth / 2 - kPlayerSize + 5);
      expect(index.hits(state), isFalse);

      final overlapping = RunState(x: 1000 - kBoltedWidth / 2 - kPlayerSize + 8);
      expect(index.hits(overlapping), isTrue);
    });

    test('a bolted enemy on the other surface is harmless', () {
      final model = level(
        bolted: const [Bolted(x: 1000, surface: Surface.ceiling)],
      );
      final index = LevelIndex(model);
      final state = RunState(x: 1000);

      expect(index.hits(state), isFalse);
    });
  });

  group('determinism', () {
    test('the same inputs produce the same run, every time', () {
      final model = level(
        bolted: const [Bolted(x: 1400, surface: Surface.floor)],
        hoppers: const [Hopper(x: 2600, surface: Surface.floor, phase: 0.4)],
      );

      RunState play() {
        final index = LevelIndex(model);
        final state = RunState();
        for (var i = 0; i < 1200; i++) {
          if (i == 300) applyInput(state, RunInput.flipUp);
          if (i == 700) applyInput(state, RunInput.flipDown);
          if (i == 900) applyInput(state, RunInput.jump);
          advance(index, state);
        }
        return state;
      }

      final a = play();
      final b = play();

      expect(a.x, b.x);
      expect(a.y, b.y);
      expect(a.vy, b.vy);
      expect(a.status, b.status);
    });

    test('the frame rate cannot change the outcome', () {
      // The game feeds whole fixed steps out of an accumulator, so a 60 hertz
      // frame is two steps and a 120 hertz frame is one. Both must agree.
      final model = level(
        bolted: const [Bolted(x: 1400, surface: Surface.ceiling)],
      );

      RunState playAt(int stepsPerFrame) {
        final index = LevelIndex(model);
        final state = RunState();
        var stepped = 0;
        while (stepped < 1800) {
          if (stepped == 240) applyInput(state, RunInput.jump);
          for (var i = 0; i < stepsPerFrame; i++) {
            advance(index, state);
            stepped++;
          }
        }
        return state;
      }

      final fast = playAt(1);
      final slow = playAt(2);

      expect(fast.x, closeTo(slow.x, 0.0001));
      expect(fast.y, closeTo(slow.y, 0.0001));
      expect(fast.status, slow.status);
    });
  });

  group('lives and checkpoints', () {
    test('death sends the character back to the last checkpoint', () {
      final model = level(
        bolted: const [Bolted(x: 2600, surface: Surface.floor)],
      );
      final sim = LevelSimulator(model);

      while (sim.state.isRunning) {
        sim.step();
      }
      expect(sim.state.status, RunStatus.dead);
      expect(sim.state.x, greaterThan(2000));

      sim.respawn();
      expect(sim.state.x, 2000);
      expect(sim.state.lives, 2);
      expect(sim.state.gravityUp, isFalse);
      expect(sim.state.status, RunStatus.running);
    });

    test('dying before the first checkpoint restarts at zero', () {
      final model = level(
        bolted: const [Bolted(x: 1000, surface: Surface.floor)],
      );
      final sim = LevelSimulator(model);
      while (sim.state.isRunning) {
        sim.step();
      }

      sim.respawn();
      expect(sim.state.x, 0);
    });

    test('the last life restarts the level with three again', () {
      final model = level(
        bolted: const [Bolted(x: 2600, surface: Surface.floor)],
      );
      final sim = LevelSimulator(model);

      for (var life = 0; life < 2; life++) {
        while (sim.state.isRunning) {
          sim.step();
        }
        sim.respawn();
      }
      expect(sim.state.lives, 1);

      while (sim.state.isRunning) {
        sim.step();
      }
      expect(sim.outOfLives, isTrue);
      sim.respawn();

      expect(sim.state.lives, kStartingLives);
      expect(sim.state.x, 0);
    });

    test('the clock keeps running across deaths', () {
      final model = level(
        bolted: const [Bolted(x: 1000, surface: Surface.floor)],
      );
      final sim = LevelSimulator(model);
      while (sim.state.isRunning) {
        sim.step();
      }
      final atDeath = sim.state.elapsed;
      sim.respawn();

      expect(sim.state.elapsed, atDeath);
      expect(atDeath, greaterThan(4));
    });

    test('respawning puts the hoppers back where they were', () {
      final model = level(
        hoppers: const [Hopper(x: 2400, surface: Surface.floor, phase: 0.5)],
      );
      final hopper = model.hoppers.first;

      // Hopper height depends only on how far the character has run, so the
      // same spot always shows the same hop.
      final first = hopper.heightAt(2400 / model.runSpeed, model.hopPeriod);
      final second = hopper.heightAt(2400 / model.runSpeed, model.hopPeriod);

      expect(first, second);
    });
  });

  test('physics.dart imports no Flame, Flutter or dart:ui', () {
    for (final path in const [
      'lib/game/logic/physics.dart',
      'lib/game/logic/run_state.dart',
      'lib/game/logic/level_model.dart',
      'lib/game/logic/level_simulator.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final imports =
          RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true)
              .allMatches(source)
              .map((m) => m.group(1)!);

      for (final import in imports) {
        expect(
          import.startsWith('package:flame') ||
              import.startsWith('package:flutter') ||
              import == 'dart:ui',
          isFalse,
          reason: '$path must stay pure Dart, but imports $import',
        );
      }
    }
  });
}
