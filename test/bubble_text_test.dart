import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/ui/widgets/bubble_text.dart';

/// The heading is drawn twice — a painter lays the keyline down and a [Text]
/// puts the fill on top of it. Two different things measuring the same string
/// is the whole risk here: when they disagree the outline slides out from
/// under the letters and the word comes apart.
void main() {
  const style = TextStyle(
    color: Colors.white,
    fontSize: 32,
    letterSpacing: 2,
    fontWeight: FontWeight.w900,
  );

  /// Pumps the heading inside a column that stretches its children, which is
  /// what the cleared panel does and what broke it: the fill went to the left
  /// edge of the stretched box while the keyline stayed in the middle.
  Future<void> pump(WidgetTester tester, TextAlign align) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BubbleText(
                  text: 'CLEARED',
                  style: style,
                  keyline: 8,
                  textAlign: align,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the fill is told where to sit rather than left to its default',
      (tester) async {
    // The painter follows whatever alignment it is handed, so the only way the
    // two passes can disagree is if the Text is not handed the same one. A
    // Text left on its default aligns to the start, which is how the keyline
    // ended up centred under a heading that had gone to the left edge.
    for (final align in [TextAlign.start, TextAlign.center, TextAlign.end]) {
      await pump(tester, align);
      expect(tester.widget<Text>(find.text('CLEARED')).textAlign, align);
    }
  });

  testWidgets('the heading takes the whole width it is stretched to',
      (tester) async {
    // Which is exactly why the alignment matters. If it sized to its content
    // instead, both passes would share one snug box and could not disagree.
    await pump(tester, TextAlign.center);
    expect(tester.getRect(find.text('CLEARED')).width, greaterThan(400),
        reason: 'a stretched column hands the heading the full width');
  });

  testWidgets('the keyline is set in the same face as the fill',
      (tester) async {
    // Both halves of the heading are drawn from a TextStyle that names no
    // font family: the Text picks the app's up from the theme, and a painter
    // handed the raw style would fall back to the platform default. Set in
    // two different faces the outline no longer fits the letters it is
    // behind, which is the same coming-apart the alignment bug caused.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'LuckiestGuy'),
        home: const Scaffold(
          body: Center(
            child: BubbleText(text: 'CLEARED', style: style, keyline: 8),
          ),
        ),
      ),
    );
    await tester.pump();

    final painter = tester.widget<CustomPaint>(
      find.ancestor(of: find.text('CLEARED'), matching: find.byType(CustomPaint)).first,
    );
    expect(painter.painter.toString(), contains('_KeylinePainter'));
    expect(
      DefaultTextStyle.of(tester.element(find.text('CLEARED'))).style.fontFamily,
      'LuckiestGuy',
      reason: 'the fill inherits the app face, so the keyline must too',
    );
  });

  testWidgets('it renders with and without a gradient', (tester) async {
    for (final gradient in [
      null,
      const [Color(0xFF6FD44A), Color(0xFFFF9838)],
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BubbleText(
                text: 'PITCHPOLE',
                style: style,
                keyline: 9,
                gradient: gradient,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('PITCHPOLE'), findsOneWidget,
          reason: 'one Text either way: the title is how a test finds the '
              'screen and how a screen reader names it');
    }
  });
}
