import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/game/logic/run_state.dart';
import 'package:pitchpole/ui/overlays/pause_menu.dart';
import 'package:pitchpole/ui/widgets/touch_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<List<RunInput>> mount(
    WidgetTester tester, {
    required ControlScheme scheme,
    bool gravityUp = false,
  }) async {
    final pressed = <RunInput>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TouchControls(
            onInput: pressed.add,
            gravityUp: gravityUp,
            scheme: scheme,
          ),
        ),
      ),
    );
    return pressed;
  }

  /// Lets the press flash timers run out, so nothing is left pending.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 250));

  group('screen halves', () {
    testWidgets('the left half flips and the right half jumps', (tester) async {
      final pressed = await mount(tester, scheme: ControlScheme.halves);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(size.width * 0.25, size.height / 2));
      await settle(tester);
      await tester.tapAt(Offset(size.width * 0.75, size.height / 2));
      await settle(tester);

      expect(pressed, [RunInput.flipUp, RunInput.jump]);
    });

    testWidgets('the flip half toggles, because a half cannot say which way',
        (tester) async {
      final pressed = await mount(
        tester,
        scheme: ControlScheme.halves,
        gravityUp: true,
      );
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(size.width * 0.25, size.height / 2));
      await settle(tester);

      expect(pressed, [RunInput.flipDown]);
    });

    testWidgets('there are no buttons to miss', (tester) async {
      await mount(tester, scheme: ControlScheme.halves);
      expect(find.byIcon(Icons.height_rounded), findsNothing);
    });
  });

  group('buttons', () {
    testWidgets('the pads send absolute flips and a jump', (tester) async {
      final pressed = await mount(tester, scheme: ControlScheme.buttons);

      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_up_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.height_rounded));
      await settle(tester);

      expect(pressed, [RunInput.flipUp, RunInput.flipDown, RunInput.jump],
          reason: 'up and down are separate, never a toggle');
    });

    testWidgets('a tap anywhere else does nothing', (tester) async {
      final pressed = await mount(tester, scheme: ControlScheme.buttons);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      // The middle of the screen, the top, and the spot the halves scheme
      // would have treated as flip.
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.tapAt(Offset(size.width / 2, 20));
      await tester.tapAt(Offset(size.width * 0.25, size.height * 0.3));
      await settle(tester);

      expect(pressed, isEmpty,
          reason: 'with buttons on, the screen itself must be inert');
    });

    testWidgets('nothing fires while the controls are disabled',
        (tester) async {
      final pressed = <RunInput>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouchControls(
              onInput: pressed.add,
              gravityUp: false,
              scheme: ControlScheme.buttons,
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.height_rounded));
      await settle(tester);

      expect(pressed, isEmpty);
    });
  });

  testWidgets('switching the scheme swaps the controls straight away',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.setControlScheme(ControlScheme.halves);

    final pressed = <RunInput>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AnimatedBuilder(
                animation: progressStore,
                builder: (context, _) => TouchControls(
                  onInput: pressed.add,
                  gravityUp: false,
                  scheme: progressStore.controlScheme,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.height_rounded), findsNothing,
        reason: 'halves has no buttons');

    await progressStore.setControlScheme(ControlScheme.buttons);
    await tester.pump();

    expect(find.byIcon(Icons.height_rounded), findsOneWidget,
        reason: 'the pads should appear without a restart');

    await progressStore.setControlScheme(ControlScheme.halves);
    await tester.pump();

    expect(find.byIcon(Icons.height_rounded), findsNothing,
        reason: 'and go away again');
  });

  group('the pause menu fits a landscape phone without scrolling', () {
    // Pausing is done mid level to change one thing and get back to running.
    // A panel that has to be scrolled to reach the buttons fails at that, and
    // this one did: stacked in a single column it came to around 570 points in
    // a viewport about 360 tall.
    //
    // Measured as "nothing to scroll" rather than "no overflow". The panel is
    // deliberately still inside a scroll view, for the phone with the font
    // size turned all the way up, so an overflow check would pass while the
    // buttons sat below the fold.
    const sizes = <String, Size>{
      'iPhone SE': Size(667, 375),
      'Pixel 7': Size(732, 360),
      'short and wide': Size(900, 320),
    };

    for (final entry in sizes.entries) {
      testWidgets('${entry.key} shows the whole panel', (tester) async {
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await progressStore.load();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PauseMenu(
                levelId: 1,
                seconds: 30,
                onResume: () {},
                onRestart: () {},
                onLevels: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final position = tester.state<ScrollableState>(
          find.byType(Scrollable),
        ).position;
        expect(position.maxScrollExtent, 0,
            reason: 'the pause menu has ${position.maxScrollExtent} points '
                'hidden below the fold at ${entry.value}');

        // And every way out of the panel is actually on screen.
        for (final label in ['RESUME', 'RESTART LEVEL', 'LEVELS']) {
          expect(find.text(label), findsOneWidget);
          final rect = tester.getRect(find.text(label));
          expect(rect.bottom, lessThanOrEqualTo(entry.value.height),
              reason: '$label is off the bottom at ${entry.value}');
        }
      });
    }
  });

  testWidgets('the pause menu switches the scheme live', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
    await progressStore.setControlScheme(ControlScheme.halves);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PauseMenu(
            levelId: 1,
            seconds: 30,
            onResume: () {},
            onRestart: () {},
            onLevels: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('BUTTONS'));
    await tester.pump();

    expect(progressStore.controlScheme, ControlScheme.buttons);
  });

  group('tapping away from the pause panel', () {
    /// Mounts the pause menu and reports how many times each way out was
    /// taken, so a tap can be checked to have done exactly one thing.
    Future<Map<String, int>> mountPause(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await progressStore.load();

      final taken = {'resume': 0, 'restart': 0, 'levels': 0};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenu(
              levelId: 1,
              seconds: 30,
              onResume: () => taken['resume'] = taken['resume']! + 1,
              onRestart: () => taken['restart'] = taken['restart']! + 1,
              onLevels: () => taken['levels'] = taken['levels']! + 1,
            ),
          ),
        ),
      );
      return taken;
    }

    testWidgets('resumes, the same as the button', (tester) async {
      final taken = await mountPause(tester);

      // The very top left corner: as far from the panel as the screen goes.
      await tester.tapAt(const Offset(6, 6));
      await tester.pump();

      expect(taken['resume'], 1);
      expect(taken['restart'], 0, reason: 'it must not pick an action');
      expect(taken['levels'], 0);
    });

    testWidgets('but a tap on the panel itself does nothing', (tester) async {
      final taken = await mountPause(tester);

      // The title. Inside the panel, but not on anything that does something:
      // a mis-tap here is a miss, not a decision to resume.
      await tester.tap(find.text('PAUSED'));
      await tester.pump();

      expect(taken['resume'], 0);
    });

    testWidgets('and the buttons still win over it', (tester) async {
      final taken = await mountPause(tester);

      // Two tap recognizers cover this pixel. The innermost has to take it,
      // or every button in every overlay would resume instead.
      await tester.tap(find.text('RESTART LEVEL'));
      await tester.pump();

      expect(taken['restart'], 1);
      expect(taken['resume'], 0);
    });
  });

  group('the audio sliders', () {
    testWidgets('are in the pause menu and move the stored level',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await progressStore.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenu(
              levelId: 1,
              seconds: 30,
              onResume: () {},
              onRestart: () {},
              onLevels: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOUND'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text('100'), findsNWidgets(2),
          reason: 'both start at full');

      // Drag the sound slider to somewhere left of where it is.
      final sound = find.byType(Slider).first;
      await tester.tapAt(tester.getCenter(sound) - const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(progressStore.soundVolume, lessThan(1));
      expect(progressStore.soundVolume, greaterThan(0));
      expect(progressStore.musicVolume, 1,
          reason: 'the two channels are independent');
    });

    testWidgets('a muted channel cannot be dragged', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await progressStore.load();
      await progressStore.setSound(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenu(
              levelId: 1,
              seconds: 30,
              onResume: () {},
              onRestart: () {},
              onLevels: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = progressStore.soundVolume;
      await tester.tapAt(
        tester.getCenter(find.byType(Slider).first) - const Offset(60, 0),
      );
      await tester.pumpAndSettle();

      expect(progressStore.soundVolume, before,
          reason: 'muted keeps the level it will come back to');
    });

    testWidgets('the panel still fits a landscape phone', (tester) async {
      // The pause panel has grown a lot: scheme chips, two slider rows and
      // three buttons, on a screen about 320 points tall.
      tester.view.physicalSize = const Size(900, 320) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      await progressStore.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenu(
              levelId: 1,
              seconds: 30,
              onResume: () {},
              onRestart: () {},
              onLevels: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the pause panel overflowed on a short landscape screen');
    });

    test('the stored level survives a reload and is clamped', () async {
      SharedPreferences.setMockInitialValues({
        'settings.soundVolume': 0.4,
        // Out of range on purpose: a hand edited or corrupt value must not
        // reach the audio layer, where it would be a volume above full.
        'settings.musicVolume': 3.5,
      });
      await progressStore.load();

      expect(progressStore.soundVolume, 0.4);
      expect(progressStore.musicVolume, 1);
    });
  });

  test('an unknown stored scheme falls back to the halves', () {
    expect(ControlScheme.fromName(null), ControlScheme.halves);
    expect(ControlScheme.fromName('nonsense'), ControlScheme.halves);
    expect(ControlScheme.fromName('buttons'), ControlScheme.buttons);
  });
}