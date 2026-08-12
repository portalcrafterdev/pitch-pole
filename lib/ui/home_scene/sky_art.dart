import 'dart:math' as math;
import 'dart:ui';

import '../menu_palette.dart';

/// Every brush stroke in the menu scene, as plain functions of time.
///
/// Nothing here holds state. Each function takes the seconds elapsed and
/// draws the scene as it looks at that instant, which is the same trick the
/// run itself uses: the game derives a hopper's phase from x rather than from
/// a wall clock so a respawn puts it back exactly where it was. Here it buys
/// something else. The Flame components own the clock and the still fallback
/// passes zero, so a menu that has been told to hold still is provably the
/// first frame of the moving one rather than a second drawing of it.
///
/// Colours come from [MenuPalette] only. None of this is ever on screen
/// during a run, so none of it can cost the player a read.

/// The order everything is drawn in, from the sky down to the sparkles on top.
void paintScene(Canvas canvas, Size size, double t) {
  paintSky(canvas, size, t);
  paintSun(canvas, size, t);
  paintBirds(canvas, size, t);
  paintClouds(canvas, size, t);
  paintHills(canvas, size, t);
  paintCoins(canvas, size, t);
  paintMascot(canvas, size, t);
  paintSparks(canvas, size, t);
}

double _wrap01(double v) => v - v.floorToDouble();

/// The gradient behind everything. Ends warm rather than blue, so the horizon
/// reads as afternoon light instead of as more sky.
void paintSky(Canvas canvas, Size size, double t) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.linear(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        const [
          MenuPalette.skyTop,
          MenuPalette.skyMid,
          MenuPalette.skyLow,
          MenuPalette.horizon,
        ],
        const [0.0, 0.42, 0.72, 1.0],
      ),
  );
}

/// Top left, opposite the settings gear and well clear of the centre column
/// the menu itself lives in.
void paintSun(Canvas canvas, Size size, double t) {
  final centre = Offset(size.width * 0.11, size.height * 0.17);
  final r = math.min(size.height * 0.10, 30.0);

  // A radial falloff rather than a flat disc. A single translucent circle has
  // a hard edge, and a hard edged glow reads as a plate behind the sun.
  canvas.drawCircle(
    centre,
    r * 2.4,
    Paint()
      ..shader = Gradient.radial(centre, r * 2.4, [
        MenuPalette.sunGlow.withValues(alpha: 0.50),
        MenuPalette.sunGlow.withValues(alpha: 0.0),
      ], [
        0.35,
        1.0,
      ]),
  );

  // One turn every forty seconds. Fast enough to notice if you watch for it,
  // slow enough that it never pulls an eye off the PLAY button.
  final spin = t * math.pi * 2 / 40;
  final ray = Paint()
    ..color = MenuPalette.sunGlow.withValues(alpha: 0.75)
    ..strokeWidth = r * 0.16
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 12; i++) {
    final a = spin + i * math.pi / 6;
    final reach = 1 + 0.10 * math.sin(t * 2.2 + i * 0.9);
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(centre + dir * (r * 1.30), centre + dir * (r * 1.74 * reach),
        ray);
  }

  canvas.drawCircle(centre, r, Paint()..color = MenuPalette.sun);
  canvas.drawCircle(
    centre - Offset(r * 0.28, r * 0.30),
    r * 0.42,
    Paint()..color = MenuPalette.sunGlow.withValues(alpha: 0.55),
  );
}

class _Cloud {
  const _Cloud(this.y, this.scale, this.speed, this.offset);

  /// Fraction of the height, a multiplier on the cloud's own size, pixels a
  /// second, and where it starts.
  final double y;
  final double scale;
  final double speed;
  final double offset;
}

/// Small clouds move faster than big ones, which is the cheapest depth cue
/// there is, and no two share a speed so the sky never visibly loops.
const List<_Cloud> _clouds = [
  _Cloud(0.13, 1.00, 9, 0.05),
  _Cloud(0.26, 0.66, 15, 0.42),
  _Cloud(0.08, 0.78, 12, 0.71),
  _Cloud(0.34, 0.52, 20, 0.88),
];

