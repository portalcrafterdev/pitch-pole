import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// Yellow, anchored to one surface but bouncing on a fixed rhythm.
///
/// Its height comes straight from the level time the game feeds it, which is
/// a pure function of how far the character has run. That is what makes a
/// checkpoint respawn put every hopper back exactly where it was.
class HopperEnemy extends PositionComponent {
  HopperEnemy(this.enemy, this.hopPeriod)
      : super(
          position: Vector2(enemy.x - kHopperSize / 2, 0),
          size: Vector2.all(kHopperSize),
          priority: 5,
        );

  final Hopper enemy;
  final double hopPeriod;

  double _height = 0;

  /// Rises towards 1 just before a launch, so the player can read the tell.
  double _crouch = 0;

  final Paint _body = Paint()..color = Palette.hopper;
  final Paint _foot = Paint()..color = Palette.hopperDark;
  final Paint _face = Paint()..color = Palette.eyePupil;

  /// Called every frame with the level time, which the game derives from the
  /// character's position.
  void syncTo(double levelTime) {
    final cycle = (levelTime + enemy.phase) % hopPeriod;
    _height = hopHeightAt(cycle);

    final untilLaunch = hopPeriod - cycle;
    _crouch = _height == 0 && untilLaunch < 0.18 ? 1 - untilLaunch / 0.18 : 0;

    position.y = enemy.surface.isCeiling
        ? kCeilingSurfaceY + _height
        : kFloorSurfaceY - _height - kHopperSize;
  }

  @override
  void render(Canvas canvas) {
    final squash = 1 - _crouch * 0.22;
    final height = size.y * squash;
    final top = enemy.surface.isCeiling ? 0.0 : size.y - height;

    // Nubs on the surface side, so a resting hopper looks planted and an
    // airborne one looks like it left the ground.
    final footRadius = size.x * 0.16;
    final footY = enemy.surface.isCeiling ? top + footRadius * 0.3 : top + height - footRadius * 0.3;
    canvas.drawCircle(Offset(size.x * 0.26, footY), footRadius, _foot);
    canvas.drawCircle(Offset(size.x * 0.74, footY), footRadius, _foot);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.x, height),
        Radius.circular(size.x * 0.28),
      ),
      _body,
    );

    // A flatter face than the player's, so the two never read as the same
    // creature at a glance.
    final eyeY = top + height * 0.38;
    final eyeRadius = size.x * 0.105;

    // In the air its eyes go wide and its mouth opens; crouched to launch it
    // screws them shut. Both are tells the player can read on approach.
    final airborne = _height > 0;
    final open = airborne ? 1.35 : 1.0;

    if (_crouch > 0.5) {
      for (final side in [0.32, 0.68]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.x * side, eyeY),
              width: eyeRadius * 2.6,
              height: eyeRadius * 0.7,
            ),
            Radius.circular(eyeRadius * 0.35),
          ),
          _face,
        );
      }
    } else {
      for (final side in [0.32, 0.68]) {
        canvas.drawCircle(
          Offset(size.x * side, eyeY),
          eyeRadius * open,
          _face,
        );
      }
    }

    final mouthY = top + height * 0.66;
    final mouthHeight = size.y * 0.09 * (airborne ? 2.1 : 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.3, mouthY, size.x * 0.4, mouthHeight),
        Radius.circular(mouthHeight / 2),
      ),
      _face,
    );
  }
}
