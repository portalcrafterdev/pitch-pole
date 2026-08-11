import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/components/bat_enemy.dart';
import 'package:pitchpole/game/components/blade_obstacle.dart';
import 'package:pitchpole/game/components/bolted_enemy.dart';
import 'package:pitchpole/game/components/door.dart';
import 'package:pitchpole/game/components/fire_obstacle.dart';
import 'package:pitchpole/game/components/hopper_enemy.dart';
import 'package:pitchpole/game/components/player.dart';
import 'package:pitchpole/game/components/spider_enemy.dart';
import 'package:pitchpole/game/components/stone_obstacle.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/physics.dart';
import 'package:pitchpole/game/logic/run_state.dart';
import 'package:pitchpole/game/pitchpole_game.dart';

const LevelModel _level = LevelModel(
  id: 1,
  length: 6000,
  runSpeed: kRunSpeed,
  hopPeriod: 2.0,
  bolted: [Bolted(x: 2600, surface: Surface.floor)],
  // Parked well past the bolted enemy, so the early tests run a clear track.
  hoppers: [Hopper(x: 5200, surface: Surface.floor, phase: 0.4)],
  blades: [Blade(x: 5500, period: 2.0)],
  stones: [Stone(x: 5800, surface: Surface.ceiling, period: 2.4)],
  fires: [Fire(x: 5650, surface: Surface.floor, period: 2.6)],
  bats: [Bat(x: 5350)],
  spiders: [Spider(x: 5900)],
  checkpoints: [2000, 4000],
);

/// An empty track, for the tests that only care about reaching the door.
const LevelModel _clearTrack = LevelModel(
  id: 2,
  length: 1200,
  runSpeed: kRunSpeed,
  hopPeriod: 2.0,
);

/// Advances the game by [seconds] in 60 hertz frames.
Future<void> play(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16, microseconds: 667));
  }
}