void paintClouds(Canvas canvas, Size size, double t) {
  // A margin either side wide enough that a cloud is never seen to pop.
  final span = size.width + 220;
  final scale = math.min(size.height / 320, 1.25);

  for (final c in _clouds) {
    final x = _wrap01(c.offset + t * c.speed / span) * span - 110;
    _cloud(canvas, Offset(x, size.height * c.y), c.scale * scale);
  }
}

void _cloud(Canvas canvas, Offset o, double s) {
  final body = Paint()..color = MenuPalette.cloud.withValues(alpha: 0.94);
  final under = Paint()..color = const Color(0xFFD5EDFB).withValues(alpha: 0.9);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx - 26 * s, o.dy + 1 * s, 56 * s, 15 * s),
      Radius.circular(8 * s),
    ),
    under,
  );
  canvas.drawCircle(o + Offset(-19 * s, 2 * s), 13 * s, body);
  canvas.drawCircle(o + Offset(1 * s, -6 * s), 19 * s, body);
  canvas.drawCircle(o + Offset(21 * s, 1 * s), 14 * s, body);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx - 22 * s, o.dy - 2 * s, 48 * s, 14 * s),
      Radius.circular(7 * s),
    ),
    body,
  );
}

/// Two birds crossing high up. They are the only thing that leaves the screen
/// and comes back, which is what keeps an otherwise still upper half alive.
void paintBirds(Canvas canvas, Size size, double t) {
  final stroke = Paint()
    ..color = MenuPalette.ink.withValues(alpha: 0.28)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;

  final span = size.width + 120;
  for (var i = 0; i < 2; i++) {
    final p = _wrap01(i * 0.45 + t * 26 / span);
    final x = p * span - 60;
    final y = size.height * (0.20 + i * 0.07) + math.sin(t * 0.9 + i * 2) * 6;
    // The flap comes off the same clock as the travel, so the wings beat as it
    // crosses rather than independently of it.
    final flap = 3 + 2.4 * math.sin(t * 9 + i * 2);
    const w = 6.0;

    canvas.drawPath(
      Path()
        ..moveTo(x - w * 2, y)
        ..quadraticBezierTo(x - w, y - flap, x, y)
        ..quadraticBezierTo(x + w, y - flap, x + w * 2, y),
      stroke,
    );
  }
}

/// Two rolling hills and a grass strip, so the buttons have a floor to stand
/// on rather than hanging in mid air.
void paintHills(Canvas canvas, Size size, double t) {
  final w = size.width;
  final h = size.height;

  void hill(double top, Color colour, double lift) {
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, top)
        ..quadraticBezierTo(w * 0.18, top - lift, w * 0.38, top + lift * 0.35)
        ..quadraticBezierTo(w * 0.58, top + lift * 1.1, w * 0.74, top - lift * 0.5)
        ..quadraticBezierTo(w * 0.90, top - lift * 1.5, w, top - lift * 0.2)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = colour,
    );
  }

  hill(h * 0.80, MenuPalette.hillFar, h * 0.05);
  hill(h * 0.88, MenuPalette.hillNear, h * 0.04);

  final capY = h * 0.945;
  canvas.drawRect(
    Rect.fromLTWH(0, capY, w, h - capY),
    Paint()..color = MenuPalette.grass,
  );

  // Tufts rather than evenly spaced ticks. Three blades of different heights
  // leaning off one root, because a row of identical marks at an identical
  // spacing stops reading as grass and starts reading as a ruler.
  final blade = Paint()
    ..color = MenuPalette.grassDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  const tufts = 22;
  for (var i = 0; i < tufts; i++) {
    final x = (i + 0.5) * w / tufts;
    final sway = math.sin(t * 1.6 + i * 0.35) * 2.4;
    for (var b = -1; b <= 1; b++) {
      final lean = b * 3.0;
      final tall = 7.0 + ((i * 7 + b * 5) % 5);
      canvas.drawPath(
        Path()
          ..moveTo(x + lean * 0.6, capY + 3)
          ..quadraticBezierTo(
            x + lean + sway * 0.5,
            capY - tall * 0.6,
            x + lean * 1.6 + sway,
            capY - tall,
          ),
        blade,
      );
    }
  }

  _paintFlowers(canvas, w, capY, t);
}

