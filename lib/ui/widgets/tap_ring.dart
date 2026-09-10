import 'package:flutter/material.dart';

/// How long a ring takes to open and go quiet.
const Duration kTapRingDuration = Duration(milliseconds: 260);

/// A ring opening out of the finger and fading as it goes.
///
/// One definition, used by the halves in a run and by every pressable thing in
/// the menus. Two copies of a shape this specific would drift apart the first
/// time one of them was tuned.
///
/// Painted rather than a Material ripple because a ripple on a white card
/// under a bright sky is close to invisible, and because it has to work the
/// same on a green tile, a faded locked one and a forest.
class TapRingPainter extends CustomPainter {
  const TapRingPainter({
    required this.at,
    required this.progress,
    required this.colour,
    this.radius = 46,
  });

  /// Where the finger went down, in the painted box's own coordinates.
  final Offset? at;

  /// 0 to 1. Nothing is drawn at either end.
  final double progress;

  final Color colour;

  /// How far the ring opens past its starting size.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = at;
    // Nothing before the first tap, and nothing once the ring has closed —
    // which is what keeps this free for the rest of the run.
    if (centre == null || progress == 0 || progress >= 1) return;

    // Fast out, slow to fade: the ring is nearly full size in the first third
    // and spends the rest of its life going quiet, so a tap reads as a hit
    // rather than as something expanding at you.
    final eased = 1 - (1 - progress) * (1 - progress) * (1 - progress);
    final open = radius * 0.26 + radius * eased;
    final fade = 1 - progress;

    canvas.drawCircle(
      centre,
      open,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade + 0.6
        ..color = colour.withValues(alpha: 0.5 * fade),
    );
    canvas.drawCircle(
      centre,
      open * 0.72,
      Paint()..color = colour.withValues(alpha: 0.12 * fade * fade),
    );
  }

  @override
  bool shouldRepaint(TapRingPainter old) =>
      old.progress != progress ||
      old.at != at ||
      old.colour != colour ||
      old.radius != radius;
}
