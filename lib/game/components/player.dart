import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curve, Curves;

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// The one character. It never moves horizontally on screen; the world moves
/// past it. Position comes from the simulation every frame, so nothing here
/// can drift away from what the rules say happened.
class PlayerComponent extends PositionComponent {
  PlayerComponent()
      : super(size: Vector2.all(kPlayerSize), priority: 10);

  /// The flip is the signature moment: a full half turn while it crosses.
  static const double flipDuration = 0.15;

  double _spin = 0;
  double _spinFrom = 0;
  double _spinTo = 0;
  double _spinT = 1;

  /// Vertical squash and stretch, 1 is neutral.
  double _stretch = 1;
  double _stretchTarget = 1;

  double _hurt = 0;

  /// Seconds since the level was cleared, or negative while it is still on.
  /// The simulation has stopped by then, so the cheer is drawn as an offset
  /// and never touches [position].
  double _cheer = -1;
  bool _cheerOnCeiling = false;

  final List<Offset> _trail = [];
  static const int _trailLength = 7;

  final Paint _body = Paint()..color = Palette.player;
  final Paint _limb = Paint()..color = Palette.playerDark;
  final Paint _white = Paint()..color = Palette.eyeWhite;
  final Paint _pupil = Paint()..color = Palette.eyePupil;
  final Paint _trailPaint = Paint()..color = Palette.player;

  static const Curve _curve = Curves.easeOut;

  /// Vertical velocity, used only to drift the pupils. Never drives position.
  double _vy = 0;

  /// True while it has a surface under its feet, so the legs know whether to
  /// run or to tuck.
  bool _grounded = true;

  /// How far through the running cycle the legs are. Taken from distance
  /// rather than from a clock, so the stride always matches the speed.
  double _stride = 0;

  /// How far through a blink, or negative between blinks.
  double _blink = -1;
  double _sinceBlink = 0;

  /// One stride covers this much ground. About five and a half steps a second
  /// at base speed, which is a small creature's run rather than a sprint.
  static const double _strideLength = 36;

  /// Drives position straight from the simulation.
  void syncTo(double x, double y, double vy, {bool grounded = true}) {
    position.setValues(x, y);
    _vy = vy;
    _grounded = grounded;
    _stride = x / _strideLength * 2 * pi;
  }

  void onFlip({required bool toCeiling}) {
    _spinFrom = _spin;
    _spinTo = _spin + (toCeiling ? pi : -pi);
    _spinT = 0;
    _stretch = 1.18;
  }

  /// The jump gets a smaller squash and no rotation.
  void onJump() => _stretch = 1.12;

  void onLand() => _stretch = 0.82;

  void onDeath() {
    _hurt = 1;
    _trail.clear();
  }

  /// The level is cleared: spin on the spot and bounce off the surface it
  /// finished on, twice, settling as the burst fades.
  void onCheer({required bool gravityUp}) {
    _cheer = 0;
    _cheerOnCeiling = gravityUp;
    _spinT = 1;
    _stretch = 1.2;
    _trail.clear();
  }

  bool get isCheering => _cheer >= 0;

  /// How far the character is off its surface for the cheer, always away from
  /// whichever surface it landed on.
  double get _cheerLift {
    if (_cheer < 0) return 0;
    final decay = max(0.0, 1 - _cheer / _cheerDuration);
    return sin(_cheer * pi * 3).abs() * 16 * decay;
  }

  static const double _cheerDuration = 1.4;

  void reset() {
    _spin = 0;
    _spinFrom = 0;
    _spinTo = 0;
    _spinT = 1;
    _stretch = 1;
    _stretchTarget = 1;
    _hurt = 0;
    _cheer = -1;
    _trail.clear();
  }

  @override
  void update(double dt) {
    if (_cheer >= 0) {
      _cheer += dt;
      // A free spin, on top of whatever the flip left it at.
      _spin += dt * 7;
    }
    if (_spinT < 1) {
      _spinT = min(1, _spinT + dt / flipDuration);
      _spin = _spinFrom + (_spinTo - _spinFrom) * _curve.transform(_spinT);
    }
    _stretch += (_stretchTarget - _stretch) * min(1, dt * 14);
    if (_hurt > 0) _hurt = max(0, _hurt - dt * 3);

    // A blink every few seconds. Nothing depends on it, it just stops the
    // face being a stare.
    if (_blink >= 0) {
      _blink += dt;
      if (_blink > _blinkDuration) {
        _blink = -1;
        _sinceBlink = 0;
      }
    } else {
      _sinceBlink += dt;
      if (_sinceBlink > _blinkEvery) _blink = 0;
    }

    // Only while airborne. On the ground every sample shares a y, so the
    // trail piles into a solid slab behind the character that reads as a
    // rendering fault rather than as speed.
    if (_grounded) {
      _trail.clear();
    } else {
      _trail.insert(0, Offset(position.x, position.y));
      if (_trail.length > _trailLength) _trail.removeLast();
    }
  }

  static const double _blinkEvery = 3.4;
  static const double _blinkDuration = 0.1;

