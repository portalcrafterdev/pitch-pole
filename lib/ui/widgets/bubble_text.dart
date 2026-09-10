import 'package:flutter/material.dart';

/// A heading with a thick keyline behind it and a soft shadow under that.
///
/// Two passes over one string rather than one widget per letter. Per letter
/// would allow the bounce a storybook logo usually has, but these headings are
/// how tests find a screen and how a screen reader names it, so each stays a
/// single [Text]. The keyline is painted underneath by a [CustomPaint] using
/// the same [TextStyle] — the only way to get a stroke behind a fill without a
/// second Text widget in the tree.
class BubbleText extends StatelessWidget {
  const BubbleText({
    super.key,
    required this.text,
    required this.style,
    required this.keyline,
    this.gradient,
    this.shadow = const Color(0x3D2C7A3A),
    this.textAlign = TextAlign.center,
  });

  final String text;

  /// The fill's style. [BubbleText] paints the keyline from the same one, so
  /// the two passes always land on top of each other.
  final TextStyle style;

  /// How thick the outline is, in logical pixels.
  final double keyline;

  /// Filled with this if given, and with [style]'s colour if not.
  final List<Color>? gradient;

  /// A drop of colour under the keyline, so the heading sits on the sky rather
  /// than floating in it.
  final Color shadow;

  /// Where the text sits when it is given more width than it needs.
  ///
  /// It has to be told, because the fill and the keyline are laid out by two
  /// different things: a [Text], which aligns itself, and a painter, which
  /// does not. Left to their own defaults inside a stretched column the fill
  /// went left and the outline stayed centred, and the heading came apart.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // The painter is given the style the [Text] will actually be drawn in,
    // not the one handed to this widget. A TextStyle here names no font
    // family, so the Text picks the app's up from the theme while a painter
    // handed the raw style falls back to the platform default — and the
    // keyline would be set in a different face from the fill it sits behind.
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final label = Text(text, style: style, textAlign: textAlign);
    final fill = gradient == null
        ? label
        : ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) =>
                LinearGradient(colors: gradient!).createShader(rect),
            child: label,
          );

    return CustomPaint(
      painter: _KeylinePainter(
        text: text,
        style: resolved,
        width: keyline,
        shadow: shadow,
        align: textAlign,
      ),
      // The stroke is centred on the glyph, so half of it falls outside the
      // text's own box. Without room the painter is clipped and the outline
      // stops at the first and last letter.
      child: Padding(
        padding: EdgeInsets.all(keyline / 2),
        child: fill,
      ),
    );
  }
}

class _KeylinePainter extends CustomPainter {
  _KeylinePainter({
    required this.text,
    required this.style,
    required this.width,
    required this.shadow,
    required this.align,
  });

  final String text;
  final TextStyle style;
  final double width;
  final Color shadow;
  final TextAlign align;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // The same rule the Text above it follows, so the two passes land on top
    // of each other however much width the parent hands down.
    final slack = size.width - painter.width;
    final dx = switch (align) {
      TextAlign.left || TextAlign.start => 0.0,
      TextAlign.right || TextAlign.end => slack,
      _ => slack / 2,
    };
    final at = Offset(dx, (size.height - painter.height) / 2);

    // Two passes: the shadow first, recoloured through a save layer so the
    // whole stroke takes one flat tint, then the white keyline over it.
    canvas.saveLayer(Offset.zero & size, Paint());
    painter.paint(canvas, at + Offset(0, width * 0.34));
    canvas.drawColor(shadow, BlendMode.srcIn);
    canvas.restore();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_KeylinePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.width != width ||
      oldDelegate.shadow != shadow ||
      oldDelegate.align != align;
}
