import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/ads.dart';
import 'package:pitchpole/ui/overlays/level_complete.dart';
import 'package:pitchpole/ui/widgets/confetti_fall.dart';
import 'package:pitchpole/ui/overlays/overlay_panel.dart';
import 'package:pitchpole/ui/widgets/star_row.dart';

/// The panel is the one screen that cannot be reached by driving the app: it
/// needs a level cleared, which is thirty seconds of correct input. So it is
/// checked here instead of on a phone.
void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required int stars,
    required int livesLost,
    double seconds = 30.2,
    double? bestSeconds,
    int coins = 28,
    int totalCoins = 40,
    bool hasNext = true,
    Size size = const Size(732, 360),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelComplete(
            levelId: 12,
            stars: stars,
            livesLost: livesLost,
            seconds: seconds,
            bestSeconds: bestSeconds,
            coins: coins,
            totalCoins: totalCoins,
            hasNext: hasNext,
            onNext: () {},
            onRetry: () {},
            onLevels: () {},
            onHome: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('says what was cleared, and how the run went', (tester) async {
    await pumpPanel(tester, stars: 2, livesLost: 1);

    expect(find.text('CLEARED'), findsOneWidget);
    // The level and the band it belongs to, above the headline. Twelve is in
    // the ramp, not the taught five — section 8 draws that line at level 5.
    expect(find.text('LEVEL 12  ·  THE RAMP'), findsOneWidget);

    expect(find.text('30.2s'), findsOneWidget);
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.text('28/40'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('LIFE LOST'), findsOneWidget,
        reason: 'singular at one, because "1 LIVES LOST" looks unfinished');

    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(find.text('RUN IT CLEAN'), findsOneWidget);
    expect(find.text('LEVELS'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the celebration waits for the ad to get off the screen',
      (tester) async {
    // The break now lands on a clear, so it opens over the top of this panel.
    // The stars pop in one at a time and the confetti falls once, and both
    // used to start the moment the panel was built — so the whole celebration
    // played behind the ad and the player dismissed it onto three stars
    // already sitting still.
    adsController.debugShowingAd = true;
    addTearDown(() => adsController.debugShowingAd = false);

    await pumpPanel(tester, stars: 3, livesLost: 0);
    expect(find.byType(ConfettiFall), findsNothing,
        reason: 'nothing celebrates while an ad is covering the screen');
    expect(tester.widget<StarRow>(find.byType(StarRow)).animate, isFalse);

    adsController.debugShowingAd = false;
    await tester.pump();

    expect(find.byType(ConfettiFall), findsOneWidget);
    expect(tester.widget<StarRow>(find.byType(StarRow)).animate, isTrue,
        reason: 'and it all starts the moment the screen is theirs again');
  });

  testWidgets('home is offered on every run, however it went', (tester) async {
    // Four buttons at one star, three at three. The way out has to be there
    // either way: the panel cannot be dismissed by tapping around it, so it is
    // the only way back to the front door.
    for (final stars in [1, 2, 3]) {
      await pumpPanel(tester, stars: stars, livesLost: 3 - stars);
      expect(find.text('HOME'), findsOneWidget);
    }
  });

  testWidgets('a slower run is not sold as a best', (tester) async {
    await pumpPanel(tester, stars: 3, livesLost: 0, bestSeconds: 29.4);

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('NEW BEST'), findsNothing);
    expect(find.text('LIVES LOST'), findsOneWidget);
  });

  testWidgets('a clean sweep is called out', (tester) async {
    await pumpPanel(tester, stars: 3, livesLost: 0, coins: 40);

    expect(find.text('EVERY COIN'), findsOneWidget,
        reason: 'sweeping a level is the reason to come back to one already '
            'beaten, so it gets said rather than left as 40/40');
  });

  testWidgets('three stars drops the retry, since there is nothing to beat',
      (tester) async {
    await pumpPanel(tester, stars: 3, livesLost: 0);

    expect(find.text('RUN IT CLEAN'), findsNothing);
    expect(find.text('NEXT LEVEL'), findsOneWidget);
  });

  testWidgets('the last level has nowhere to go next', (tester) async {
    await pumpPanel(tester, stars: 3, livesLost: 0, hasNext: false);

    expect(find.text('NEXT LEVEL'), findsNothing);
    expect(find.text('LEVELS'), findsOneWidget);
  });

  testWidgets('the label, the headline and the stars share a centre line',
      (tester) async {
    // Three things stacked over each other, laid out by three different
    // widgets. Ranged left the heading sat over a row of stars that had
    // centred themselves, and the block read as two separate layouts.
    await pumpPanel(tester, stars: 2, livesLost: 1);

    final label = tester.getCenter(find.text('LEVEL 12  ·  THE RAMP')).dx;
    final headline = tester.getCenter(find.text('CLEARED')).dx;
    final stars = tester.getCenter(find.byType(StarRow)).dx;

    expect(headline, closeTo(label, 1));
    expect(stars, closeTo(label, 1));
  });

  group('it fits a landscape phone', () {
    // The panel carries a heading, a star row, a three column strip and three
    // buttons into about 360 points of height. Every one of these overflowed
    // at some point in its life.
    const sizes = <String, Size>{
      'iPhone SE': Size(667, 375),
      'Pixel 7': Size(732, 360),
      'short and wide': Size(900, 320),
    };

    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpPanel(
          tester,
          stars: 1,
          livesLost: 2,
          size: entry.value,
        );

        expect(tester.takeException(), isNull,
            reason: 'the panel overflowed at ${entry.value}');
        expect(find.byType(OverlayPanel), findsOneWidget);
        expect(find.text('CLEARED'), findsOneWidget);
      });
    }
  });
}
