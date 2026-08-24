import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/level_repository.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/main.dart';
import 'package:pitchpole/ui/overlays/overlay_panel.dart';
import 'package:pitchpole/ui/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the pack's index for real before a screen that needs it is pumped.
///
/// The menus only ever ask for the level *count*, which is a 29 byte asset,
/// and the shard a level lives in is decoded on another isolate. A real
/// isolate never finishes inside `testWidgets`' fake clock, so the read has to
/// happen in [WidgetTester.runAsync] first; after that the repository serves
/// it from cache and the widgets settle normally.
Future<void> warmLevels(WidgetTester tester) =>
    tester.runAsync(() => levelRepository.count());

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
  });

  testWidgets('the pack reports its size without reading a level',
      (tester) async {
    // What the menus actually do. Reading the whole pack to learn how many
    // levels there are costs 29 MB of JSON and peaks near half a gigabyte,
    // which is more than Android gives an app on a cheap phone.
    final count = (await tester.runAsync(levelRepository.count))!;
    expect(count, kTotalLevels);
  });

  testWidgets('a level is reachable by id, from either end of the pack',
      (tester) async {
    // Through runAsync, because the shard is decoded on another isolate and a
    // real isolate never finishes under the fake test clock.
    await tester.runAsync(() async {
      expect((await levelRepository.byId(1))!.id, 1);
      expect((await levelRepository.byId(kTotalLevels))!.id, kTotalLevels);

      // Either side of a shard seam, which is where arithmetic on the id is
      // the thing most likely to be off by one.
      expect((await levelRepository.byId(kShardSize))!.id, kShardSize);
      expect((await levelRepository.byId(kShardSize + 1))!.id, kShardSize + 1);

      expect(await levelRepository.byId(kTotalLevels + 1), isNull,
          reason: 'past the end of the pack is nothing, not a crash');
      expect(await levelRepository.byId(0), isNull);
    });
  });

  testWidgets('home offers play and reaches level select', (tester) async {
    await warmLevels(tester);
    await tester.pumpWidget(const PitchpoleApp());
    await tester.pumpAndSettle();

    expect(find.text('PITCHPOLE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);

    await tester.tap(find.text('LEVELS'));
    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectScreen), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  group('every screen fits a landscape phone', () {
    // The game is landscape only, and a phone held sideways leaves very
    // little height. These are the real logical sizes of common handsets, and
    // the shortest is where the home page used to overflow.
    const sizes = <String, Size>{
      'iPhone SE': Size(667, 375),
      'Pixel 7': Size(732, 360),
      'short and wide': Size(900, 320),
    };

    for (final entry in sizes.entries) {
      testWidgets('${entry.key} shows home without overflowing',
          (tester) async {
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await warmLevels(tester);
        await tester.pumpWidget(const PitchpoleApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the page overflowed at ${entry.value}');
        expect(find.text('PITCHPOLE'), findsOneWidget);
        expect(find.text('PLAY'), findsOneWidget);

        // Not just "it fits": a shrink wrapping stack once pinned the whole
        // page to the left of a 2400 wide phone, which no overflow check
        // would ever have caught. The button is measured rather than its
        // label, because the label sits right of centre by half the icon.
        final centres = <String, double>{
          'title': tester.getRect(find.text('PITCHPOLE')).center.dx,
          'play button': tester
              .getRect(find.widgetWithText(PanelButton, 'PLAY'))
              .center
              .dx,
        };
        for (final entryCentre in centres.entries) {
          expect(entryCentre.value, closeTo(entry.value.width / 2, 2),
              reason: 'the ${entryCentre.key} is not centred at '
                  '${entry.value}');
        }
      });

      testWidgets('${entry.key} shows level select without overflowing',
          (tester) async {
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await warmLevels(tester);
        await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the page overflowed at ${entry.value}');
      });
    }
  });

  group('level select opens where the player is', () {
    /// Pumps level select on a realistic landscape phone and returns the
    /// scroll offset it settled at.
    Future<double> openLevelSelect(WidgetTester tester) async {
      tester.view.physicalSize = const Size(732, 360) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await warmLevels(tester);
      await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
      await tester.pumpAndSettle();

      return tester
          .widget<GridView>(find.byType(GridView))
          .controller!
          .offset;
    }

    testWidgets('a new player starts at the top', (tester) async {
      expect(await openLevelSelect(tester), 0,
          reason: 'nothing is solved, so level 1 is the current level');
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('one level in, it is still at the top', (tester) async {
      await progressStore.record(1, 3, 30.0);

      expect(await openLevelSelect(tester), 0,
          reason: 'level 2 is in the first row, so there is nothing to '
              'scroll past');
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('deep in the pack it scrolls to the current level',
        (tester) async {
      // The whole reason this exists: at 10,000 levels, opening at the top
      // leaves a player hundreds of rows away from where they got to.
      for (var id = 1; id <= 400; id++) {
        await progressStore.record(id, 3, 30.0);
      }

      final offset = await openLevelSelect(tester);
      expect(offset, greaterThan(0));

      // Level 401 is the first unsolved one, and it should be on screen.
      expect(find.text('401'), findsOneWidget,
          reason: 'the grid should open on the level the player is on');
    });
  });

  testWidgets('only the first level is unlocked on a fresh install',
      (tester) async {
    expect(progressStore.isUnlocked(1), isTrue);
    expect(progressStore.isUnlocked(2), isFalse);

    await progressStore.record(1, 3, 30.0);

    expect(progressStore.isUnlocked(2), isTrue);
    expect(progressStore.totalStars, 3);
    expect(progressStore.nextLevel(28), 2);
  });

  testWidgets('a better result replaces a worse one, never the reverse',
      (tester) async {
    await progressStore.record(4, 1, 40.0);
    await progressStore.record(4, 3, 34.0);
    expect(progressStore.starsFor(4), 3);
    expect(progressStore.bestSecondsFor(4), 34.0);

    await progressStore.record(4, 2, 38.0);
    expect(progressStore.starsFor(4), 3);
    expect(progressStore.bestSecondsFor(4), 34.0);
  });

  testWidgets('stars and best time are kept independently', (tester) async {
    // A slow clean run keeps its stars; a fast scrappy one keeps its time.
    await progressStore.record(5, 3, 45.0);
    await progressStore.record(5, 1, 31.0);

    expect(progressStore.starsFor(5), 3);
    expect(progressStore.bestSecondsFor(5), 31.0);
  });

  testWidgets('resetting progress relocks everything', (tester) async {
    await progressStore.record(1, 3, 30.0);
    await progressStore.resetProgress();

    expect(progressStore.totalStars, 0);
    expect(progressStore.isUnlocked(2), isFalse);
  });
}
