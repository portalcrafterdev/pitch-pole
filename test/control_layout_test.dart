import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/ui/screens/control_layout_screen.dart';
import 'package:pitchpole/ui/widgets/touch_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A realistic landscape phone.
const Size kPhone = Size(732, 360);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await progressStore.load();
  });

  group('where the pads sit', () {
    test('a fresh install has all three at home', () {
      for (final pad in ControlPad.values) {
        expect(progressStore.padSpot(pad), pad.home);
      }
      expect(progressStore.padsMoved, isFalse);
    });

    test('a moved pad outlives the session that moved it', () async {
      await progressStore.setPadSpot(ControlPad.jump, const Offset(0.2, 0.3));

      // What a relaunch does.
      await progressStore.load();

      expect(progressStore.padSpot(ControlPad.jump), const Offset(0.2, 0.3));
      expect(progressStore.padsMoved, isTrue,
          reason: 'a layout the player set up has to still be there when they '
              'come back, or they will set it up once and never again');

      // And the two nobody touched are untouched.
      expect(progressStore.padSpot(ControlPad.floor), ControlPad.floor.home);
    });

    test('reset puts every pad back', () async {
      await progressStore.setPadSpot(ControlPad.jump, const Offset(0.2, 0.3));
      await progressStore.setPadSpot(ControlPad.floor, const Offset(0.8, 0.3));

      await progressStore.resetPadLayout();
      await progressStore.load();

      for (final pad in ControlPad.values) {
        expect(progressStore.padSpot(pad), pad.home);
      }
      expect(progressStore.padsMoved, isFalse);
    });

    test('half a saved coordinate is ignored, not half applied', () async {
      // A write that was interrupted between the two keys. Pairing the axis
      // that survived with a default for the one that did not would put the
      // pad somewhere the player never chose.
      SharedPreferences.setMockInitialValues({'settings.pad.jump.x': 0.2});
      await progressStore.load();

      expect(progressStore.padSpot(ControlPad.jump), ControlPad.jump.home);
    });

    test('the layout stays on the phone it was made on', () async {
      // Rule 5 of the cloud save: settings do not travel. A layout arranged
      // for a tablet's thumbs is the right answer on the device it was made
      // on and the wrong one everywhere else.
      await progressStore.setPadSpot(ControlPad.jump, const Offset(0.2, 0.3));

      final data = progressStore.toSnapshot();
      expect(data.keys.where((k) => k.contains('pad')), isEmpty);
    });
  });

  group('how big a pad is', () {
    test('a fresh install has all three at standard size', () {
      for (final pad in ControlPad.values) {
        expect(progressStore.padScale(pad), 1);
        expect(progressStore.padDiameter(pad), pad.size);
      }
    });

    test('a resized pad outlives the session that resized it', () async {
      await progressStore.setPadScale(ControlPad.jump, 1.5);
      await progressStore.load();

      expect(progressStore.padScale(ControlPad.jump), 1.5);
      expect(progressStore.padDiameter(ControlPad.jump),
          ControlPad.jump.size * 1.5);
      expect(progressStore.padsMoved, isTrue,
          reason: 'a resize alone is a layout worth offering to put back');
    });

    test('a size beyond the ends is held at the end', () async {
      await progressStore.setPadScale(ControlPad.jump, 9);
      expect(progressStore.padScale(ControlPad.jump), kMaxPadScale);

      await progressStore.setPadScale(ControlPad.jump, 0.01);
      expect(progressStore.padScale(ControlPad.jump), kMinPadScale);
    });

    test('a size saved outside the ends is pulled back on load', () async {
      // An older build, a corrupt write, or a range that has since narrowed.
      // A pad the size of the phone would take every press in the game.
      SharedPreferences.setMockInitialValues({'settings.pad.jump.s': 40.0});
      await progressStore.load();

      expect(progressStore.padScale(ControlPad.jump), kMaxPadScale);
    });

    test('reset puts every size back too', () async {
      await progressStore.setPadScale(ControlPad.jump, 1.5);
      await progressStore.resetPadLayout();
      await progressStore.load();

      for (final pad in ControlPad.values) {
        expect(progressStore.padScale(pad), 1);
      }
      expect(progressStore.padsMoved, isFalse);
    });

    test('a size never travels to another device', () async {
      await progressStore.setPadScale(ControlPad.jump, 1.5);
      expect(progressStore.toSnapshot().keys.where((k) => k.contains('pad')),
          isEmpty);
    });

    test('a grown pad is still kept on screen', () {
      // The clamp takes the diameter, not the pad, so growing one has to pull
      // it in off the edge it was already touching.
      const spot = Offset(0.99, 0.99);
      final small = clampPadSpot(ControlPad.jump.size, spot, kPhone);
      final large =
          clampPadSpot(ControlPad.jump.size * kMaxPadScale, spot, kPhone);

      expect(large.dx, lessThan(small.dx));
      expect(large.dy, lessThan(small.dy));

      final centre = Offset(large.dx * kPhone.width, large.dy * kPhone.height);
      final half = ControlPad.jump.size * kMaxPadScale / 2;
      expect(centre.dx + half,
          lessThanOrEqualTo(kPhone.width - kPadEdgeMargin + 0.01));
      expect(centre.dy + half,
          lessThanOrEqualTo(kPhone.height - kPadBottomMargin + 0.01));
    });
  });

  group('a pad can never be dragged somewhere it cannot be pressed', () {
    test('it stays wholly on screen, on both axes', () {
      for (final pad in ControlPad.values) {
        for (final wild in const [
          Offset(-4, -4),
          Offset(4, 4),
          Offset(0, 1),
          Offset(1, 0),
        ]) {
          final at = clampPadSpot(pad.size, wild, kPhone);
          final centre = Offset(at.dx * kPhone.width, at.dy * kPhone.height);
          final half = pad.size / 2;

          expect(centre.dx - half, greaterThanOrEqualTo(kPadEdgeMargin - 0.01));
          expect(centre.dx + half,
              lessThanOrEqualTo(kPhone.width - kPadEdgeMargin + 0.01));
          expect(centre.dy - half, greaterThanOrEqualTo(kPadTopMargin - 0.01));
        }
      }
    });

    test('it stays clear of the system gesture strips', () {
      // The game runs full bleed, so the left, right and bottom edges all
      // belong to Android's back and home gestures. A pad overlapping one
      // loses presses to the system, sometimes, which is the worst way for an
      // input to fail — this was found by a tap on a pad at the left edge
      // leaving the screen instead of selecting it.
      for (final pad in ControlPad.values) {
        for (final wild in const [
          Offset(0.5, 9),
          Offset(-9, 0.5),
          Offset(9, 0.5),
        ]) {
          final at = clampPadSpot(pad.size, wild, kPhone);
          final centre = Offset(at.dx * kPhone.width, at.dy * kPhone.height);
          final half = pad.size / 2;

          expect(centre.dy + half,
              lessThanOrEqualTo(kPhone.height - kPadBottomMargin + 0.01));
          expect(centre.dx - half,
              greaterThanOrEqualTo(kPadEdgeMargin - 0.01));
          expect(centre.dx + half,
              lessThanOrEqualTo(kPhone.width - kPadEdgeMargin + 0.01));
        }
      }
    });

    test('the gesture margin is wide enough to clear the back strip', () {
      // Android's system gesture inset is 20dp at each side. A margin under
      // that puts a pad back inside the strip and the bug comes straight back.
      expect(kPadEdgeMargin, greaterThanOrEqualTo(20));
    });

    test('the defaults do not overlap, on any phone the game runs on', () {
      // These are the real logical sizes of common handsets held sideways,
      // and the shortest is where three pads have the least room.
      for (final screen in const [
        Size(667, 375),
        Size(732, 360),
        Size(900, 320),
      ]) {
        final centres = {
          for (final pad in ControlPad.values)
            pad: () {
              final at = clampPadSpot(pad.size, pad.home, screen);
              return Offset(at.dx * screen.width, at.dy * screen.height);
            }(),
        };

        for (final a in ControlPad.values) {
          for (final b in ControlPad.values) {
            if (a.index >= b.index) continue;
            expect(
              (centres[a]! - centres[b]!).distance,
              greaterThanOrEqualTo((a.size + b.size) / 2),
              reason: '$a and $b overlap at $screen, so one press would land '
                  'on two pads',
            );
          }
        }
      }
    });
  });

  group('the arrange screen', () {
    Finder padAt(ControlPad pad) => find.byKey(ValueKey(pad));

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = kPhone * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: ControlLayoutScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all three pads and no overflow', (tester) async {
      await open(tester);

      expect(find.byType(PlacedPad), findsNWidgets(3));
      expect(padAt(ControlPad.jump), findsOneWidget);
      expect(padAt(ControlPad.ceiling), findsOneWidget);
      expect(find.text('FLOOR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging a pad moves it and keeps it', (tester) async {
      await open(tester);

      final before = tester.getCenter(padAt(ControlPad.jump));
      await tester.drag(padAt(ControlPad.jump), const Offset(-300, -120));
      await tester.pumpAndSettle();

      expect(tester.getCenter(padAt(ControlPad.jump)).dx,
          lessThan(before.dx - 200));
      expect(progressStore.padSpot(ControlPad.jump),
          isNot(ControlPad.jump.home));

      // And it is on disk, not just in the widget that drew it.
      final moved = progressStore.padSpot(ControlPad.jump);
      await progressStore.load();
      expect(progressStore.padSpot(ControlPad.jump), moved);
    });

    testWidgets('a drag off the edge is caught, not saved', (tester) async {
      await open(tester);

      await tester.drag(padAt(ControlPad.jump), const Offset(900, 900));
      await tester.pumpAndSettle();

      final at = clampPadSpot(
        ControlPad.jump.size,
        progressStore.padSpot(ControlPad.jump),
        kPhone,
      );
      expect(progressStore.padSpot(ControlPad.jump), at,
          reason: 'what is stored is already clamped, so a pad cannot be '
              'parked off screen and then found missing in a level');
    });

    testWidgets('a pad dropped on a button can still be picked up',
        (tester) async {
      // The dead end this screen could have had: park a pad over DONE, and if
      // the button were drawn on top there would be nothing left to grab and
      // no way to undo it.
      await open(tester);

      final done = tester.getCenter(find.text('DONE'));
      final jump = tester.getCenter(padAt(ControlPad.jump));
      await tester.drag(padAt(ControlPad.jump), done - jump);
      await tester.pumpAndSettle();

      final parked = progressStore.padSpot(ControlPad.jump);

      await tester.drag(padAt(ControlPad.jump), const Offset(0, 160));
      await tester.pumpAndSettle();

      expect(progressStore.padSpot(ControlPad.jump), isNot(parked),
          reason: 'the pad has to stay draggable wherever it lands');
    });

    testWidgets('the minus and plus resize the pad last touched',
        (tester) async {
      await open(tester);

      // Jump is selected to begin with, so the stepper has something to act
      // on before anything has been touched.
      final before = tester.getSize(padAt(ControlPad.jump));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(progressStore.padScale(ControlPad.jump), greaterThan(1));
      expect(tester.getSize(padAt(ControlPad.jump)).width,
          greaterThan(before.width));

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();

      expect(progressStore.padScale(ControlPad.jump), lessThan(1));
    });

    testWidgets('tapping a pad points the stepper at it', (tester) async {
      await open(tester);
      // The stepper carries the selected pad's name, so its label appears
      // twice: once under the pad and once in the stepper.
      expect(find.text('JUMP'), findsNWidgets(2));

      await tester.tap(padAt(ControlPad.floor));
      await tester.pumpAndSettle();

      expect(find.text('FLOOR'), findsNWidgets(2));
      expect(find.text('JUMP'), findsOneWidget,
          reason: 'a tap is how a player picks the pad to resize without '
              'having to move it first');

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(progressStore.padScale(ControlPad.floor), greaterThan(1));
    });

    testWidgets('dragging a pad points the stepper at it too', (tester) async {
      await open(tester);
      expect(find.text('JUMP'), findsNWidgets(2));

      await tester.drag(padAt(ControlPad.ceiling), const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(find.text('CEILING'), findsNWidgets(2));
      expect(find.text('JUMP'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(progressStore.padScale(ControlPad.ceiling), greaterThan(1));
      expect(progressStore.padScale(ControlPad.jump), 1,
          reason: 'the pad nobody touched is not the one being resized');
    });

    testWidgets('a big pad cannot swallow a small one', (tester) async {
      // Sizes are the player's to set and nothing stops them stacking a large
      // pad on a small one. Painting the smallest last keeps its circle its
      // own, so it can still be pressed in a level and still be picked up
      // here — a pad that cannot be pressed is a pad that cannot be moved
      // back.
      await progressStore.setPadScale(ControlPad.jump, kMaxPadScale);
      await progressStore.setPadScale(ControlPad.ceiling, kMinPadScale);
      await progressStore.setPadSpot(ControlPad.jump, const Offset(0.5, 0.5));
      await progressStore
          .setPadSpot(ControlPad.ceiling, const Offset(0.5, 0.5));

      await open(tester);

      final moved = progressStore.padSpot(ControlPad.ceiling);
      await tester.drag(padAt(ControlPad.ceiling), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(progressStore.padSpot(ControlPad.ceiling), isNot(moved),
          reason: 'the small pad sits on top and takes the drag');
      expect(progressStore.padSpot(ControlPad.jump), const Offset(0.5, 0.5),
          reason: 'and the large one under it did not move');
    });

    testWidgets('a size at the end of its range stops offering more',
        (tester) async {
      await progressStore.setPadScale(ControlPad.jump, kMaxPadScale);
      await open(tester);

      final plus = tester.widget<InkResponse>(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(InkResponse),
        ),
      );
      expect(plus.onTap, isNull, reason: 'it is as big as it goes');
    });

    testWidgets('reset is offered only once something has moved',
        (tester) async {
      await open(tester);

      Widget resetButton() =>
          tester.widget(find.ancestor(
            of: find.text('RESET'),
            matching: find.byType(InkWell),
          ));

      expect((resetButton() as InkWell).onTap, isNull,
          reason: 'nothing has been moved, so there is nothing to put back');

      await tester.drag(padAt(ControlPad.jump), const Offset(-200, -80));
      await tester.pumpAndSettle();

      expect((resetButton() as InkWell).onTap, isNotNull);

      await tester.tap(find.text('RESET'));
      await tester.pumpAndSettle();

      expect(progressStore.padSpot(ControlPad.jump), ControlPad.jump.home);
    });
  });
}
