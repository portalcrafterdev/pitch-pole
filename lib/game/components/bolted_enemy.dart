import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// Red, bolted to one surface, never moves. Forces a flip.
class BoltedEnemy extends PositionComponent {
  BoltedEnemy(this.enemy)
      : super(
          position: Vector2(
            enemy.x - kBoltedWidth / 2,
            enemy.surface.isCeiling
                ? kCeilingSurfaceY
                : kFloorSurfaceY - kBoltedHeight,
          ),
          size: Vector2(kBoltedWidth, kBoltedHeight),
          priority: 5,
        );

  final Bolted enemy;

  /// How much of the box the spike crown takes. Everything is drawn inside
  /// the hit box, so the spikes can never look like they reached further than
  /// they kill.
  static const double _crownFraction = 0.26;
  static const int _spikes = 4;

  double _t = 0;

  final Paint _body = Paint()..color = Palette.bolted;
  final Paint _crown = Paint()..color = Palette.boltedDark;
  final Paint _white = Paint()..color = Palette.eyeWhite;
  final Paint _pupil = Paint()..color = Palette.eyePupil;

  @override
  void update(double dt) {
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    // Cosmetic bob only. It is not part of the hit box.
    final bob = sin(_t * 2.2 + enemy.x) * kBoltedBob;
    final onCeiling = enemy.surface.isCeiling;

    canvas.save();
    canvas.translate(0, onCeiling ? -bob : bob);

    final crownHeight = size.y * _crownFraction;
    final bodyTop = onCeiling ? 0.0 : crownHeight;
    final bodyHeight = size.y - crownHeight;

    // Spikes point into the play area: up off the floor, down off the ceiling.
    final spikes = Path();
    final width = size.x / _spikes;
    for (var i = 0; i < _spikes; i++) {
      final left = i * width;
      if (onCeiling) {
        final base = bodyHeight;
        spikes
          ..moveTo(left, base)
          ..lineTo(left + width, base)
          ..lineTo(left + width / 2, base + crownHeight)
          ..close();
      } else {
        spikes
          ..moveTo(left, crownHeight)
          ..lineTo(left + width, crownHeight)
          ..lineTo(left + width / 2, 0)
          ..close();
      }
    }
    canvas.drawPath(spikes, _crown);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, bodyTop, size.x, bodyHeight),
        const Radius.circular(4),
      ),
      _body,
    );

    // Bolts, so it reads as fixed to its surface rather than resting on it.
    final boltY = onCeiling ? bodyTop + 3.5 : bodyTop + bodyHeight - 3.5;
    for (final side in [0.16, 0.84]) {
      canvas.drawCircle(Offset(size.x * side, boltY), 1.6, _crown);
    }

    final eyeRadius = size.x * 0.17;
    final eyeY = bodyTop + bodyHeight * 0.46;
    // Pupils tucked towards the player, so it reads as watching the run come.
    final glare = -eyeRadius * 0.22;
    for (final side in [0.30, 0.70]) {
      final centre = Offset(size.x * side, eyeY);
      canvas.drawCircle(centre, eyeRadius, _white);
      canvas.drawCircle(centre.translate(glare, 0), eyeRadius * 0.52, _pupil);
    }

    // Brows angled down towards the middle: the whole face is a scowl, which
    // is the cheapest way to say do not touch this one.
    for (final side in [0.30, 0.70]) {
      final inner = side < 0.5 ? 1.0 : -1.0;
      final x = size.x * side;
      final browY = eyeY - eyeRadius * 1.25;
      canvas.drawPath(
        Path()
          ..moveTo(x - eyeRadius * 1.1, browY - (onCeiling ? -1.6 : 1.6) * inner)
          ..lineTo(x + eyeRadius * 1.1, browY + (onCeiling ? -1.6 : 1.6) * inner)
          ..lineTo(x + eyeRadius * 1.1, browY + eyeRadius * 0.5)
          ..lineTo(x - eyeRadius * 1.1, browY + eyeRadius * 0.5)
          ..close(),
        _crown,
      );
    }

    // A flat gritted mouth under the eyes.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.x / 2, eyeY + eyeRadius * 1.9),
          width: size.x * 0.42,
          height: 2.4,
        ),
        const Radius.circular(1.2),
      ),
      _crown,
    );

    canvas.restore();
  }
}
