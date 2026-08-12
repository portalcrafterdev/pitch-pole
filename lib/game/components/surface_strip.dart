import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../logic/physics.dart';
import '../scene_theme.dart';

/// The two surfaces: mossy forest floor below, leaf canopy above.
///
/// Drawn in viewport space and scrolled by hand, so an 8400 unit level costs
/// the same to draw as a 6000 unit one. The grass and the leaves are rolled
/// once from a fixed seed and repeat over one span, so the ground looks the
/// same every run without storing anything per level.
class SurfaceStrip extends PositionComponent {
  SurfaceStrip({this.theme = SceneTheme.forest}) : super(priority: -10);

  /// The place this level is set in. The floor of a winter level is frozen
  /// ground under snow rather than earth under moss, and it has to agree with
  /// the backdrop behind it or the two read as different worlds.
  final SceneTheme theme;

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
  late final List<_Lobe> _crownLobes = _crownline(seed: 31, count: 30);

  late final Paint _earth = Paint()..color = theme.earth;
  late final Paint _canopy = Paint()..color = theme.canopy;
  late final Paint _mossCap = Paint()..color = theme.mossDark;
  late final Paint _mossEdge = Paint()..color = theme.moss;
  late final Paint _leafEdge = Paint()..color = theme.canopyMid;
  late final Paint _blade = Paint()..color = theme.moss;
  late final Paint _rock = Paint()..color = theme.earthDark;
  late final Paint _subsoil = Paint()..color = theme.earthDark;
  late final Paint _crown = Paint()..color = theme.canopyMid;

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

  static List<_Lobe> _crownline({required int seed, required int count}) {
    final random = Random(seed);
    return List.generate(count, (i) {
      return _Lobe(
        x: (i + random.nextDouble() * 0.8) * (_span / count),
        radius: 7 + random.nextDouble() * 8,
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
    // The canopy is drawn at its real thickness rather than filling
    // everything above the band, so the sky behind it shows through. The
    // backdrop paints that sky; this only has to stop short of it.
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        kCeilingSurfaceY - kBlockThickness,
        kCanvasWidth,
        kBlockThickness,
      ),
      _canopy,
    );
    _renderCanopyTop(canvas);

    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        kFloorSurfaceY,
        kCanvasWidth,
        kCanvasHeight - kFloorSurfaceY,
      ),
      _earth,
    );
    // Deeper soil further down, so the ground is not one flat slab.
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        kFloorSurfaceY + kBlockThickness,
        kCanvasWidth,
        kCanvasHeight - kFloorSurfaceY - kBlockThickness,
      ),
      _subsoil,
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

  /// A scalloped top edge on the canopy, so the treeline meets the sky as
  /// foliage rather than as a ruled line. Scrolls with the world.
  void _renderCanopyTop(Canvas canvas) {
    const top = kCeilingSurfaceY - kBlockThickness;
    final offset = scrollX % _span;

    for (final lobe in _crownLobes) {
      final x = lobe.x - offset;
      for (final placed in [x, x + _span]) {
        if (placed < -20 || placed > kCanvasWidth + 20) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(placed, top + 1),
            width: lobe.radius * 2,
            height: lobe.radius * 1.5,
          ),
          _crown,
        );
      }
    }
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
        ? theme.moss.withValues(alpha: 0.55)
        : theme.moss.withValues(alpha: 0.28);

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

class _Lobe {
  const _Lobe({required this.x, required this.radius});

  final double x;
  final double radius;
}

class _Rock {
  const _Rock({required this.x, required this.y, required this.radius});

  final double x;
  final double y;
  final double radius;
}