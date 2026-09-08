import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/scene_theme.dart';
import '../../game/logic/physics.dart';

/// Fills the letterbox with the two colours the scene already ends on.
///
/// The play field is a fixed 560 by 220, which is a wider shape than any phone
/// held sideways, so it is scaled to the screen's width and leaves a band above
/// and below. Those bands are unavoidable — stretching the field would show
/// some players more of the level than others, and the whole pack is tuned on
/// everyone seeing the same distance ahead.
///
/// What is avoidable is them being black, which reads as the game failing to
/// fill the screen. The canvas ends on flat sky along its top edge and flat
/// deep soil along its bottom, so continuing those two colours outwards makes
/// the scene run to both edges instead.
///
/// Which two colours those are depends on where the level is set. It used to
/// be the forest's, always, because there was only the forest; a winter or a
/// night level then ended on its own sky and had the forest's painted next to
/// it, and the seam that CLAUDE.md warns about appeared along the top and
/// bottom of every level past ten.
class Letterbox extends StatelessWidget {
  const Letterbox({super.key, required this.theme});

  /// The level's own place, so the bands continue *this* scene rather than
  /// the one the game happened to start life with.
  final SceneTheme theme;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LetterboxPainter(theme),
        size: Size.infinite,
      );
}

class _LetterboxPainter extends CustomPainter {
  const _LetterboxPainter(this.theme);

  final SceneTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    // The same fit the fixed resolution viewport does, so the seam lands in
    // exactly the same place.
    final scale = min(size.width / kCanvasWidth, size.height / kCanvasHeight);
    final bar = (size.height - kCanvasHeight * scale) / 2;

    // Nothing to fill: the screen is wider than the field, so what is left
    // over is at the sides rather than above and below. No flat colour can
    // stand in for the scene there, since a vertical slice of it runs sky,
    // band, earth. No phone is this shape; a very wide window can be.
    if (bar <= 0) return;

    // A pixel of overlap. The game is drawn on top of this, so the only thing
    // it can cause is the seam being covered rather than a hairline of black
    // showing through it at some fractional scale.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, bar + 1),
      Paint()..color = theme.skyHigh,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - bar - 1, size.width, bar + 1),
      Paint()..color = theme.earthDark,
    );
  }

  @override
  bool shouldRepaint(_LetterboxPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
