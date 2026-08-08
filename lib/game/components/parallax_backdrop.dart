import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// The forest behind the run: two receding tree lines, light coming down
/// through the leaves, low mist and a few fireflies.
///
/// Everything here is a near black green. The design rule still holds: the
/// cast and the finish line must be the only high contrast things on screen,
/// so none of this is allowed to compete with an obstacle.
///
/// Drawn in viewport space and scrolled by hand, so it costs the same however
/// long the level is. Every shape is rolled once from a fixed seed, so it is
/// the same forest on every run and on every device.
class ParallaxBackdrop extends PositionComponent {
  ParallaxBackdrop() : super(priority: -20);

  /// World x at the left edge of the view. The game sets this every frame.
  double scrollX = 0;

  /// Only drives the drifting: mist and fireflies. Nothing that matters.
  double _t = 0;

  static const double _farFactor = 0.10;
  static const double _midFactor = 0.26;
  static const double _mistFactor = 0.55;

  /// Clouds are the furthest thing there is, so they barely move with the run.
  static const double _cloudFactor = 0.03;

  /// Each layer repeats over its own span, which must be at least a screen
  /// wide for the tiling below to cover the view.
  static const double _farSpan = 1400;
  static const double _midSpan = 1100;
  static const double _mistSpan = 900;

  late final List<_Tree> _far = _grow(
    seed: 3,
    count: 16,
    span: _farSpan,
    minHeight: 34,
    maxHeight: 62,
    minWidth: 26,
    maxWidth: 52,
  );

  late final List<_Tree> _mid = _grow(
    seed: 17,
    count: 9,
    span: _midSpan,
    minHeight: 66,
    maxHeight: 104,
    minWidth: 14,
    maxWidth: 26,
  );

  late final List<_Drift> _mist = _drifts(seed: 29, count: 7, span: _mistSpan);
  late final List<_Firefly> _fireflies = _swarm(seed: 41, count: 11);

  /// Deer stand in the far treeline and scroll with it, so they belong to the
  /// forest rather than to the view.
  late final List<_Deer> _deer = _herd(seed: 53, count: 5, span: _farSpan);

  /// Birds and moths live in the view, like the fireflies, so an empty stretch
  /// of track still has something moving in it.
  late final List<_Bird> _birds = _flock(seed: 67, count: 6);
  late final List<_Cloud> _clouds = _sky(seed: 83, count: 6);
  late final List<_Moth> _moths = _mothsIn(seed: 71, count: 7);