/// Flowers along the grass line, on their own slow sway.
void _paintFlowers(Canvas canvas, double w, double capY, double t) {
  const petals = [MenuPalette.cloud, MenuPalette.pink, MenuPalette.gold];
  for (var i = 0; i < 7; i++) {
    // Irregular spacing on purpose: an evenly spaced row of flowers is a
    // fence.
    final x = w * (0.06 + i * 0.135 + (i.isEven ? 0.03 : 0));
    if (x > w) break;
    final sway = math.sin(t * 1.2 + i * 1.7) * 2.0;
    final stem = 12.0 + (i % 3) * 3;
    final head = Offset(x + sway, capY - stem);

    canvas.drawPath(
      Path()
        ..moveTo(x, capY + 2)
        ..quadraticBezierTo(x + sway * 0.4, capY - stem * 0.6, head.dx, head.dy),
      Paint()
        ..color = MenuPalette.grassDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    final colour = petals[i % petals.length];
    for (var p = 0; p < 5; p++) {
      final a = p * math.pi * 2 / 5 + i;
      canvas.drawCircle(
        head + Offset(math.cos(a), math.sin(a)) * 3.0,
        2.6,
        Paint()..color = colour,
      );
    }
    canvas.drawCircle(head, 1.9, Paint()..color = MenuPalette.goldDark);
  }
}

/// A little group of coins on the right, bobbing.
///
/// The right third of a landscape screen is dead space once the menu column is
/// centred, and that empty third is a good part of why the page read as severe.
void paintCoins(Canvas canvas, Size size, double t) {
  final x = size.width * 0.86;
  // Hovering just over the grass rather than out in open sky, so they read as
  // coins waiting to be run through instead of as three dots.
  final ground = size.height * 0.925;
  final baseY = ground - 34;
  const r = 12.0;

  for (var i = 0; i < 3; i++) {
    final bob = math.sin(t * 1.8 + i * 2.1) * 5;
    final centre = Offset(x + (i - 1) * 30.0, baseY + bob + (i.isEven ? 6 : 0));

    // The shadow stays on the ground and tightens as the coin rises, which is
    // what sells the bob as height rather than as the whole group sliding.
    final lift = (ground - centre.dy) / 60;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx, ground),
        width: r * (2.0 - lift * 0.7),
        height: r * (0.55 - lift * 0.2),
      ),
      Paint()..color = MenuPalette.ink.withValues(alpha: 0.13),
    );
    canvas.drawCircle(centre, r, Paint()..color = MenuPalette.goldDark);
    canvas.drawCircle(centre, r * 0.82, Paint()..color = MenuPalette.gold);
    canvas.drawCircle(
      centre - const Offset(r * 0.28, r * 0.30),
      r * 0.26,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7),
    );
  }
}

class _Spark {
  const _Spark(this.x, this.phase, this.speed, this.size);

  final double x;
  final double phase;
  final double speed;
  final double size;
}

/// Seeded once at load rather than per frame, so a sparkle keeps its own lane
/// instead of being somewhere new every time the scene repaints.
final List<_Spark> _sparks = List<_Spark>.generate(16, (i) {
  final r = math.Random(700 + i);
  return _Spark(
    r.nextDouble(),
    r.nextDouble(),
    0.030 + r.nextDouble() * 0.048,
    1.5 + r.nextDouble() * 2.6,
  );
});

/// Sparkles drifting up the whole page, swaying as they climb.
void paintSparks(Canvas canvas, Size size, double t) {
  for (final s in _sparks) {
    final p = _wrap01(s.phase + t * s.speed);
    final y = (1 - p) * size.height;
    final x = s.x * size.width + math.sin(p * 6.3 + s.phase * 6.3) * 14;
    // Fades in low and out high, so none of them ever blinks out of existence
    // in the middle of the screen.
    final fade = math.sin(p * math.pi).clamp(0.0, 1.0);
    _spark(canvas, Offset(x, y), s.size, fade * 0.75);
  }
}

