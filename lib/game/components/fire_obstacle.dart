import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A vent set into one surface that erupts on a rhythm.
///
/// The height comes straight from the level time the game feeds it, which is
/// a pure function of how far the character has run. The flicker on top of it
/// is cosmetic and never touches the hit box, so what the player dodges is
/// exactly what the validator searched.
class FireObstacle extends PositionComponent {
  FireObstacle(this.fire)
      : super(
          position: Vector2(fire.x - kFireWidth / 2, 0),
          size: Vector2(kFireWidth, kFireReach),
          priority: 6,
        );

  final Fire fire;

  double _height = 0;
  double _warning = 0;

  /// Only flickers the drawn flame. Never the height.
  double _flicker = 0;

  final Paint _vent = Paint()..color = Palette.vent;
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _edge = Paint();
  final Paint _mid = Paint();
  final Paint _core = Paint();

  bool get onCeiling => fire.surface.isCeiling;

  /// Called every frame with the level time.
  void syncTo(double levelTime) {
    _height = fire.heightAt(levelTime);
    _warning = fire.warningAt(levelTime);
    _flicker = levelTime;

    // The component spans the full reach whichever way it points, so the
    // flame can be drawn from the surface outwards without moving anything.
    position.y = onCeiling ? kCeilingSurfaceY : kFloorSurfaceY - kFireReach;
  }

  @override
  void render(Canvas canvas) {
    // Local y of the surface the vent is set into, and which way it burns.
    final root = onCeiling ? 0.0 : size.y;
    final direction = onCeiling ? 1.0 : -1.0;

    _renderVent(canvas, root, direction);
    if (_height <= 0.5) return;
    _renderFlame(canvas, root, direction);
  }

  /// The grate, and the glow that says it is about to light. That glow is the
  /// whole reason a fire is readable rather than a trap.
  void _renderVent(Canvas canvas, double root, double direction) {
    final lit = max(_warning, _height / kFireReach);

    // Always a faint ember, even stone cold. Without it a dark vent is just
    // another dark shape on a dark surface, and the only warning you get is
    // the 0.45 second glow — which is not enough to plan a flip around.
    _glow.color = Palette.ventHot.withValues(alpha: 0.14 + 0.48 * lit);
    canvas.drawCircle(
      Offset(size.x / 2, root + direction * 2),
      5 + 6 * lit,
      _glow,
    );

    // Three teeth across the mouth, so it reads as a vent and not a hole.
    final mouth = Rect.fromLTWH(
      1,
      onCeiling ? 0 : size.y - 5,
      size.x - 2,
      5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mouth, const Radius.circular(1.5)),
      _vent,
    );
    _edge.color = Color.lerp(Palette.vent, Palette.ventHot, lit)!;
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          3.5 + i * (size.x - 7) / 3,
          onCeiling ? 1 : size.y - 4,
          2.2,
          3,
        ),
        _edge,
      );
    }
  }

  void _renderFlame(Canvas canvas, double root, double direction) {
    final centre = size.x / 2;
    // Three tongues at slightly different heights, each wobbling on its own
    // beat, so the column never looks like a rectangle.
    for (var i = 0; i < 3; i++) {
      final wobble = sin(_flicker * (9 + i * 2.5) + i * 2.1);
      final scale = i == 1 ? 1.0 : 0.74 + 0.10 * wobble;
      final tipX = centre + (i - 1) * size.x * 0.22 + wobble * 1.6;
      final tip = root + direction * _height * scale;
      final halfWidth = size.x * (i == 1 ? 0.42 : 0.26);

      final paint = switch (i) {
        1 => _mid..color = Palette.fireMid,
        _ => _edge..color = Palette.fireEdge,
      };

      canvas.drawPath(
        Path()
          ..moveTo(centre - halfWidth, root)
          ..quadraticBezierTo(
            centre - halfWidth * 0.9,
            root + direction * _height * scale * 0.55,
            tipX,
            tip,
          )
          ..quadraticBezierTo(
            centre + halfWidth * 0.9,
            root + direction * _height * scale * 0.55,
            centre + halfWidth,
            root,
          )
          ..close(),
        paint,
      );
    }

    // A pale core low down, where a flame is hottest.
    final coreHeight = _height * 0.45;
    _core.color = Palette.fireCore.withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(centre - size.x * 0.16, root)
        ..quadraticBezierTo(
          centre - size.x * 0.14,
          root + direction * coreHeight * 0.6,
          centre + sin(_flicker * 11) * 1.2,
          root + direction * coreHeight,
        )
        ..quadraticBezierTo(
          centre + size.x * 0.14,
          root + direction * coreHeight * 0.6,
          centre + size.x * 0.16,
          root,
        )
        ..close(),
      _core,
    );
  }
}