  final Paint _wash = Paint();
  final Paint _farPaint = Paint()..color = Palette.canopyFar;
  final Paint _midPaint = Paint()..color = Palette.canopyMid;
  final Paint _trunkPaint = Paint()..color = Palette.trunk;
  final Paint _shaftPaint = Paint();
  final Paint _mistPaint = Paint();
  final Paint _fireflyPaint = Paint();
  final Paint _wildlifePaint = Paint();
  final Paint _cloudPaint = Paint();
  final Paint _mothPaint = Paint();
  final Paint _antlerPaint = Paint()
    ..color = Palette.wildlife
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  final Paint _birdPaint = Paint()
    ..color = Palette.wildlife
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static List<_Tree> _grow({
    required int seed,
    required int count,
    required double span,
    required double minHeight,
    required double maxHeight,
    required double minWidth,
    required double maxWidth,
  }) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Tree(
        // Evenly spaced then jittered, so the line never looks like a fence
        // and never leaves a hole either.
        x: (i + random.nextDouble() * 0.8 - 0.4) * (span / count),
        width: minWidth + random.nextDouble() * (maxWidth - minWidth),
        height: minHeight + random.nextDouble() * (maxHeight - minHeight),
        conifer: random.nextBool(),
      );
    });
  }

  static List<_Drift> _drifts({
    required int seed,
    required int count,
    required double span,
  }) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Drift(
        x: (i + random.nextDouble() * 0.6) * (span / count),
        y: kFloorSurfaceY - 6 - random.nextDouble() * 34,
        width: 70 + random.nextDouble() * 110,
        height: 4 + random.nextDouble() * 7,
        rate: 0.15 + random.nextDouble() * 0.25,
      );
    });
  }

  static List<_Deer> _herd({
    required int seed,
    required int count,
    required double span,
  }) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Deer(
        x: (i + random.nextDouble() * 0.7) * (span / count),
        height: 15 + random.nextDouble() * 6,
        // Every deer grazes on its own slow clock, so the herd is never in
        // step with itself.
        rate: 0.16 + random.nextDouble() * 0.2,
        phase: random.nextDouble() * 2 * pi,
        facing: random.nextBool() ? 1 : -1,
        antlered: random.nextDouble() < 0.4,
      );
    });
  }

  static List<_Cloud> _sky({required int seed, required int count}) {
    final random = Random(seed);
    const ceiling = kCeilingSurfaceY - kBlockThickness;
    return List.generate(count, (i) {
      final height = 5 + random.nextDouble() * 5;
      return _Cloud(
        x: (i + random.nextDouble() * 0.7) * ((kCanvasWidth + 120) / count),
        // Kept clear of the canopy edge so a cloud never looks like it is
        // sitting on the ceiling the character runs along.
        y: 5 + random.nextDouble() * (ceiling - height - 9),
        width: 40 + random.nextDouble() * 54,
        height: height,
        speed: 1.4 + random.nextDouble() * 2.2,
        alpha: 0.55 + random.nextDouble() * 0.35,
      );
    });
  }

  static List<_Bird> _flock({required int seed, required int count}) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Bird(
        x: random.nextDouble() * kCanvasWidth,
        y: kCeilingSurfaceY + 6 + random.nextDouble() * 34,
        size: 2.4 + random.nextDouble() * 1.8,
        // Slow, because they are meant to be far away.
        speed: 5 + random.nextDouble() * 7,
        rate: 3.5 + random.nextDouble() * 2.5,
        phase: random.nextDouble() * 2 * pi,
      );
    });
  }

  static List<_Moth> _mothsIn({required int seed, required int count}) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Moth(
        x: random.nextDouble() * kCanvasWidth,
        y: kCeilingSurfaceY + 14 + random.nextDouble() * (kBandHeight - 40),
        size: 1.2 + random.nextDouble() * 0.9,
        rate: 0.7 + random.nextDouble() * 0.8,
        phase: random.nextDouble() * 2 * pi,
        drift: 14 + random.nextDouble() * 20,
      );
    });
  }

  static List<_Firefly> _swarm({required int seed, required int count}) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Firefly(
        x: random.nextDouble() * kCanvasWidth,
        y: kCeilingSurfaceY + 12 + random.nextDouble() * (kBandHeight - 24),
        radius: 0.9 + random.nextDouble() * 0.9,
        rate: 0.5 + random.nextDouble() * 0.9,
        phase: random.nextDouble() * 2 * pi,
        drift: 8 + random.nextDouble() * 16,
      );
    });
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    _renderSky(canvas);

    // Light falls from the canopy, so the band is brighter at the top. It is
    // kept to a mid tone on purpose: the blade is near white steel and would
    // disappear against a pale one.
    _wash.shader = Gradient.linear(
      const Offset(0, kCeilingSurfaceY),
      const Offset(0, kFloorSurfaceY),
      const [Palette.bandHigh, Palette.bandLow],
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kCeilingSurfaceY, kCanvasWidth, kBandHeight),
      _wash,
    );

    _renderTrees(canvas, _far, _farFactor, _farSpan, _farPaint, _farPaint);
    _renderBirds(canvas);
    _renderDeer(canvas);
    _renderShafts(canvas);
    _renderTrees(canvas, _mid, _midFactor, _midSpan, _midPaint, _trunkPaint);
    _renderMist(canvas);
    _renderMoths(canvas);
    _renderFireflies(canvas);
  }

  /// Open sky above the canopy, with clouds drifting across it.
  ///
  /// This is the only part of the view that is genuinely bright. It sits
  /// entirely outside the play band, so nothing here can ever be mistaken for
  /// something that kills.
  void _renderSky(Canvas canvas) {
    const skyBottom = kCeilingSurfaceY - kBlockThickness;

    _wash.shader = Gradient.linear(
      const Offset(0, 0),
      const Offset(0, skyBottom),
      const [Palette.skyHigh, Palette.skyLow],
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kCanvasWidth, skyBottom),
      _wash,
    );
    _wash.shader = null;

    // Clouds drift on their own, slowly, and wrap well outside the view.
    for (final cloud in _clouds) {
      final span = kCanvasWidth + 120;
      var x = (cloud.x - scrollX * _cloudFactor - _t * cloud.speed) % span;
      if (x < 0) x += span;
      x -= 60;

      _cloudPaint.color = Palette.cloud.withValues(alpha: cloud.alpha);
      // Three overlapping lobes, so the outline is not an oval.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, cloud.y),
          width: cloud.width,
          height: cloud.height,
        ),
        _cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - cloud.width * 0.26, cloud.y + cloud.height * 0.18),
          width: cloud.width * 0.62,
          height: cloud.height * 0.74,
        ),
        _cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + cloud.width * 0.28, cloud.y + cloud.height * 0.14),
          width: cloud.width * 0.58,
          height: cloud.height * 0.70,
        ),
        _cloudPaint,
      );
    }
  }

  /// Deer standing in the far treeline, grazing.
  ///
  /// They scroll with the far trees, so they read as part of the forest rather
  /// than as something coming towards the player. Drawn between the far and
  /// mid tree lines so the nearer trees pass in front of them.
  void _renderDeer(Canvas canvas) {
    final offset = (scrollX * _farFactor) % _farSpan;
    _wildlifePaint.color = Palette.wildlife;
    for (final deer in _deer) {
      final x = deer.x - offset;
      _drawDeer(canvas, x, deer);
      _drawDeer(canvas, x + _farSpan, deer);
    }
  }

  void _drawDeer(Canvas canvas, double x, _Deer deer) {
    if (x + 20 < 0 || x - 20 > kCanvasWidth) return;

    final height = deer.height;
    final width = height * 1.15;
    final feet = kFloorSurfaceY;
    final backY = feet - height * 0.62;
    final side = deer.facing.toDouble();

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - width / 2, backY, width, height * 0.34),
        Radius.circular(height * 0.15),
      ),
      _wildlifePaint,
    );

    // Legs, two visible pairs.
    final legWidth = max(0.9, height * 0.075);
    for (final at in [-0.34, -0.16, 0.18, 0.36]) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + width * at - legWidth / 2,
          backY + height * 0.30,
          legWidth,
          height * 0.34,
        ),
        _wildlifePaint,
      );
    }

    // The head dips to graze and lifts again. This is the only thing in the
    // background that moves on its own, so it is kept slow.
    final graze = (0.5 + 0.5 * sin(_t * deer.rate + deer.phase));
    final neckTop = backY - height * 0.30 + graze * height * 0.46;
    final neckX = x + side * width * 0.42;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          neckX - legWidth,
          neckTop,
          legWidth * 2,
          backY - neckTop + height * 0.12,
        ),
        Radius.circular(legWidth),
      ),
      _wildlifePaint,
    );

    // Muzzle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          neckX - (side > 0 ? legWidth : height * 0.26 - legWidth),
          neckTop - height * 0.06,
          height * 0.26,
          height * 0.15,
        ),
        Radius.circular(height * 0.06),
      ),
      _wildlifePaint,
    );

    if (!deer.antlered) return;
    for (final spread in [0.10, 0.20]) {
      canvas.drawLine(
        Offset(neckX, neckTop - height * 0.04),
        Offset(
          neckX - side * height * spread,
          neckTop - height * (0.16 + spread),
        ),
        _antlerPaint,
      );
    }
  }

  /// Birds crossing behind the trees. They live in the view and wrap round, so
  /// there is always one somewhere without ever needing more than a handful.
  void _renderBirds(Canvas canvas) {
    _wildlifePaint.color = Palette.wildlife;
    for (final bird in _birds) {
      // Drifting leftwards, wrapped well outside the view so one never pops
      // into existence in front of the player.
      final span = kCanvasWidth + 40;
      var x = (bird.x - _t * bird.speed) % span;
      if (x < 0) x += span;
      x -= 20;

      final flap = sin(_t * bird.rate + bird.phase);
      final lift = bird.size * 0.55 * flap;

      // A shallow V. At this size that is all a bird needs to be.
      canvas.drawPath(
        Path()
          ..moveTo(x - bird.size, bird.y - lift)
          ..lineTo(x, bird.y)
          ..lineTo(x + bird.size, bird.y - lift),
        _birdPaint,
      );
    }
  }

  /// Moths in the light. Paler than a firefly and never pulsing, so the two
  /// read as different animals rather than as one drawn two ways.
  void _renderMoths(Canvas canvas) {
    for (final moth in _moths) {
      final x = moth.x + sin(_t * moth.rate + moth.phase) * moth.drift;
      final y = moth.y +
          sin(_t * moth.rate * 1.7 + moth.phase * 1.3) * moth.drift * 0.35;
      // Flutter comes from the width, not from the brightness.
      final open = 0.55 + 0.45 * sin(_t * 9 + moth.phase).abs();
      _mothPaint.color = Palette.moth.withValues(alpha: 0.11);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: moth.size * 2.4 * open,
          height: moth.size * 1.5,
        ),
        _mothPaint,
      );
    }
  }

  /// Draws each tree twice, a span apart. The span is wider than the view, so
  /// those two placements always cover it however far the level has scrolled.
  void _renderTrees(
    Canvas canvas,
    List<_Tree> trees,
    double factor,
    double span,
    Paint canopy,
    Paint trunk,
  ) {
    final offset = (scrollX * factor) % span;
    for (final tree in trees) {
      final x = tree.x - offset;
      _drawTree(canvas, x, tree, canopy, trunk);
      _drawTree(canvas, x + span, tree, canopy, trunk);
    }
  }

  void _drawTree(
    Canvas canvas,
    double x,
    _Tree tree,
    Paint canopy,
    Paint trunk,
  ) {
    if (x + tree.width < 0 || x - tree.width > kCanvasWidth) return;

    final top = kFloorSurfaceY - tree.height;
    final trunkWidth = tree.width * 0.16;

    canvas.drawRect(
      Rect.fromLTWH(
        x - trunkWidth / 2,
        top + tree.height * 0.35,
        trunkWidth,
        tree.height * 0.65,
      ),
      trunk,
    );

    if (tree.conifer) {
      // Three stacked skirts, narrowing towards the top.
      for (var i = 0; i < 3; i++) {
        final skirtTop = top + tree.height * 0.30 * i;
        final halfWidth = tree.width / 2 * (1 - i / 3 * 0.45);
        canvas.drawPath(
          Path()
            ..moveTo(x, skirtTop)
            ..lineTo(x + halfWidth, skirtTop + tree.height * 0.38)
            ..lineTo(x - halfWidth, skirtTop + tree.height * 0.38)
            ..close(),
          canopy,
        );
      }
    } else {
      // A broadleaf: three overlapping blobs, so the outline is not a circle.
      final crown = top + tree.height * 0.28;
      canvas.drawCircle(Offset(x, crown), tree.width * 0.34, canopy);
      canvas.drawCircle(
        Offset(x - tree.width * 0.26, crown + tree.width * 0.14),
        tree.width * 0.27,
        canopy,
      );
      canvas.drawCircle(
        Offset(x + tree.width * 0.26, crown + tree.width * 0.12),
        tree.width * 0.29,
        canopy,
      );
    }
  }

  /// Light coming down through the leaves. Fixed to the view rather than to
  /// the world, so it reads as the sun rather than as scenery going past.
  void _renderShafts(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final x = 90.0 + i * 190;
      _shaftPaint.color = Palette.shaft.withValues(alpha: 0.030 - i * 0.006);
      canvas.drawPath(
        Path()
          ..moveTo(x, kCeilingSurfaceY)
          ..lineTo(x + 26, kCeilingSurfaceY)
          ..lineTo(x + 74, kFloorSurfaceY)
          ..lineTo(x + 30, kFloorSurfaceY)
          ..close(),
        _shaftPaint,
      );
    }
  }

  void _renderMist(Canvas canvas) {
    final offset = (scrollX * _mistFactor) % _mistSpan;
    _mistPaint.color = Palette.mist.withValues(alpha: 0.05);
    for (final drift in _mist) {
      final wander = sin(_t * drift.rate + drift.x) * 6;
      final x = drift.x - offset + wander;
      for (final placed in [x, x + _mistSpan]) {
        if (placed + drift.width < 0 || placed > kCanvasWidth) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(placed, drift.y, drift.width, drift.height),
            Radius.circular(drift.height / 2),
          ),
          _mistPaint,
        );
      }
    }
  }

  /// Fireflies hang in the view rather than in the world, so a stretch with
  /// nothing in it still has something moving in it.
  void _renderFireflies(Canvas canvas) {
    for (final fly in _fireflies) {
      final pulse = 0.5 + 0.5 * sin(_t * fly.rate * 2 + fly.phase);
      final x = fly.x + sin(_t * fly.rate * 0.7 + fly.phase) * fly.drift;
      final y = fly.y + cos(_t * fly.rate * 0.5 + fly.phase) * fly.drift * 0.4;
      _fireflyPaint.color =
          Palette.firefly.withValues(alpha: 0.10 + 0.28 * pulse);
      canvas.drawCircle(Offset(x, y), fly.radius, _fireflyPaint);
    }
  }
}

