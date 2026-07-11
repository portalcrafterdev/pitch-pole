import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// The floor and ceiling. Drawn in viewport space and scrolled by hand, so a
/// 8400 unit level costs the same to draw as a 6000 unit one.
class SurfaceStrip extends PositionComponent {
  SurfaceStrip() : super(priority: -10);

  /// World x at the left edge of the view. The game sets this every frame.
  double scrollX = 0;

  static const double _tile = 40;

  final Paint _block = Paint()..color = Palette.block;
  final Paint _edge = Paint()..color = Palette.door.withValues(alpha: 0.55);
  final Paint _seam = Paint()..color = Palette.blockEdge;

  @override
  void render(Canvas canvas) {
    // Solid ceiling above the band and solid floor below it.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kCanvasWidth, kCeilingSurfaceY),
      _block,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        kFloorSurfaceY,
        kCanvasWidth,
        kCanvasHeight - kFloorSurfaceY,
      ),
      _block,
    );

    // The two surface lines the character actually rests on.
    canvas.drawRect(
      const Rect.fromLTWH(0, kCeilingSurfaceY - 1.5, kCanvasWidth, 1.5),
      _edge,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kFloorSurfaceY, kCanvasWidth, 1.5),
      _edge,
    );

    // Seams, so the speed reads even on an empty stretch.
    final offset = scrollX % _tile;
    for (var x = -offset; x < kCanvasWidth; x += _tile) {
      canvas.drawRect(
        Rect.fromLTWH(x, kCeilingSurfaceY - kBlockThickness, 1, kBlockThickness),
        _seam,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, kFloorSurfaceY, 1, kBlockThickness),
        _seam,
      );
    }
  }
}
