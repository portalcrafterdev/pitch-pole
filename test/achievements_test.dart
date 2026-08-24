import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/achievement_rules.dart';
import 'package:pitchpole/data/achievements.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _metadataCsv = 'store/achievements/AchievementsMetadata.csv';

/// A finished level, with the boring fields filled in.
RunOutcome outcome({
  int levelId = 1,
  int stars = 3,
  int coins = 0,
  int coinsOnLevel = 33,
  double runSpeed = 200,
  int jumps = 5,
  int flips = 5,
  int deathsOnLevel = 0,
  int levelsThisSession = 1,
}) =>
    RunOutcome(
      levelId: levelId,
      stars: stars,
      coins: coins,
      coinsOnLevel: coinsOnLevel,
      runSpeed: runSpeed,
      jumps: jumps,
      flips: flips,
      deathsOnLevel: deathsOnLevel,
      levelsThisSession: levelsThisSession,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AchievementsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.resetProgress();
    controller = AchievementsController();
    await controller.load();
    controller.debugReported = [];
  });

  group('the set matches what Play was told', () {
    // The runtime knows achievements by their display name, and so does the
    // import CSV. Nothing checks the two agree, so a rename in one place is a
    // silent no-op forever: the game reports an achievement Play has never
    // heard of, and no error is raised anywhere.
    List<List<String>> metadataRows() => File(_metadataCsv)
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.split(','))
        .toList();

    test('every achievement in the game is one Play knows about', () {
      final known = {for (final row in metadataRows()) row[0]};

      for (final spec in Ach.all) {
        expect(known, contains(spec.name),
            reason: '${spec.name} is not in $_metadataCsv');
      }
      expect(Ach.all.length, known.length,
          reason: 'the CSV and the game disagree about how many there are');
    });

    test('incremental achievements agree about their step counts', () {
      // Reporting 500 steps towards a target Play thinks is 100 is not an
      // error, it is just wrong: the achievement completes early or never.
      final rows = {for (final row in metadataRows()) row[0]: row};

      for (final spec in Ach.all) {
        final row = rows[spec.name]!;
        final incremental = row[2] == 'True';
        expect(spec.incremental, incremental,
            reason: '${spec.name} is incremental=$incremental in the CSV');
        if (incremental) {
          expect(spec.steps, int.parse(row[3]),
              reason: '${spec.name} has a different target in the CSV');
        }
      }
    });

    test('every achievement carries the id Play assigned it', () {
      // Without an id nothing is ever reported, and nothing complains: the
      // send is skipped silently, which is exactly right for a platform that
      // is not set up and exactly wrong for one that is.
      for (final spec in Ach.all) {
        expect(spec.androidId, isNotEmpty,
            reason: '${spec.name} has no Play Games id');
        expect(spec.androidId, startsWith('CgkI'),
            reason: '${spec.name} does not look like a Play Games id');
      }

      final ids = Ach.all.map((a) => a.androidId).toSet();
      expect(ids.length, Ach.all.length,
          reason: 'two achievements share an id, so one of them can never be '
              'earned');
    });

    test('iOS is deliberately unwired, and silent about it', () {
      // Game Center assigns its own ids and the game is not set up there yet.
      // The point of this test is that it is a decision rather than an
      // oversight: when iOS is done, these stop being empty and this test is
      // what has to be updated to say so.
      for (final spec in Ach.all) {
        expect(spec.iosId, isEmpty,
            reason: '${spec.name} has an iOS id now, so update this test');
      }
    });

    test('keys are unique, and name the icon files', () {
      expect(Ach.all.map((a) => a.key).toSet().length, Ach.all.length);
      for (final spec in Ach.all) {
        expect(File('store/achievements/${spec.key}.png').existsSync(), isTrue,
            reason: 'no icon for ${spec.key}');
      }
    });
  });

  group('earning', () {
    test('the first level earns the first achievement', () async {
      await progressStore.record(1, 3, 30);
      await awardFor(outcome(), progressStore, controller);

      expect(controller.has(Ach.firstSteps), isTrue);
    });

    test('an achievement is only ever earned once', () async {
      await progressStore.record(1, 3, 30);
      await awardFor(outcome(), progressStore, controller);
      controller.debugReported!.clear();

      await awardFor(outcome(), progressStore, controller);
      expect(controller.debugReported, isNot(contains(Ach.firstSteps.key)),
          reason: 'the platform must not be told the same thing twice');
    });

    test('clearing the five taught levels earns Taught', () async {
      for (var id = 1; id <= 4; id++) {
        await progressStore.record(id, 1, 30);
      }
      await awardFor(outcome(levelId: 4, stars: 1), progressStore, controller);
      expect(controller.has(Ach.taught), isFalse, reason: 'one still to go');

      await progressStore.record(5, 1, 30);
      await awardFor(outcome(levelId: 5, stars: 1), progressStore, controller);
      expect(controller.has(Ach.taught), isTrue);
    });

    test('Featherfoot needs a run with no jump at all', () async {
      await progressStore.record(1, 3, 30);

      await awardFor(outcome(jumps: 1), progressStore, controller);
      expect(controller.has(Ach.featherfoot), isFalse);

      await awardFor(outcome(jumps: 0), progressStore, controller);
      expect(controller.has(Ach.featherfoot), isTrue);
    });

    test('Held Ground allows three flips and not four', () async {
      await progressStore.record(1, 3, 30);

      await awardFor(outcome(flips: 4), progressStore, controller);
      expect(controller.has(Ach.heldGround), isFalse);

      await awardFor(outcome(flips: 3), progressStore, controller);
      expect(controller.has(Ach.heldGround), isTrue);
    });

    test('Full Tilt needs top speed and every life', () async {
      await progressStore.record(400, 3, 30);

      await awardFor(outcome(levelId: 400, stars: 3, runSpeed: 200),
          progressStore, controller);
      expect(controller.has(Ach.fullTilt), isFalse, reason: 'too slow');

      await awardFor(outcome(levelId: 400, stars: 1, runSpeed: 280),
          progressStore, controller);
      expect(controller.has(Ach.fullTilt), isFalse, reason: 'lives were lost');

      await awardFor(outcome(levelId: 400, stars: 3, runSpeed: 280),
          progressStore, controller);
      expect(controller.has(Ach.fullTilt), isTrue);
    });

    test('Sweep needs every coin on the level, not merely a lot', () async {
      await progressStore.record(1, 3, 30, coins: 32, coinsOnLevel: 33);
      await awardFor(
          outcome(coins: 32, coinsOnLevel: 33), progressStore, controller);
      expect(controller.has(Ach.sweep), isFalse, reason: 'one coin short');

      await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
      await awardFor(
          outcome(coins: 33, coinsOnLevel: 33), progressStore, controller);
      expect(controller.has(Ach.sweep), isTrue);
    });

    test('Stubborn wants ten deaths on the same level', () async {
      await progressStore.record(7, 1, 30);

      await awardFor(outcome(levelId: 7, deathsOnLevel: 9), progressStore,
          controller);
      expect(controller.has(Ach.stubborn), isFalse);

      await awardFor(outcome(levelId: 7, deathsOnLevel: 10), progressStore,
          controller);
      expect(controller.has(Ach.stubborn), isTrue);
    });

    test('progress towards an incremental one is reported as it grows',
        () async {
      for (var id = 1; id <= 3; id++) {
        await progressStore.record(id, 1, 30);
      }
      await awardFor(outcome(levelId: 3, stars: 1), progressStore, controller);

      expect(controller.debugReported, contains('two_dozen:3'));
      expect(controller.has(Ach.twoDozen), isFalse, reason: '22 still to go');
    });

    test('an incremental one unlocks when it fills', () async {
      for (var id = 1; id <= 25; id++) {
        await progressStore.record(id, 1, 30);
      }
      await awardFor(outcome(levelId: 25, stars: 1), progressStore, controller);

      expect(controller.has(Ach.twoDozen), isTrue);
    });
  });

  group('the deaths a level has cost', () {
    test('are counted and survive a reload', () async {
      await progressStore.recordDeath(12);
      await progressStore.recordDeath(12);
      expect(progressStore.deathsFor(12), 2);

      await progressStore.load();
      expect(progressStore.deathsFor(12), 2,
          reason: 'Stubborn is about a level you keep coming back to, so the '
              'count has to outlive the session');
    });

    test('are wiped by resetting progress', () async {
      await progressStore.recordDeath(12);
      await progressStore.resetProgress();
      expect(progressStore.deathsFor(12), 0);
    });
  });

  test('nothing is granted in the game itself', () async {
    // CLAUDE.md section 15: being signed in must not change what happens on
    // screen. The controller therefore has no way to hand anything back —
    // no lives, no coins, no unlocks — and this is here to keep it that way.
    await progressStore.record(1, 3, 30);
    final starsBefore = progressStore.totalStars;
    final coinsBefore = progressStore.totalCoins;

    await awardFor(outcome(), progressStore, controller);

    expect(progressStore.totalStars, starsBefore);
    expect(progressStore.totalCoins, coinsBefore);
  });

  test('earning works signed out, and is owed until it can be sent', () async {
    // The whole point of buffering. A player who never signs in still earns
    // everything; signing in later hands the backlog over.
    await progressStore.record(1, 3, 30);
    await awardFor(outcome(), progressStore, controller);

    expect(controller.has(Ach.firstSteps), isTrue,
        reason: 'no account is needed to earn it');

    final reloaded = AchievementsController();
    await reloaded.load();
    expect(reloaded.has(Ach.firstSteps), isTrue,
        reason: 'and it survives a restart');
  });
}
