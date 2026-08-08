import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A spider dropping out of the canopy on a thread.
///
/// The drop comes from level time, so it is where the validator says it is.
/// The thread is drawn from the ceiling line down to the body and is never
/// part of the hit box — only the body kills.
class SpiderEnemy extends PositionComponent {
  SpiderEnemy(this.spider)
      : super(
          position: Vector2(spider.x - kSpiderSize / 2, 0),
          size: Vector2(kSpiderSize, kSpiderSize),
          priority: 6,
        );

  final Spider spider;

  /// How far below the ceiling line the body is. Kept so the thread knows how
  /// long to be.
  double _drop = kSpiderRest;
  double _sway = 0;

  final Paint _thread = Paint()
    ..color = Palette.thread
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  final Paint _leg = Paint()
    ..color = Palette.spiderDark
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _body = Paint()..color = Palette.spider;
  final Paint _white = Paint()..color = Palette.eyeWhite;
  final Paint _pupil = Paint()..color = Palette.eyePupil;

  void syncTo(double levelTime) {
    _drop = spider.dropAt(levelTime);
    position.y = kCeilingSurfaceY + _drop;
    _sway = levelTime;
  }

  @override
  void render(Canvas canvas) {
    final centreX = size.x / 2;

    // The ceiling line in local coordinates. The thread runs from there to the
    // body, however far down it has come.
    canvas.drawLine(
      Offset(centreX, -_drop),
      Offset(centreX, size.y * 0.30),
      _thread,
    );

    _drawLegs(canvas, centreX);

    // Abdomen and head.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centreX, size.y * 0.58),
        width: size.x * 0.56,
        height: size.y * 0.50,
      ),
      _body,
    );
    canvas.drawCircle(
      Offset(centreX, size.y * 0.34),
      size.x * 0.20,
      _body,
    );

    _drawEyes(canvas, centreX);
  }

  /// Eight legs, in four mirrored pairs, working slightly out of step so the
  /// spider looks alive while it hangs.
  void _drawLegs(Canvas canvas, double centreX) {
    final hipY = size.y * 0.42;
    for (var i = 0; i < 4; i++) {
      final twitch = sin(_sway * 3.4 + i * 1.3) * size.x * 0.045;
      final spread = size.x * (0.30 + i * 0.13);
      final knee = size.y * (0.16 + i * 0.06);
      final foot = size.y * (0.44 + i * 0.12) + twitch;

      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(centreX + side * size.x * 0.10, hipY)
            ..quadraticBezierTo(
              centreX + side * spread,
              knee,
              centreX + side * spread * 0.92,
              foot,
            ),
          _leg,
        );
      }
    }
  }

  void _drawEyes(Canvas canvas, double centreX) {
    final radius = size.x * 0.05;
    for (final side in [-1.0, 1.0]) {
      final eyeX = centreX + side * size.x * 0.075;
      canvas.drawCircle(Offset(eyeX, size.y * 0.31), radius, _white);
      canvas.drawCircle(
        Offset(eyeX, size.y * 0.32),
        radius * 0.5,
        _pupil,
      );
    }
  }
}
