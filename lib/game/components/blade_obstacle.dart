import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A blade sweeping the whole band. There is no surface to hide on, only the
/// moment when it is at the far side.
///
/// Its position comes from the level time, which the game derives from how far
/// the character has run, so it is in the same place on every attempt.
class BladeObstacle extends PositionComponent {
  BladeObstacle(this.blade)
      : super(
          position: Vector2(blade.x - kBladeWidth / 2, kCeilingSurfaceY),
          size: Vector2(kBladeWidth, kBladeHeight),
          priority: 6,
        );

  final Blade blade;

  double _spin = 0;

  final Paint _body = Paint()..color = Palette.blade;
  final Paint _edge = Paint()..color = Palette.bladeEdge;
  final Paint _rail = Paint()
    ..color = Palette.bladeEdge.withValues(alpha: 0.28)
    ..strokeWidth = 1;

  void syncTo(double levelTime) {
    position.y = blade.topAt(levelTime);
    // Spun from level time too, so nothing here drifts on a slow frame.
    _spin = levelTime * 9;
  }

  @override
  void render(Canvas canvas) {
    // The rail it runs along, so the sweep reads as mechanical.
    canvas.drawLine(
      Offset(size.x / 2, -position.y + kCeilingSurfaceY),
      Offset(size.x / 2, -position.y + kFloorSurfaceY),
      _rail,
    );

    final teeth = Path();
    const count = 5;
    final width = size.x / count;
    for (var i = 0; i < count; i++) {
      final left = i * width;
      teeth
        ..moveTo(left, size.y / 2)
        ..lineTo(left + width / 2, size.y / 2 - size.y * 0.55)
        ..lineTo(left + width, size.y / 2)
        ..lineTo(left + width / 2, size.y / 2 + size.y * 0.55)
        ..close();
    }
    canvas.drawPath(teeth, _edge);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.y * 0.22, size.x, size.y * 0.56),
        Radius.circular(size.y * 0.28),
      ),
      _body,
    );

    // A turning hub, so a stationary looking blade still reads as live.
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_spin);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.y * 0.5, height: 1.6),
      _edge,
    );
    canvas.rotate(pi / 2);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.y * 0.5, height: 1.6),
      _edge,
    );
    canvas.restore();
  }
}
