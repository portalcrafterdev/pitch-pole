import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// The two surfaces: mossy forest floor below, leaf canopy above.
///
/// Drawn in viewport space and scrolled by hand, so an 8400 unit level costs
/// the same to draw as a 6000 unit one. The grass and the leaves are rolled
/// once from a fixed seed and repeat over one span, so the ground looks the
/// same every run without storing anything per level.
class SurfaceStrip extends PositionComponent {
  SurfaceStrip() : super(priority: -10);

  /// World x at the left edge of the view. The game sets this every frame.
  double scrollX = 0;

  /// How far the decoration pattern runs before it repeats. Wider than the
  /// view, so two placements always cover the screen.
  static const double _span = 720;

  /// How far grass and leaves reach into the band. Cosmetic only, and behind
  /// the character, so it never reads as something that can touch you.
  static const double _fringe = 6;

  late final List<_Blade> _grass = _sow(seed: 5, count: 74, up: true);
  late final List<_Blade> _leaves = _sow(seed: 13, count: 62, up: false);
  late final List<_Rock> _rocks = _scatter(seed: 23, count: 16);

  final Paint _earth = Paint()..color = Palette.earth;
  final Paint _canopy = Paint()..color = Palette.canopy;
  final Paint _mossCap = Paint()..color = Palette.mossDark;
  final Paint _mossEdge = Paint()..color = Palette.moss;
  final Paint _leafEdge = Paint()..color = Palette.canopyMid;
  final Paint _blade = Paint()..color = Palette.moss;
  final Paint _rock = Paint()..color = Palette.earthDark;

  static List<_Blade> _sow({
    required int seed,
    required int count,
    required bool up,
  }) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Blade(
        x: (i + random.nextDouble() * 0.9) * (_span / count),
        height: (up ? 3.0 : 2.0) + random.nextDouble() * _fringe,
        lean: (random.nextDouble() * 2 - 1) * 2.2,
        width: 0.9 + random.nextDouble() * 0.9,
      );
    });
  }

  static List<_Rock> _scatter({required int seed, required int count}) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Rock(
        x: (i + random.nextDouble() * 0.8) * (_span / count),
        y: kFloorSurfaceY + 6 + random.nextDouble() * (kBlockThickness - 4),
        radius: 1.6 + random.nextDouble() * 2.6,
      );
    });
  }

  @override
  void render(Canvas canvas) {
    // The solid mass above and below the band.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kCanvasWidth, kCeilingSurfaceY),
      _canopy,
    );
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        kFloorSurfaceY,
        kCanvasWidth,
        kCanvasHeight - kFloorSurfaceY,
      ),
      _earth,
    );

    // A moss cap along the top of the earth, and the bright line the
    // character actually rests on.
    canvas.drawRect(
      const Rect.fromLTWH(0, kFloorSurfaceY, kCanvasWidth, 5),
      _mossCap,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kFloorSurfaceY, kCanvasWidth, 1.5),
      _mossEdge,
    );

    // The underside of the canopy, and the line the character rests on when
    // gravity is up.
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        kCeilingSurfaceY - 5,
        kCanvasWidth,
        5,
      ),
      _leafEdge,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kCeilingSurfaceY - 1.5, kCanvasWidth, 1.5),
      _mossEdge,
    );

    final offset = scrollX % _span;

    _renderBlades(canvas, _grass, offset, up: true);
    _renderBlades(canvas, _leaves, offset, up: false);
    _renderRocks(canvas, offset);
  }

  /// Grass sprouting up off the floor, and leaves hanging down off the
  /// canopy. Both lean, so the speed reads even on an empty stretch.
  void _renderBlades(
    Canvas canvas,
    List<_Blade> blades,
    double offset, {
    required bool up,
  }) {
    final root = up ? kFloorSurfaceY : kCeilingSurfaceY;
    final direction = up ? -1.0 : 1.0;
    _blade.color = up
        ? Palette.moss.withValues(alpha: 0.55)
        : Palette.moss.withValues(alpha: 0.28);

    for (final blade in blades) {
      final x = blade.x - offset;
      for (final placed in [x, x + _span]) {
        if (placed < -4 || placed > kCanvasWidth + 4) continue;
        canvas.drawPath(
          Path()
            ..moveTo(placed - blade.width, root)
            ..lineTo(placed + blade.width, root)
            ..lineTo(
              placed + blade.lean,
              root + direction * blade.height,
            )
            ..close(),
          _blade,
        );
      }
    }
  }

  /// Stones half buried in the earth, so the floor is not a flat colour.
  void _renderRocks(Canvas canvas, double offset) {
    for (final rock in _rocks) {
      final x = rock.x - offset;
      for (final placed in [x, x + _span]) {
        if (placed < -8 || placed > kCanvasWidth + 8) continue;
        canvas.drawCircle(Offset(placed, rock.y), rock.radius, _rock);
      }
    }
  }
}

class _Blade {
  const _Blade({
    required this.x,
    required this.height,
    required this.lean,
    required this.width,
  });

  final double x;
  final double height;

  /// How far the tip is pushed sideways from the root.
  final double lean;
  final double width;
}

class _Rock {
  const _Rock({required this.x, required this.y, required this.radius});

  final double x;
  final double y;
  final double radius;
}