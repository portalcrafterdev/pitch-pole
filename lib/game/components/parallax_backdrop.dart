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

  final Paint _wash = Paint();
  final Paint _farPaint = Paint()..color = Palette.canopyFar;
  final Paint _midPaint = Paint()..color = Palette.canopyMid;
  final Paint _trunkPaint = Paint()..color = Palette.trunk;
  final Paint _shaftPaint = Paint();
  final Paint _mistPaint = Paint();
  final Paint _fireflyPaint = Paint();

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
    // Light falls from the canopy, so the band is a shade warmer at the top.
    _wash.shader = Gradient.linear(
      const Offset(0, kCeilingSurfaceY),
      const Offset(0, kFloorSurfaceY),
      const [Color(0xFF12211A), Palette.background],
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kCeilingSurfaceY, kCanvasWidth, kBandHeight),
      _wash,
    );

    _renderTrees(canvas, _far, _farFactor, _farSpan, _farPaint, _farPaint);
    _renderShafts(canvas);
    _renderTrees(canvas, _mid, _midFactor, _midSpan, _midPaint, _trunkPaint);
    _renderMist(canvas);
    _renderFireflies(canvas);
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
