import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A coin sitting in the run.
///
/// Whether it has been taken is decided by the simulator, not here — this only
/// draws it. The spin is driven by level time so it is the same on every
/// device, and the pop on collection is the one piece of pure decoration.
class CoinPickup extends PositionComponent {
  CoinPickup(this.coin)
      : super(
          position: Vector2(coin.x - kCoinSize / 2, coin.y - kCoinSize / 2),
          size: Vector2.all(kCoinSize),
          priority: 4,
        );

  final Coin coin;

  double _spin = 0;

  /// Counts down while the collection pop plays. Negative once it is over and
  /// the coin is gone for good.
  double _pop = -1;

  static const double popDuration = 0.28;

  bool _taken = false;

  final Paint _face = Paint();
  final Paint _core = Paint();
  final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _burst = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  bool get isTaken => _taken;

  void syncTo(double levelTime) {
    // Offset by x so a row of coins spins out of step rather than in unison.
    _spin = levelTime * 3.4 + coin.x * 0.02;
  }

  /// Called once, the frame the simulator says this coin was picked up.
  void collect() {
    if (_taken) return;
    _taken = true;
    _pop = popDuration;
  }

  /// Puts the coin back, for a respawn or a restart.
  void reset() {
    _taken = false;
    _pop = -1;
  }

  @override
  void update(double dt) {
    if (_pop > 0) _pop = max(-1, _pop - dt);
  }

  @override
  void render(Canvas canvas) {
    if (_taken && _pop <= 0) return;

    final centre = Offset(size.x / 2, size.y / 2);

    if (_taken) {
      _renderPop(canvas, centre);
      return;
    }

    // Spinning: the face narrows to an edge and back, like a coin on its axis.
    final turn = cos(_spin);
    final halfWidth = (size.x / 2) * turn.abs().clamp(0.18, 1.0);
    final radius = size.y / 2;

    final face = Rect.fromCenter(
      center: centre,
      width: halfWidth * 2,
      height: radius * 2,
    );

    _face.color = Palette.coin;
    canvas.drawOval(face, _face);

    _edge.color = Palette.coinEdge;
    canvas.drawOval(face, _edge);

    // A bright pip in the middle, only while the face is turned towards the
    // player, so the coin reads as catching the light rather than blinking.
    if (halfWidth > size.x * 0.28) {
      _core.color = Palette.coinCore.withValues(
        alpha: 0.35 + 0.45 * turn.abs(),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: centre,
          width: halfWidth * 0.7,
          height: radius * 0.8,
        ),
        _core,
      );
    }
  }

  /// A ring expanding out as the coin fades. Short, because it happens a lot.
  void _renderPop(Canvas canvas, Offset centre) {
    final t = 1 - (_pop / popDuration);
    _burst.color = Palette.coinCore.withValues(alpha: (1 - t) * 0.9);
    canvas.drawCircle(centre, size.x * (0.4 + t * 0.9), _burst);

    _face.color = Palette.coin.withValues(alpha: (1 - t) * 0.7);
    canvas.drawCircle(centre, size.x * 0.32 * (1 - t), _face);
  }
}
