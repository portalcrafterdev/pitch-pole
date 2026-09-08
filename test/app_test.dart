import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/level_repository.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/ui/chapters.dart';
import 'package:pitchpole/main.dart';
import 'package:pitchpole/ui/overlays/overlay_panel.dart';
import 'package:pitchpole/ui/screens/level_select_screen.dart';
import 'package:pitchpole/ui/widgets/star_row.dart';
import 'package:pitchpole/ui/widgets/steady_insets.dart';
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

/// The screens under the wrapper `main.dart` puts them under.
///
/// [SteadyInsets] is what keeps a page from relayouting when the system bars
/// show themselves, so a screen pumped bare is not the screen the player has.
Widget app(Widget home) =>
    MaterialApp(home: home, builder: SteadyInsets.wrap);

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
        await tester.pumpWidget(app(const LevelSelectScreen()));
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
      await tester.pumpWidget(app(const LevelSelectScreen()));
      await tester.pumpAndSettle();

      // The outer scroller is a list of chapters; the grids inside a chapter
      // are fixed blocks that do not scroll on their own.
      return tester.widget<ListView>(find.byType(ListView)).controller!.offset;
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

    testWidgets('a level part way down a chapter opens on screen',
        (tester) async {
      // Eighty is four rows into chapter two: far enough down that the grid
      // has to scroll to it, near enough the front that it would be easy to
      // assume the top of the list was good enough.
      for (var id = 1; id < 80; id++) {
        await progressStore.record(id, 3, 30.0);
      }

      final offset = await openLevelSelect(tester);
      expect(offset, greaterThan(0));
      expect(find.text('1'), findsNothing,
          reason: 'the player should not be looking at the start of the pack');

      // Not `findsOneWidget`: a lazy list builds a cache extent either side of
      // what it shows, so a tile can be in the tree and still be off screen.
      // Where it actually sits is the only thing that answers the question.
      final tile = tester.getRect(find.text('80'));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tile.top, greaterThan(0));
      expect(tile.bottom, lessThan(screen.height));
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

  testWidgets('the grid holds still when the system bars show themselves',
      (tester) async {
    // The bars are hidden by immersive mode, but a swipe from an edge brings
    // them back for two or three seconds on their own. In landscape that is a
    // navigation bar down one edge, and the grid used to shrink for exactly as
    // long as it was up and then grow back.
    tester.view.physicalSize = const Size(732, 360) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);

    await warmLevels(tester);
    await tester.pumpWidget(app(const LevelSelectScreen()));
    await tester.pumpAndSettle();

    Size tileSize() => tester.getSize(
          find.ancestor(of: find.text('1'), matching: find.byType(Column)).first,
        );
    final steady = tileSize();

    tester.view.padding = const FakeViewPadding(right: 48 * 2);
    await tester.pumpAndSettle();
    expect(tileSize(), steady, reason: 'the grid shrank under the bar');

    // And back again, which is the half that made it read as a flicker.
    tester.view.resetPadding();
    await tester.pumpAndSettle();
    expect(tileSize(), steady);
  });

  testWidgets('a real cutout is still respected', (tester) async {
    // The point is to ignore a bar that is about to go away, not to run the
    // page under a notch. A padding that is there from the first frame is not
    // transient, and is honoured.
    tester.view.physicalSize = const Size(732, 360) * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(left: 40 * 2);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);

    await warmLevels(tester);
    await tester.pumpWidget(app(const LevelSelectScreen()));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(ListView)).dx, greaterThanOrEqualTo(40),
        reason: 'the grid ran under the cutout');
  });

  testWidgets('the grid holds still while the jump dialog is open',
      (tester) async {
    // Opening "go to level" raises the keyboard, and an IME pulls Android out
    // of immersive mode, so the navigation bar comes back along the right
    // edge in landscape. That is a real inset and SafeArea honoured it, so
    // every tile in the grid was rebuilt narrower — behind a scrim, for a
    // dialog about to close.
    tester.view.physicalSize = const Size(732, 360) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await warmLevels(tester);
    await tester.pumpWidget(app(const LevelSelectScreen()));
    await tester.pumpAndSettle();

    final before = tester.getSize(
      find.ancestor(of: find.text('1'), matching: find.byType(Column)).first,
    );

    await tester.tap(find.text('Go to level'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // What the IME does to the page: a navigation bar down the right edge and
    // a keyboard along the bottom.
    tester.view.padding = const FakeViewPadding(right: 48 * 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 150 * 2);
    addTearDown(() {
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.ancestor(of: find.text('1'), matching: find.byType(Column)).first,
      ),
      before,
      reason: 'a tile resized behind the dialog that covers it',
    );
  });

  group('the grid says where a chapter begins', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(732, 360) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await warmLevels(tester);
      await tester.pumpWidget(app(const LevelSelectScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('every chapter carries a header of its own', (tester) async {
      // Fifty levels never divide evenly by the seven or eight columns a
      // phone fits, so in a flat grid chapter two started in the middle of a
      // row with nothing on screen saying so.
      await open(tester);
      expect(find.text('CHAPTER 1  ·  TAUGHT'), findsOneWidget);
    });

    testWidgets('the header names the band its first level is in',
        (tester) async {
      // Chapter 1 holds the boundary at level 5, so the band cannot be read
      // off the chapter number: it is the first level in the chapter that
      // decides it.
      expect(bandFor(1), 'TAUGHT');
      expect(bandFor(51), 'THE RAMP');
      expect(bandFor(301), 'THE LONG CLIMB');
    });

    testWidgets('a chapter starts on a row of its own', (tester) async {
      await open(tester);

      // Tile centres, not text: '1' and '51' are different widths, so their
      // own left edges say nothing about which column they are in.
      double columnOf(String id) => tester.getCenter(
            find.ancestor(of: find.text(id), matching: find.byType(Column)).first,
          ).dx;
      final firstColumn = columnOf('1');

      await tester.dragUntilVisible(
        find.text('CHAPTER 2  ·  THE RAMP'),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      // Level 50 ends chapter 1 and 51 opens chapter 2. In a flat grid they
      // sat side by side; now a header comes between them and 51 is back at
      // the start of a row.
      expect(columnOf('51'), closeTo(firstColumn, 0.5),
          reason: 'chapter 2 should open at the start of a fresh row');
      expect(
        tester.getCenter(find.text('CHAPTER 2  ·  THE RAMP')).dy,
        lessThan(tester.getCenter(find.text('51')).dy),
        reason: 'the header should sit above the chapter it names',
      );
    });
  });

  group('a tile says where you stand with its level', () {
    /// Pumps level select and returns the finder for one tile's subtree, so a
    /// mark can be looked for inside the tile it belongs to rather than
    /// anywhere on a page holding a hundred of them.
    Future<Finder> tileFor(WidgetTester tester, String levelId) async {
      tester.view.physicalSize = const Size(732, 360) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await warmLevels(tester);
      await tester.pumpWidget(app(const LevelSelectScreen()));
      await tester.pumpAndSettle();

      // `.first` because ancestors come back nearest first, and the page
      // itself is a Column too: without it the search reaches every other
      // tile in the grid and a locked tile borrows level 1's stars.
      return find
          .ancestor(of: find.text(levelId), matching: find.byType(Column))
          .first;
    }

    testWidgets('a locked one carries a padlock where the stars would be',
        (tester) async {
      // The padlock sits in the star slot rather than beside the number, so
      // every tile in a row shares one centre line whatever state it is in.
      final tile = await tileFor(tester, '2');

      expect(find.descendant(of: tile, matching: find.byType(StarRow)),
          findsNothing);
      expect(
          find.descendant(
              of: tile, matching: find.byIcon(Icons.lock_rounded)),
          findsOneWidget);
    });

    testWidgets('an open one carries its stars and no padlock',
        (tester) async {
      // Three stars rather than two, so the header's star total is not also
      // the string '2' and the tile stays the only thing that finder matches.
      await progressStore.record(1, 3, 39.0);
      final tile = await tileFor(tester, '2');

      expect(find.descendant(of: tile, matching: find.byType(StarRow)),
          findsOneWidget);
      expect(
          find.descendant(
              of: tile, matching: find.byIcon(Icons.lock_rounded)),
          findsNothing,
          reason: 'a padlock on a level you can play is a lie');
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

  testWidgets('progress outlives the session that made it', (tester) async {
    // The most basic promise the game makes, and until now nothing held it:
    // there were tests that a better result replaces a worse one, and that a
    // reset clears everything, but none that a star was still there after the
    // app was closed. Every other kind of progress had such a test — the daily
    // streak, the deaths a level has cost, a restored cloud save — and the one
    // thing every player actually cares about did not.
    await progressStore.record(1, 3, 30.0, coins: 33, coinsOnLevel: 33);
    await progressStore.record(2, 2, 34.5, coins: 11, coinsOnLevel: 40);

    // What a relaunch does: build the store again from what is on disk.
    await progressStore.load();

    expect(progressStore.starsFor(1), 3);
    expect(progressStore.starsFor(2), 2);
    expect(progressStore.bestSecondsFor(1), 30.0);
    expect(progressStore.bestSecondsFor(2), 34.5);
    expect(progressStore.bestCoinsFor(1), 33);
    expect(progressStore.totalStars, 5);
    expect(progressStore.solvedCount, 2);
    expect(progressStore.isUnlocked(3), isTrue,
        reason: 'a player who closed the game must not find level 3 locked '
            'again when they come back');
  });
}
