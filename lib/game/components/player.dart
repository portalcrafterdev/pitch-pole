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
  final Paint _foot = Paint()..color = Palette.playerDark;
  final Paint _white = Paint()..color = Palette.eyeWhite;
  final Paint _pupil = Paint()..color = Palette.eyePupil;
  final Paint _trailPaint = Paint()..color = Palette.player;

  static const Curve _curve = Curves.easeOut;

  /// Vertical velocity, used only to drift the pupils. Never drives position.
  double _vy = 0;

  /// Drives position straight from the simulation.
  void syncTo(double x, double y, double vy) {
    position.setValues(x, y);
    _vy = vy;
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

    _trail.insert(0, Offset(position.x, position.y));
    if (_trail.length > _trailLength) _trail.removeLast();
  }

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
    _foot.color = Color.lerp(Palette.playerDark, Palette.boltedDark, _hurt)!;

    final width = size.x / _stretch;
    final height = size.y * _stretch;

    canvas.save();
    canvas.translate(
      size.x / 2,
      size.y / 2 + (_cheerOnCeiling ? _cheerLift : -_cheerLift),
    );
    canvas.rotate(_spin);

    // Two nubs peeking out below the body, so it reads as a creature rather
    // than a block. Drawn first, so the body overlaps their tops.
    final footRadius = width * 0.15;
    final footY = height / 2 - footRadius * 0.4;
    canvas.drawCircle(Offset(-width * 0.26, footY), footRadius, _foot);
    canvas.drawCircle(Offset(width * 0.26, footY), footRadius, _foot);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, height),
        Radius.circular(width * 0.34),
      ),
      _body,
    );

    // Big eyes in the upper half, so a flipped character reads as upside down.
    // The pupils lean into the run and drift with the fall, which is most of
    // what makes it feel alive.
    final eyeRadius = width * 0.21;
    final eyeY = -height * 0.06;
    final eyeX = width * 0.21;
    final pupilLean = eyeRadius * 0.28;
    final pupilDrift =
        (_vy / kJumpVelocity).clamp(-1.0, 1.0) * eyeRadius * 0.30;

    for (final side in [-1.0, 1.0]) {
      final centre = Offset(side * eyeX, eyeY);
      canvas.drawCircle(centre, eyeRadius, _white);
      canvas.drawCircle(
        centre.translate(pupilLean, pupilDrift),
        eyeRadius * 0.46,
        _pupil,
      );
    }
    canvas.restore();
  }
}
