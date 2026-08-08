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

  test('an unknown stored scheme falls back to the halves', () {
    expect(ControlScheme.fromName(null), ControlScheme.halves);
    expect(ControlScheme.fromName('nonsense'), ControlScheme.halves);
    expect(ControlScheme.fromName('buttons'), ControlScheme.buttons);
  });
}