class _Tree {
  const _Tree({
    required this.x,
    required this.width,
    required this.height,
    required this.conifer,
  });

  final double x;
  final double width;
  final double height;
  final bool conifer;
}

class _Drift {
  const _Drift({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rate,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double rate;
}

class _Deer {
  const _Deer({
    required this.x,
    required this.height,
    required this.rate,
    required this.phase,
    required this.facing,
    required this.antlered,
  });

  final double x;
  final double height;
  final double rate;
  final double phase;

  /// 1 faces the way the character runs, -1 faces back down the track.
  final int facing;

  final bool antlered;
}

class _Cloud {
  const _Cloud({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.alpha,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double speed;
  final double alpha;
}

class _Bird {
  const _Bird({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rate,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double rate;
  final double phase;
}

class _Moth {
  const _Moth({
    required this.x,
    required this.y,
    required this.size,
    required this.rate,
    required this.phase,
    required this.drift,
  });

  final double x;
  final double y;
  final double size;
  final double rate;
  final double phase;
  final double drift;
}

class _Firefly {
  const _Firefly({
    required this.x,
    required this.y,
    required this.radius,
    required this.rate,
    required this.phase,
    required this.drift,
  });

  final double x;
  final double y;
  final double radius;
  final double rate;
  final double phase;
  final double drift;
}