void main() {
  Future<PitchpoleGame> mount(
    WidgetTester tester, {
    LevelModel level = _level,
    void Function(int stars, double seconds)? onWin,
    void Function()? onRunOut,
    Future<void> Function()? onLifeLost,
  }) async {
    final game = PitchpoleGame(
      level: level,
      hapticsEnabled: false,
      soundEnabled: false,
      musicEnabled: false,
      onWin: onWin ?? (_, _) {},
      onRunOut: onRunOut ?? () {},
      onLifeLost: onLifeLost,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await tester.pump();
    return game;
  }

  testWidgets('the scene is built from the level data', (tester) async {
    final game = await mount(tester);

    expect(game.world.children.whereType<PlayerComponent>().length, 1,
        reason: 'one character, the player never controls two things');
    expect(game.world.children.whereType<BoltedEnemy>().length, 1);
    expect(game.world.children.whereType<HopperEnemy>().length, 1);
    expect(game.world.children.whereType<BladeObstacle>().length, 1);
    expect(game.world.children.whereType<StoneObstacle>().length, 1);
    expect(game.world.children.whereType<FireObstacle>().length, 1);
    expect(game.world.children.whereType<BatEnemy>().length, 1);
    expect(game.world.children.whereType<SpiderEnemy>().length, 1);
    expect(game.world.children.whereType<DoorComponent>().length, 1);
  });

  testWidgets('the animals move on their own, off the level clock',
      (tester) async {
    final game = await mount(tester);
    final bat = game.world.children.whereType<BatEnemy>().first;
    final spider = game.world.children.whereType<SpiderEnemy>().first;

    final batYs = <double>[];
    final spiderYs = <double>[];
    for (var i = 0; i < 10; i++) {
      await play(tester, 0.2);
      batYs.add(bat.position.y);
      spiderYs.add(spider.position.y);
    }

    expect(batYs.toSet().length, greaterThan(1),
        reason: 'the bat should be drifting');
    expect(spiderYs.toSet().length, greaterThan(1),
        reason: 'the spider should be dropping and climbing');
  });

  testWidgets('a bat stays in the middle and never reaches a surface',
      (tester) async {
    final game = await mount(tester);
    final bat = game.world.children.whereType<BatEnemy>().first;

    for (var i = 0; i < 20; i++) {
      await play(tester, 0.1);
      expect(bat.position.y, greaterThan(kCeilingSurfaceY),
          reason: 'a bat belongs to no surface');
      expect(bat.position.y + kBatHeight, lessThan(kFloorSurfaceY));
    }
  });

  testWidgets('the moving obstacles move on their own', (tester) async {
    final game = await mount(tester);
    final blade = game.world.children.whereType<BladeObstacle>().first;
    final stone = game.world.children.whereType<StoneObstacle>().first;

    final bladeYs = <double>[];
    final stoneYs = <double>[];
    for (var i = 0; i < 10; i++) {
      await play(tester, 0.2);
      bladeYs.add(blade.position.y);
      stoneYs.add(stone.position.y);
    }

    expect(bladeYs.toSet().length, greaterThan(1),
        reason: 'the blade should be sweeping');
    expect(stoneYs.toSet().length, greaterThan(1),
        reason: 'the stone should be slamming');
  });

  /// Renders [component] on its own and counts the pixels it actually put
  /// down. Proves the drawing happens, not just that the numbers are right.
  ///
  /// Rasterising has to happen outside the test's fake async, or `toImage`
  /// never completes.
  Future<int> paintedPixels(
    WidgetTester tester,
    PositionComponent component,
  ) async {
    var painted = 0;
    await tester.runAsync(() async {
      final recorder = PictureRecorder();
      component.render(Canvas(recorder));
      final picture = recorder.endRecording();

      final image = await picture.toImage(
        component.size.x.ceil(),
        component.size.y.ceil(),
      );
      final data = await image.toByteData();
      picture.dispose();
      image.dispose();
      if (data == null) return;

      for (var i = 3; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 8) painted++;
      }
    });
    return painted;
  }

  testWidgets('a lit vent paints far more than a dark one', (tester) async {
    const vent = Fire(x: 100, surface: Surface.floor, period: 2.6);

    // Cycle 0: dark, so only the grate shows.
    final component = FireObstacle(vent)..syncTo(0);
    final dark = await paintedPixels(tester, component);

    // Straight to full height.
    component.syncTo(kFireWarnTime + kFireRiseTime);
    final lit = await paintedPixels(tester, component);

    expect(dark, greaterThan(0), reason: 'the grate has to be visible');
    expect(lit, greaterThan(dark * 3),
        reason: 'a flame at full reach should dwarf the grate');
  });

  testWidgets('a ceiling vent paints just as much as a floor one',
      (tester) async {
    const floor = Fire(x: 100, surface: Surface.floor, period: 2.6);
    const ceiling = Fire(x: 100, surface: Surface.ceiling, period: 2.6);
    const alight = kFireWarnTime + kFireRiseTime;

    final down = await paintedPixels(
      tester,
      FireObstacle(floor)..syncTo(alight),
    );
    final up = await paintedPixels(
      tester,
      FireObstacle(ceiling)..syncTo(alight),
    );

    expect(up, greaterThan(0));
    // Same flame, mirrored. Anything else means one direction is broken.
    expect((up - down).abs(), lessThan(down * 0.2));
  });

  testWidgets('a fire lights and goes out on its own', (tester) async {
    final game = await mount(tester);
    final fire = game.world.children.whereType<FireObstacle>().first;
    final level = game.level;
    final vent = level.fires.first;

    // Sampled from the level time the game feeds it, so the flame is where
    // the validator says it is rather than wherever a wall clock landed.
    final heights = <double>[];
    for (var i = 0; i < 14; i++) {
      final levelTime = i * 0.2;
      heights.add(vent.heightAt(levelTime));
    }

    expect(heights.any((h) => h == 0), isTrue, reason: 'it should go dark');
    expect(heights.any((h) => h > kFireReach * 0.9), isTrue,
        reason: 'and reach full height');
    expect(fire.onCeiling, isFalse);
  });

  testWidgets('the character runs forward with no input at all',
      (tester) async {
    final game = await mount(tester);

    await play(tester, 2);

    expect(game.sim.state.x, closeTo(kRunSpeed * 2, kRunSpeed * 0.1));
    expect(game.sim.state.status, RunStatus.running);
  });

  testWidgets('the camera keeps the character locked at screen x 90',
      (tester) async {
    final game = await mount(tester);
    final player = game.world.children.whereType<PlayerComponent>().first;

    for (final seconds in [0.5, 1.5, 3.0]) {
      await play(tester, seconds);
      final viewLeft = game.camera.viewfinder.position.x - kCanvasWidth / 2;
      expect(player.position.x - viewLeft, closeTo(kPlayerScreenX, 0.001));
      expect(game.camera.viewfinder.position.y, kCanvasHeight / 2,
          reason: 'the camera never moves vertically');
    }
  });

  testWidgets('flip up sends the character to the ceiling', (tester) async {
    final game = await mount(tester);
    final player = game.world.children.whereType<PlayerComponent>().first;

    game.press(RunInput.flipUp);
    await play(tester, 1);

    expect(game.sim.state.gravityUp, isTrue);
    expect(player.position.y, closeTo(restingY(gravityUp: true), 0.5));

    game.press(RunInput.flipDown);
    await play(tester, 1);

    expect(game.sim.state.gravityUp, isFalse);
    expect(player.position.y, closeTo(restingY(gravityUp: false), 0.5));
  });

  testWidgets('pressing the surface it is already on does nothing',
      (tester) async {
    final game = await mount(tester);
    await play(tester, 0.5);

    game.press(RunInput.flipDown);
    await play(tester, 0.2);

    expect(game.sim.state.gravityUp, isFalse);
    expect(game.sim.state.grounded, isTrue);
  });

  testWidgets('a hopper moves on its own, without the player touching it',
      (tester) async {
    final game = await mount(tester);
    final hopper = game.world.children.whereType<HopperEnemy>().first;

    final samples = <double>[];
    for (var i = 0; i < 8; i++) {
      await play(tester, 0.15);
      samples.add(hopper.position.y);
    }

    expect(samples.toSet().length, greaterThan(1),
        reason: 'the hopper should be bouncing');
  });

  testWidgets('hitting a bolted enemy pauses, then respawns at the checkpoint',
      (tester) async {
    final game = await mount(tester);

    // The enemy sits at 2600, just past the 2000 checkpoint.
    await play(tester, 13.2);
    expect(game.sim.state.status, RunStatus.dead);
    expect(game.sim.state.lives, 3, reason: 'the life goes on respawn');

    await play(tester, PitchpoleGame.kDeathPause + 0.2);

    expect(game.sim.state.status, RunStatus.running);
    expect(game.sim.state.x, greaterThanOrEqualTo(2000),
        reason: 'it restarts from the 2000 checkpoint, not the level start');
    expect(game.sim.state.x, lessThan(2400),
        reason: 'and only the pumped remainder of a second past it');
    expect(game.sim.state.lives, 2);
  });

  testWidgets('a life lost waits for the break, then respawns', (tester) async {
    // Stands in for the ad: the respawn must wait for it and then happen.
    final gate = Completer<void>();
    final game = await mount(tester, onLifeLost: () => gate.future);

    await play(tester, 13.2);
    expect(game.sim.state.status, RunStatus.dead);

    await play(tester, PitchpoleGame.kDeathPause + 0.5);
    expect(game.sim.state.status, RunStatus.dead,
        reason: 'the run holds still behind the ad rather than ticking on');
    expect(game.sim.state.lives, 3, reason: 'the life goes on the respawn');

    gate.complete();
    await play(tester, 0.2);

    expect(game.sim.state.status, RunStatus.running);
    expect(game.sim.state.lives, 2);
    expect(game.sim.state.x, greaterThanOrEqualTo(2000),
        reason: 'and it still comes back at the checkpoint');
  });

  testWidgets('a break that resolves at once respawns as fast as ever',
      (tester) async {
    // The case that matters most: no ad loaded. This must be indistinguishable
    // from the game before ads existed, or every death gains a stutter.
    final game = await mount(tester, onLifeLost: () async {});

    await play(tester, 13.2);
    await play(tester, PitchpoleGame.kDeathPause + 0.2);

    expect(game.sim.state.status, RunStatus.running);
    expect(game.sim.state.lives, 2);
  });

  testWidgets('sound and music can be switched during a run', (tester) async {
    final game = await mount(tester);

    // Nothing here can be heard under `flutter test`; what is being checked is
    // that flipping them mid level is accepted and does not throw. The bug
    // this guards is the settings being read once at construction, which left
    // the pause menu switches doing nothing until the next level.
    game.applyAudioSettings(sound: false, music: false);
    await play(tester, 0.5);
    game.applyAudioSettings(sound: true, music: true);
    await play(tester, 0.5);

    expect(tester.takeException(), isNull);
    expect(game.sim.state.isRunning, isTrue);
  });

  testWidgets('the last life holds the run instead of resetting it',
      (tester) async {
    var ranOut = 0;
    final game = await mount(tester, onRunOut: () => ranOut++);

    // Die on the enemy at 2600 three times over. The third is the last life.
    for (var life = 0; life < 3; life++) {
      while (game.sim.state.status != RunStatus.dead) {
        await play(tester, 0.5);
      }
      await play(tester, PitchpoleGame.kDeathPause + 0.2);
    }

    expect(ranOut, 1);
    expect(game.sim.state.status, RunStatus.dead,
        reason: 'the run is over but not thrown away');
    expect(game.sim.state.x, greaterThan(2000),
        reason: 'the level used to be reset to the start here, which left the '
            'extra life nothing to give back');

    // What the ad buys: the same run, one checkpoint back.
    game.revive();

    expect(game.sim.state.status, RunStatus.running);
    expect(game.sim.state.lives, 1);
    expect(game.sim.state.x, 2000,
        reason: 'picked up at the checkpoint, not the start of the level');

    await play(tester, 1);
    expect(game.sim.state.x, greaterThan(2000),
        reason: 'and it is actually running again');
  });

  testWidgets('flipping over the enemy survives it', (tester) async {
    final game = await mount(tester);

    await play(tester, 11);
    game.press(RunInput.flipUp);
    await play(tester, 3);

    expect(game.sim.state.status, RunStatus.running);
    expect(game.sim.state.x, greaterThan(2700));
  });

  testWidgets('input is refused while the death pause is running',
      (tester) async {
    final game = await mount(tester);
    await play(tester, 13.2);

    expect(game.sim.state.status, RunStatus.dead);
    expect(game.acceptsInput, isFalse);
  });

  testWidgets('clearing the level plays the finish burst before the overlay',
      (tester) async {
    var stars = 0;
    var reported = false;
    final game = await mount(
      tester,
      level: _clearTrack,
      onWin: (s, _) {
        stars = s;
        reported = true;
      },
    );
    final door = game.world.children.whereType<DoorComponent>().first;
    final player = game.world.children.whereType<PlayerComponent>().first;

    // The track is 1200 units at 200 a second, so the door lands at 6.
    await play(tester, 6.2);

    expect(game.sim.state.status, RunStatus.won);
    expect(door.isCelebrating, isTrue,
        reason: 'the finish line should burst the moment it is crossed');
    expect(player.isCheering, isTrue);
    expect(reported, isFalse,
        reason: 'the overlay must wait until the burst has been seen');

    await play(tester, PitchpoleGame.kWinPause + 0.2);

    expect(reported, isTrue);
    expect(stars, 3, reason: 'it finished without losing a life');
  });

  testWidgets('restarting after a win clears the burst', (tester) async {
    final game = await mount(tester, level: _clearTrack);
    final door = game.world.children.whereType<DoorComponent>().first;

    await play(tester, 6.2);
    expect(door.isCelebrating, isTrue);

    game.restart();
    await tester.pump();

    expect(door.isCelebrating, isFalse);
    expect(game.sim.state.x, 0);
  });

  testWidgets('restart puts everything back to the start', (tester) async {
    final game = await mount(tester);
    await play(tester, 5);
    expect(game.sim.state.x, greaterThan(500));

    game.restart();
    await tester.pump();

    expect(game.sim.state.x, 0);
    expect(game.sim.state.lives, kStartingLives);
    expect(game.sim.state.elapsed, 0);
    expect(game.sim.state.gravityUp, isFalse);
  });
}
