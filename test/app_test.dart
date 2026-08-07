import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/level_repository.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/main.dart';
import 'package:pitchpole/ui/overlays/overlay_panel.dart';
import 'package:pitchpole/ui/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
  });

  testWidgets('the level pack loads from the asset bundle', (tester) async {
    final levels = await levelRepository.loadAll();

    expect(levels.length, greaterThanOrEqualTo(15));
    expect(levels.first.id, 1);
  });

  testWidgets('home offers play and reaches level select', (tester) async {
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

        await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the page overflowed at ${entry.value}');
      });
    }
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