void _spark(Canvas canvas, Offset o, double r, double alpha) {
  canvas.drawPath(
    Path()
      ..moveTo(o.dx, o.dy - r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r * 2)
      ..close(),
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
  );
}

/// The runner, idling on the grass at the left.
///
/// It is the same character the player controls, drawn the same way: legs that
/// cycle, ears that lie back, pupils that lean into the run. On the menu it is
/// standing still rather than running, so the legs keep a slow march and the
/// bounce is a hop rather than a stride.
void paintMascot(Canvas canvas, Size size, double t) {
  final scale = math.min(size.height / 320, 1.3);
  final feet = Offset(size.width * 0.13, size.height * 0.945);
  final s = 52.0 * scale;

  // One hop a second and a bit, with the squash on the landing rather than
  // spread evenly through it. A bounce with no squash reads as a float.
  final cycle = _wrap01(t / 1.4);
  final hop = math.sin(cycle * math.pi).abs();
  final lift = hop * s * 0.42;
  final squash = 1 - 0.16 * math.pow(1 - hop, 6).toDouble();
  final stretch = 1 / squash;

  canvas.drawOval(
    Rect.fromCenter(
      center: feet,
      width: s * (1.5 - hop * 0.4),
      height: s * (0.30 - hop * 0.08),
    ),
    Paint()..color = MenuPalette.ink.withValues(alpha: 0.16),
  );

  canvas.save();
  canvas.translate(feet.dx, feet.dy - lift);
  canvas.scale(stretch, squash);

  final body = Paint()..color = const Color(0xFF3E8EF7);
  final bodyDark = Paint()..color = const Color(0xFF2C6FD1);

  // Legs, marching out of the same clock as the hop. Long enough to read as
  // legs: the first pass drew them a fifth of the body tall, which at this
  // size was a point rather than a limb.
  final swing = math.sin(t * 4.2) * s * 0.20;
  final leg = Paint()
    ..color = const Color(0xFF2C6FD1)
    ..strokeWidth = s * 0.17
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
      Offset(-s * 0.20, -s * 0.34), Offset(-s * 0.24 + swing, -s * 0.02), leg);
  canvas.drawLine(
      Offset(s * 0.20, -s * 0.34), Offset(s * 0.24 - swing, -s * 0.02), leg);

  // Ears first, so the head overlaps their roots. Short and rounded rather
  // than long and thin, which was reading as antennae on a bug.
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * s * 0.30, -s * 1.36);
    canvas.rotate(side * 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.24, height: s * 0.42),
      bodyDark,
    );
    canvas.restore();
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -s * 0.72), width: s, height: s * 1.14),
      Radius.circular(s * 0.34),
    ),
    body,
  );

  // A paler belly, so the body is not one flat colour.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.35),
        width: s * 0.62,
        height: s * 0.38,
      ),
      Radius.circular(s * 0.18),
    ),
    Paint()..color = const Color(0xFF6BAEFB),
  );

  // Cheeks. Nothing in the run has these; they are here because a face with
  // colour in it reads as friendly and this one is meant to.
  final cheek = Paint()..color = MenuPalette.pink.withValues(alpha: 0.55);
  canvas.drawCircle(Offset(-s * 0.34, -s * 0.74), s * 0.10, cheek);
  canvas.drawCircle(Offset(s * 0.34, -s * 0.74), s * 0.10, cheek);

  // A blink every three and a bit seconds, held for a tenth of one.
  final blink = _wrap01(t / 3.4) > 0.97;
  final eyeH = blink ? s * 0.03 : s * 0.17;
  for (final side in [-1.0, 1.0]) {
    final centre = Offset(side * s * 0.19, -s * 0.94);
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: s * 0.24, height: eyeH * 1.5),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    if (!blink) {
      canvas.drawCircle(
        centre + Offset(s * 0.03, math.sin(t * 1.1) * s * 0.02),
        s * 0.07,
        Paint()..color = const Color(0xFF12161F),
      );
    }
  }

  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(0, -s * 0.62),
      width: s * 0.34,
      height: s * 0.26,
    ),
    0.15,
    math.pi - 0.3,
    false,
    Paint()
      ..color = const Color(0xFF12161F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round,
  );

  canvas.restore();
}
