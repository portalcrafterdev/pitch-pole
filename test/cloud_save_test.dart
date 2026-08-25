import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/cloud_save.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A save as it would arrive from another device.
Map<String, dynamic> snapshot({
  Map<int, int> stars = const {},
  Map<int, double> best = const {},
  Map<int, int> coins = const {},
  Map<int, int> coinsOf = const {},
  Map<int, int> deaths = const {},
  int streak = 0,
  int? streakDay,
}) =>
    {
      'v': 1,
      'stars': {for (final e in stars.entries) '${e.key}': e.value},
      'best': {for (final e in best.entries) '${e.key}': e.value},
      'coins': {for (final e in coins.entries) '${e.key}': e.value},
      'coinsOf': {for (final e in coinsOf.entries) '${e.key}': e.value},
      'deaths': {for (final e in deaths.entries) '${e.key}': e.value},
      'streak': streak,
      'streakDay': ?streakDay,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.resetProgress();
    cloudSave.debugReset();
  });

  group('what gets carried across', () {
    test('only levels actually played are in the file', () async {
      // Ten thousand levels of empty entries would be a large upload for a
      // player who has seen forty of them.
      await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
      await progressStore.record(2, 2, 31);

      final data = progressStore.toSnapshot();
      expect((data['stars'] as Map).keys, ['1', '2']);
      expect((data['stars'] as Map)['1'], 3);
    });

    test('settings are deliberately left on the device', () async {
      // How loud a phone is, and which control scheme it uses, is a fact about
      // that phone rather than about the player.
      await progressStore.setMusic(false);
      await progressStore.setControlScheme(ControlScheme.buttons);

      final data = progressStore.toSnapshot();
      expect(data.containsKey('music'), isFalse);
      expect(data.containsKey('controls'), isFalse);
    });

    test('it survives a round trip through JSON', () async {
      await progressStore.record(7, 3, 29.5, coins: 12, coinsOnLevel: 40);
      final wire = jsonDecode(jsonEncode(progressStore.toSnapshot()));

      await progressStore.resetProgress();
      await progressStore.mergeSnapshot(wire as Map<String, dynamic>);

      expect(progressStore.starsFor(7), 3);
      expect(progressStore.bestSecondsFor(7), 29.5);
      expect(progressStore.bestCoinsFor(7), 12);
    });
  });

  group('merging keeps the better side', () {
    test('more stars wins, in either direction', () async {
      await progressStore.record(1, 1, 30);
      await progressStore.mergeSnapshot(snapshot(stars: {1: 3}));
      expect(progressStore.starsFor(1), 3, reason: 'the cloud was better');

      await progressStore.record(2, 3, 30);
      await progressStore.mergeSnapshot(snapshot(stars: {2: 1}));
      expect(progressStore.starsFor(2), 3, reason: 'the device was better');
    });

    test('the faster time wins, not the newer one', () async {
      await progressStore.record(1, 3, 31.5);
      await progressStore.mergeSnapshot(snapshot(best: {1: 30.2}));
      expect(progressStore.bestSecondsFor(1), 30.2);

      await progressStore.mergeSnapshot(snapshot(best: {1: 44.0}));
      expect(progressStore.bestSecondsFor(1), 30.2,
          reason: 'a slower run from another device must not overwrite a PB');
    });

    test('more coins wins', () async {
      await progressStore.record(1, 3, 30, coins: 10, coinsOnLevel: 33);
      await progressStore.mergeSnapshot(snapshot(coins: {1: 33}));
      expect(progressStore.bestCoinsFor(1), 33);
    });

    test('the longer streak wins, and brings its own day with it', () async {
      final day = ProgressStore.dayIndex(DateTime(2026, 5, 4));
      await progressStore.notePlayed(now: DateTime(2026, 5, 4));
      expect(progressStore.streakOn(DateTime(2026, 5, 4)), 1);

      await progressStore.mergeSnapshot(snapshot(streak: 9, streakDay: day));
      expect(progressStore.streakOn(DateTime(2026, 5, 4)), 9);
    });

    test('a streak arriving without a day keeps the device its own', () async {
      // An older save may carry a streak and no day. Taking the count and
      // leaving this device's day alone is right: the day here is real, the
      // player did play today, and pairing the longer streak with it is the
      // reading that does not lose them anything.
      await progressStore.notePlayed(now: DateTime(2026, 5, 4));
      await progressStore.mergeSnapshot(snapshot(streak: 9));

      expect(progressStore.streakOn(DateTime(2026, 5, 4)), 9);
      expect(progressStore.streakOn(DateTime(2026, 5, 9)), 0,
          reason: 'and it is still a real streak that can be broken, not one '
              'pinned open by a day that never happened');
    });
  });

  group('merging is safe to repeat', () {
    test('deaths take the larger count rather than the sum', () async {
      // This is the one that would quietly break. Adding looks right — deaths
      // on two devices really did both happen — but a device syncs the same
      // save over and over, so adding doubles, then doubles again, and hands
      // out Stubborn to somebody who never earned it.
      await progressStore.recordDeath(7);
      await progressStore.recordDeath(7);

      await progressStore.mergeSnapshot(snapshot(deaths: {7: 6}));
      expect(progressStore.deathsFor(7), 6);

      await progressStore.mergeSnapshot(snapshot(deaths: {7: 6}));
      await progressStore.mergeSnapshot(snapshot(deaths: {7: 6}));
      expect(progressStore.deathsFor(7), 6,
          reason: 'merging the same save three times must equal merging once');
    });

    test('merging the same save twice changes nothing', () async {
      final save = snapshot(
        stars: {1: 3, 2: 2},
        best: {1: 30.0},
        coins: {1: 33},
        streak: 4,
        streakDay: ProgressStore.dayIndex(DateTime(2026, 5, 4)),
      );

      await progressStore.mergeSnapshot(save);
      final afterOnce = progressStore.toSnapshot().toString();

      await progressStore.mergeSnapshot(save);
      expect(progressStore.toSnapshot().toString(), afterOnce);
    });
  });

  group('signing in can never cost the player anything', () {
    test('progress made signed out survives an empty cloud', () async {
      // The failure that makes people uninstall a game. A first sign in on a
      // phone with real progress must merge, never be flattened by whatever
      // the cloud happened to hold.
      await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
      await progressStore.record(2, 3, 30);
      await progressStore.record(3, 2, 30);

      await progressStore.mergeSnapshot(snapshot());

      expect(progressStore.solvedCount, 3);
      expect(progressStore.totalStars, 8);
    });

    test('two devices end up with the best of both', () async {
      // This phone did better on level 1, the other on level 2. Both are kept.
      await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
      await progressStore.record(2, 1, 38);

      await progressStore.mergeSnapshot(snapshot(
        stars: {1: 1, 2: 3},
        best: {1: 41.0, 2: 30.0},
        coins: {1: 4, 2: 40},
      ));

      expect(progressStore.starsFor(1), 3);
      expect(progressStore.starsFor(2), 3);
      expect(progressStore.bestSecondsFor(1), 30.0);
      expect(progressStore.bestSecondsFor(2), 30.0);
      expect(progressStore.bestCoinsFor(1), 33);
      expect(progressStore.bestCoinsFor(2), 40);
    });

    test('a merged save is written to disk, not just held in memory', () async {
      await progressStore.mergeSnapshot(snapshot(stars: {5: 3}, coins: {5: 9}));

      await progressStore.load();
      expect(progressStore.starsFor(5), 3,
          reason: 'restored progress has to outlive the session that fetched '
              'it, or every launch re-downloads the same save');
      expect(progressStore.bestCoinsFor(5), 9);
    });
  });

  group('nothing here can break a run', () {
    test('rubbish in the save is ignored, not thrown', () async {
      await progressStore.record(1, 3, 30);

      await progressStore.mergeSnapshot({'v': 1, 'stars': 'not a map'});
      await progressStore.mergeSnapshot({'stars': {'x': 'y', '2': null}});
      await progressStore.mergeSnapshot(const {});

      expect(progressStore.starsFor(1), 3, reason: 'and progress is untouched');
    });

    test('nothing is uploaded or restored while signed out', () async {
      // No account, no sync, and no error either. Exactly what a player who
      // never signs in has always had.
      cloudSave.debugUploaded = [];
      cloudSave.debugDownload = jsonEncode(snapshot(stars: {1: 3}));

      await progressStore.record(1, 1, 30);
      cloudSave.scheduleSave();
      await cloudSave.save();
      await cloudSave.restore();

      expect(cloudSave.debugUploaded, isEmpty);
      expect(progressStore.starsFor(1), 1,
          reason: 'the cloud save must not be applied without an account');
    });
  });
}
