import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A bat hovering in the middle of the band.
///
/// Its height comes from the level time the game feeds it, so it is where the
/// validator says it is. The wingbeat is cosmetic and never touches the hit
/// box — a bat with its wings out is no wider than one with them tucked.
class BatEnemy extends PositionComponent {
  BatEnemy(this.bat)
      : super(
          position: Vector2(bat.x - kBatWidth / 2, 0),
          size: Vector2(kBatWidth, kBatHeight),
          priority: 6,
        );

  final Bat bat;

  /// Drives the wings only.
  double _beat = 0;

  final Paint _wing = Paint()..color = Palette.batDark;
  final Paint _body = Paint()..color = Palette.bat;
  final Paint _white = Paint()..color = Palette.eyeWhite;
  final Paint _pupil = Paint()..color = Palette.eyePupil;

  void syncTo(double levelTime) {
    position.y = bat.centreAt(levelTime) - kBatHeight / 2;
    _beat = levelTime;
  }

  @override
  void render(Canvas canvas) {
    final centreX = size.x / 2;
    final centreY = size.y / 2;

    // Wings beat faster than anything else on screen, so a bat is the first
    // thing the eye finds in an empty stretch of band.
    final flap = sin(_beat * 11);
    final span = size.x * 0.30;
    final lift = flap * size.y * 0.24;

    for (final side in [-1.0, 1.0]) {
      final tipX = centreX + side * (size.x / 2);
      canvas.drawPath(
        Path()
          ..moveTo(centreX + side * size.x * 0.10, centreY - 1)
          ..quadraticBezierTo(
            centreX + side * span,
            centreY - lift - size.y * 0.30,
            tipX,
            centreY - lift * 0.5,
          )
          // A scalloped trailing edge, so it reads as a wing and not a fin.
          ..quadraticBezierTo(
            centreX + side * span * 1.05,
            centreY + size.y * 0.16 - lift * 0.3,
            centreX + side * size.x * 0.10,
            centreY + size.y * 0.20,
          )
          ..close(),
        _wing,
      );
    }

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centreX, centreY),
          width: size.x * 0.34,
          height: size.y * 0.72,
        ),
        Radius.circular(size.x * 0.16),
      ),
      _body,
    );

    // Ears, so the silhouette is unmistakably a bat even at 28 units wide.
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(centreX + side * size.x * 0.11, centreY - size.y * 0.30)
          // Kept just inside the box: everything is drawn within the sprite,
          // which is itself 3 units bigger than the hit box on every side.
          ..lineTo(centreX + side * size.x * 0.16, centreY - size.y * 0.47)
          ..lineTo(centreX + side * size.x * 0.03, centreY - size.y * 0.34)
          ..close(),
        _body,
      );
    }

    _drawFace(canvas, centreX, centreY);
  }

  void _drawFace(Canvas canvas, double centreX, double centreY) {
    final eyeY = centreY - size.y * 0.10;
    final radius = size.x * 0.055;
    for (final side in [-1.0, 1.0]) {
      final eyeX = centreX + side * size.x * 0.075;
      canvas.drawCircle(Offset(eyeX, eyeY), radius, _white);
      // Pupils lean into the oncoming run, like the rest of the cast.
      canvas.drawCircle(
        Offset(eyeX - radius * 0.35, eyeY),
        radius * 0.55,
        _pupil,
      );
    }
  }
}
