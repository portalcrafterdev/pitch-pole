import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// One flat dark colour with a slow stripe at most. The enemies and the door
/// must be the only high contrast things on screen.
class ParallaxBackdrop extends PositionComponent {
  ParallaxBackdrop() : super(priority: -20);

  /// World x at the left edge of the view. The game sets this every frame.
  double scrollX = 0;

  static const double _spacing = 180;
  static const double _factor = 0.25;

  final Paint _stripe = Paint()..color = Palette.blockEdge.withValues(alpha: 0.45);

  @override
  void render(Canvas canvas) {
    final offset = (scrollX * _factor) % _spacing;
    for (var x = -offset; x < kCanvasWidth; x += _spacing) {
      canvas.drawRect(
        Rect.fromLTWH(x, kCeilingSurfaceY, 2, kBandHeight),
        _stripe,
      );
    }
  }
}
