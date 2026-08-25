import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixed point to count days from, so nothing here depends on the day the
/// suite happens to run. Mid-month and mid-morning, so adding or subtracting a
/// day never crosses a month boundary by accident.
final DateTime _base = DateTime(2026, 3, 12, 10, 30);

DateTime _day(int offset, {int hour = 10}) =>
    DateTime(2026, 3, 12 + offset, hour, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.resetProgress();
  });

  test('a new player has no streak', () {
    expect(progressStore.streakOn(_base), 0);
  });

  test('the first run makes it one, not zero', () async {
    // Playing is the thing being counted, so a run has to leave the counter
    // showing something. Starting at zero would read as not having counted.
    await progressStore.notePlayed(now: _base);
    expect(progressStore.streakOn(_base), 1);
  });

  test('playing again the same day does not count twice', () async {
    await progressStore.notePlayed(now: _day(0, hour: 9));
    await progressStore.notePlayed(now: _day(0, hour: 21));
    expect(progressStore.streakOn(_base), 1);
  });

  test('consecutive days add up', () async {
    for (var i = 0; i < 5; i++) {
      await progressStore.notePlayed(now: _day(i));
    }
    expect(progressStore.streakOn(_day(4)), 5);
  });

  test('a missed day breaks it back to zero', () async {
    await progressStore.notePlayed(now: _day(0));
    await progressStore.notePlayed(now: _day(1));
    expect(progressStore.streakOn(_day(1)), 2);

    // Day 2 is skipped entirely, and by day 3 the run is gone.
    expect(progressStore.streakOn(_day(3)), 0);
  });

  test('playing after a break starts again at one', () async {
    await progressStore.notePlayed(now: _day(0));
    await progressStore.notePlayed(now: _day(1));
    await progressStore.notePlayed(now: _day(5));
    expect(progressStore.streakOn(_day(5)), 1);
  });

  test('yesterday still counts as alive', () async {
    // The streak is not broken the instant midnight passes. A player who
    // played yesterday and has not opened the game yet today is mid streak,
    // and being shown a zero all morning would tell them they had lost
    // something they still have.
    await progressStore.notePlayed(now: _day(0));
    await progressStore.notePlayed(now: _day(1));

    expect(progressStore.streakOn(_day(2, hour: 8)), 2,
        reason: 'not played today yet, but today is not over');

    await progressStore.notePlayed(now: _day(2, hour: 23));
    expect(progressStore.streakOn(_day(2, hour: 23)), 3);
  });

  test('a day is a local day, not 24 hours', () async {
    // One minute past midnight is a new day; one minute to midnight is not.
    await progressStore.notePlayed(now: DateTime(2026, 3, 12, 23, 59));
    expect(progressStore.streakOn(DateTime(2026, 3, 12, 23, 59)), 1);

    await progressStore.notePlayed(now: DateTime(2026, 3, 13, 0, 1));
    expect(progressStore.streakOn(DateTime(2026, 3, 13, 0, 1)), 2,
        reason: 'two minutes apart, but two different days');
  });

  test('it survives a restart', () async {
    await progressStore.notePlayed(now: _day(0));
    await progressStore.notePlayed(now: _day(1));

    await progressStore.load();
    expect(progressStore.streakOn(_day(1)), 2,
        reason: 'a streak that forgot itself overnight would be no streak');
  });

  test('resetting progress clears it', () async {
    await progressStore.notePlayed(now: _base);
    await progressStore.resetProgress();
    expect(progressStore.streakOn(_base), 0);

    await progressStore.load();
    expect(progressStore.streakOn(_base), 0, reason: 'and stays cleared');
  });

  test('a broken streak is only hidden, never rewritten behind the player',
      () async {
    // streakOn reports zero once a day has been missed, but the stored run is
    // left alone until the next time they play. Nothing is mutated by asking.
    await progressStore.notePlayed(now: _day(0));
    await progressStore.notePlayed(now: _day(1));
    expect(progressStore.streakOn(_day(9)), 0);
    expect(progressStore.streakOn(_day(1)), 2,
        reason: 'reading a broken streak must not destroy the record of it');
  });

  test('the day index counts real days across a month boundary', () {
    expect(
      ProgressStore.dayIndex(DateTime(2026, 4, 1, 3)) -
          ProgressStore.dayIndex(DateTime(2026, 3, 31, 22)),
      1,
    );
    expect(
      ProgressStore.dayIndex(DateTime(2027, 1, 1)) -
          ProgressStore.dayIndex(DateTime(2026, 12, 31)),
      1,
    );
  });
}
