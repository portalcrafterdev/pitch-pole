import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/components/blade_obstacle.dart';
import 'package:pitchpole/game/components/bolted_enemy.dart';
import 'package:pitchpole/game/components/door.dart';
import 'package:pitchpole/game/components/fire_obstacle.dart';
import 'package:pitchpole/game/components/hopper_enemy.dart';
import 'package:pitchpole/game/components/player.dart';
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
  }) async {
    final game = PitchpoleGame(
      level: level,
      hapticsEnabled: false,
      soundEnabled: false,
      musicEnabled: false,
      onWin: onWin ?? (_, _) {},
      onRunOut: onRunOut ?? () {},
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
    expect(game.world.children.whereType<DoorComponent>().length, 1);
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