  @override
  void render(Canvas canvas) {
    // The trail is drawn in world space, so undo the component transform.
    canvas.save();
    canvas.translate(-position.x, -position.y);
    for (var i = _trail.length - 1; i >= 1; i--) {
      final fade = (1 - i / _trail.length) * 0.16;
      if (fade <= 0) continue;
      _trailPaint.color = Palette.player.withValues(alpha: fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _trail[i].dx + kPlayerSize * 0.2,
            _trail[i].dy + kPlayerSize * 0.2,
            kPlayerSize * 0.6,
            kPlayerSize * 0.6,
          ),
          const Radius.circular(3),
        ),
        _trailPaint,
      );
    }
    canvas.restore();

    _body.color = Color.lerp(Palette.player, Palette.bolted, _hurt)!;
    _limb.color = Color.lerp(Palette.playerDark, Palette.boltedDark, _hurt)!;

    final width = size.x / _stretch;
    final height = size.y * _stretch;

    canvas.save();
    canvas.translate(
      size.x / 2,
      size.y / 2 + (_cheerOnCeiling ? _cheerLift : -_cheerLift),
    );
    canvas.rotate(_spin);

    // The body does not fill the box. The bottom quarter is left for the
    // legs, because the box rests exactly on the surface line: a leg drawn
    // below the body would be underground and invisible.
    final bodyHeight = height * _bodyFraction;

    // Everything is drawn behind the body first, so the body overlaps where
    // each limb joins it and nothing shows a seam.
    _drawEars(canvas, width, height);
    _drawLegs(canvas, width, height, bodyHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, bodyHeight),
        Radius.circular(width * 0.34),
      ),
      _body,
    );

    _drawFace(canvas, width, height, bodyHeight);
    canvas.restore();
  }

  /// How much of the box is body. The rest is legs.
  static const double _bodyFraction = 0.76;

  /// Two ears on top, laid back by the run. They also say which way is up,
  /// which is what makes a flipped character read as upside down.
  void _drawEars(Canvas canvas, double width, double height) {
    final top = -height / 2;
    for (final side in [-1.0, 1.0]) {
      final root = side * width * 0.24;
      canvas.drawPath(
        Path()
          ..moveTo(root - width * 0.10, top + 2)
          ..lineTo(root + width * 0.10, top + 2)
          // Swept back, so it reads as moving even in a still frame.
          ..lineTo(root - width * 0.16, top - height * 0.20)
          ..close(),
        _limb,
      );
    }
  }

  /// Two legs cycling out of the bottom. Grounded they run; airborne they
  /// tuck up, which is what sells a jump without any extra animation.
  void _drawLegs(Canvas canvas, double width, double height, double bodyHeight) {
    // Start inside the body so the joint is hidden, and reach the sole of the
    // box, which is the surface the character is standing on.
    final hip = -height / 2 + bodyHeight - height * 0.05;
    final sole = height / 2;
    final full = sole - hip;
    final thickness = width * 0.17;

    for (var i = 0; i < 2; i++) {
      final phase = _stride + i * pi;
      final swing = _grounded ? sin(phase) : 0.5;
      // The trailing leg comes off the ground; airborne, both tuck.
      final lift = _grounded ? max(0.0, cos(phase)) : 1.0;

      final x = width * 0.19 * (i == 0 ? -1 : 1) + swing * width * 0.17;
      final length = full * (1 - lift * 0.45);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - thickness / 2, hip, thickness, length),
          Radius.circular(thickness / 2),
        ),
        _limb,
      );
      canvas.drawCircle(Offset(x, hip + length), thickness * 0.58, _limb);
    }
  }

  /// Big eyes in the upper half. The pupils lean into the run and drift with
  /// the fall, which is most of what makes it feel alive.
  void _drawFace(Canvas canvas, double width, double height,
      double bodyHeight) {
    // Measured from the middle of the body, not the middle of the box, so
    // the face stays centred now that the legs own the bottom quarter.
    final bodyCentre = -height / 2 + bodyHeight / 2;
    final eyeRadius = width * 0.21;
    final eyeY = bodyCentre - bodyHeight * 0.04;
    final eyeX = width * 0.21;
    final pupilLean = eyeRadius * 0.28;
    final pupilDrift =
        (_vy / kJumpVelocity).clamp(-1.0, 1.0) * eyeRadius * 0.30;
    final blinking = _blink >= 0;

    for (final side in [-1.0, 1.0]) {
      final centre = Offset(side * eyeX, eyeY);
      if (blinking) {
        // A closed eye is a line, not a smaller circle.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: centre,
              width: eyeRadius * 1.8,
              height: eyeRadius * 0.42,
            ),
            Radius.circular(eyeRadius * 0.21),
          ),
          _pupil,
        );
        continue;
      }
      canvas.drawCircle(centre, eyeRadius, _white);
      canvas.drawCircle(
        centre.translate(pupilLean, pupilDrift),
        eyeRadius * 0.46,
        _pupil,
      );
    }

    // A small mouth, open a little wider the faster it is falling.
    final gape = 1 + (_vy.abs() / kJumpVelocity).clamp(0.0, 1.0) * 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width * 0.04, bodyCentre + bodyHeight * 0.30),
          width: width * 0.24,
          height: width * 0.07 * gape,
        ),
        Radius.circular(width * 0.05),
      ),
      _pupil,
    );
  }
}
