import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/ads.dart';
import 'package:pitchpole/data/level_repository.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';
import 'package:pitchpole/game/pitchpole_game.dart';
import 'package:pitchpole/ui/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// There is no ads plugin under `flutter test`, so every call into it fails.
/// That is the case worth testing: it is the same one a player gets with no
/// connection, with ads not yet configured, or with nothing filled for them.
/// The rule being checked throughout is that none of it can stop a level.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
  });

  group('an ad never makes the player wait', () {
    test('with nothing loaded it returns at once and shows nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      // If this ever starts waiting on a network the whole feature becomes a
      // spinner before every level, so the assertion is on the clock as well
      // as the result.
      final watch = Stopwatch()..start();
      final shown = await adsController.showAtBreak();
      watch.stop();

      expect(shown, isFalse);
      expect(adsController.hasAdReady, isFalse);
      expect(watch.elapsedMilliseconds, lessThan(500));

      debugDefaultTargetPlatformOverride = null;
    });

    test('a platform with no ads at all says so rather than throwing',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(adsController.isSupported, isFalse);
      expect(await adsController.showAtBreak(), isFalse);
      await adsController.initialize();

      debugDefaultTargetPlatformOverride = null;
    });

    test('two breaks at once cannot stack one ad on another', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      adsController.debugShowing = true;

      expect(await adsController.showAtBreak(), isFalse,
          reason: 'a level ending while an ad is up must not open a second');

      adsController.debugShowing = false;
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('the extra life', () {
    test('picks the run up at the checkpoint instead of the start', () async {
      final levels = await levelRepository.loadAll();
      // A level long enough to have checkpoints to come back to.
      final level = levels.firstWhere((l) => l.checkpoints.isNotEmpty);

      final sim = LevelSimulator(level);
      // Spend two lives, so the next death is the last one.
      for (var life = 0; life < 2; life++) {
        while (sim.state.isRunning) {
          sim.step();
        }
        sim.respawn();
      }
      while (sim.state.isRunning) {
        sim.step();
      }

      expect(sim.outOfLives, isTrue);
      final diedAt = sim.state.x;

      sim.revive();

      expect(sim.state.lives, 1);
      expect(sim.state.isRunning, isTrue);
      expect(sim.state.x, level.checkpointBehind(diedAt),
          reason: 'the point of paying for a life is keeping the run');
      expect(sim.state.x, sim.state.checkpointX);
    });

    test('is a life on top of the three, not one of them', () {
      final sim = LevelSimulator(
        const LevelModel(id: 1, length: 1000, runSpeed: 200, hopPeriod: 2),
      );
      while (sim.state.isRunning && sim.state.x < 900) {
        sim.step();
      }

      // Nothing has died here at all, which is the case that would expose a
      // revive that quietly decremented instead of granting.
      sim.revive();
      expect(sim.state.lives, 1);
    });

    test('a dismissed ad grants nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      // No ad loaded, so nothing is earned. The caller must not revive.
      expect(await adsController.showForExtraLife(), isFalse);
      expect(adsController.canOfferExtraLife, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('a level still starts when there is no ad to show',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final levels = (await tester.runAsync(levelRepository.loadAll))!;

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levels: levels, index: 0)),
      );
      // Not pumpAndSettle: a running game never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);

      // The run is held paused until the break ad is dealt with. This is the
      // regression that matters: if that ever fails instead of returning,
      // every level in the game freezes before it starts.
      final widget = tester.widget<GameWidget<PitchpoleGame>>(
        find.byType(GameWidget<PitchpoleGame>),
      );
      expect(widget.game!.paused, isFalse,
          reason: 'the level must start even though no ad was available');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
