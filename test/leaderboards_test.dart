import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/leaderboards.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LeaderboardsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.resetProgress();
    controller = LeaderboardsController();
    await controller.load();
    controller.debugSubmitted = [];
  });

  group('the set the game submits to', () {
    test('there are four, with unique keys', () {
      expect(Lb.all.length, 4);
      expect(Lb.all.map((b) => b.key).toSet().length, 4);
      expect(Lb.all.map((b) => b.name).toSet().length, 4);
    });

    test('every board is unwired until Play Console has been told', () {
      // The ids are generated when the boards are created in the console and
      // pasted back here, exactly as the achievement ids were. Until then the
      // game tracks all of this happily and sends none of it, which is the
      // same thing that happens to a player who never signs in.
      for (final board in Lb.all) {
        expect(board.androidId, isEmpty,
            reason: '${board.name} has an id now, so update this test');
        expect(board.iosId, isEmpty);
        expect(board.wired, isFalse);
      }
    });

    test('each caps at a figure the game can actually reach', () {
      // The cap is what the board's upper score limit should be set to in the
      // console, so a score above it can only be a tampered client. Wrong here
      // and a legitimate player is either clipped or a cheat goes unnoticed.
      expect(Lb.levelsCleared.max, 10000);
      expect(Lb.starsEarned.max, 30000, reason: '3 stars on every level');
      expect(Lb.coinsCollected.max, 467430, reason: 'the pack was counted');
      expect(Lb.levelsSwept.max, 10000);
    });
  });

  group('submitting', () {
    test('sends the totals off the store, not off the run', () async {
      await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
      await progressStore.record(2, 2, 30, coins: 10, coinsOnLevel: 36);

      await controller.submitTotals(progressStore);

      expect(controller.debugSubmitted, containsAll(<String>[
        'levels_cleared:2',
        'stars_earned:5',
        'coins_collected:43',
        'levels_swept:1',
      ]));
    });

    test('a figure the platform already holds is not sent again', () async {
      // Seeded as though a previous run had been accepted, because that is
      // the only thing that fills the sent map: a score is only crossed off
      // when the platform takes it, never when the game merely tried.
      SharedPreferences.setMockInitialValues({
        'leaderboards.sent.levels_cleared': 5,
      });
      final resumed = LeaderboardsController();
      await resumed.load();
      resumed.debugSubmitted = [];

      await resumed.submit(Lb.levelsCleared, 5);
      expect(resumed.debugSubmitted, isEmpty,
          reason: 'the platform already has 5, so there is nothing to say');

      await resumed.submit(Lb.levelsCleared, 6);
      expect(resumed.debugSubmitted, contains('levels_cleared:6'));
    });

    test('a score is clamped to what the game can produce', () async {
      // A number above the cap could not have come from playing, and sending
      // one would put a figure on a public board that the game says is
      // impossible.
      await controller.submit(Lb.starsEarned, 999999);
      expect(controller.debugSubmitted, contains('stars_earned:30000'));
    });
  });

  test('nothing is granted for a score or a rank', () async {
    // CLAUDE.md section 15. The leaderboards were let in on the condition that
    // they mirror what the player already has rather than become a reason to
    // be signed in, so this asserts the controller cannot hand anything back.
    await progressStore.record(1, 3, 30, coins: 33, coinsOnLevel: 33);
    final starsBefore = progressStore.totalStars;
    final coinsBefore = progressStore.totalCoins;
    final solvedBefore = progressStore.solvedCount;

    await controller.submitTotals(progressStore);

    expect(progressStore.totalStars, starsBefore);
    expect(progressStore.totalCoins, coinsBefore);
    expect(progressStore.solvedCount, solvedBefore);
  });

  test('playing signed out still builds the figures that get sent', () async {
    // Nothing here is signed in, and every total still lands in the buffer.
    // Signing in later flushes it, so a week of signed out play arrives with
    // real numbers rather than an empty row.
    await progressStore.record(1, 3, 30);
    await progressStore.record(2, 3, 30);
    await controller.submitTotals(progressStore);

    expect(controller.debugSubmitted, contains('levels_cleared:2'));

    controller.debugSubmitted!.clear();
    await controller.flush();
    expect(controller.debugSubmitted, contains('levels_cleared:2'),
        reason: 'a score is only crossed off when the platform takes it, and '
            'signed out it never did — so it is all still owed, which is the '
            'whole point of the buffer');
  });

  test('the boards cannot be opened without an account', () async {
    // Signed out there is no board to show, so the row does not offer one.
    expect(controller.canShow, isFalse);
  });
}
