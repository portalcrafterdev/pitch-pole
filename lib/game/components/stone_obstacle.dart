import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/level_model.dart';
import '../logic/physics.dart';

/// A stone that hangs against its surface, slams across the band, and is
/// winched back up.
///
/// Like every other obstacle its position comes from the level time, which the
/// game derives from how far the character has run.
class StoneObstacle extends PositionComponent {
  StoneObstacle(this.stone)
      : super(
          position: Vector2(stone.x - kStoneSize / 2, 0),
          size: Vector2.all(kStoneSize),
          priority: 6,
        );

  final Stone stone;

  double _offset = 0;

  /// Rises to 1 in the moment before it drops, as the tell.
  double _wind = 0;

  final Paint _body = Paint()..color = Palette.stone;
  final Paint _chip = Paint()..color = Palette.stoneDark;
  final Paint _chain = Paint()
    ..color = Palette.stoneDark
    ..strokeWidth = 1.4;

  void syncTo(double levelTime) {
    _offset = stone.offsetAt(levelTime);

    final cycle = (levelTime + stone.phase) % stone.period;
    final untilDrop = stone.period - cycle;
    _wind = _offset == 0 && untilDrop < 0.25 ? 1 - untilDrop / 0.25 : 0;

    position.y = stone.surface.isCeiling
        ? kCeilingSurfaceY + _offset
        : kFloorSurfaceY - _offset - kStoneSize;
  }

  @override
  void render(Canvas canvas) {
    final onCeiling = stone.surface.isCeiling;

    // The chain back to the surface it hangs from.
    final anchorY = onCeiling ? -_offset : _offset + size.y;
    canvas.drawLine(
      Offset(size.x / 2, onCeiling ? 0 : size.y),
      Offset(size.x / 2, anchorY),
      _chain,
    );

    // A shiver just before it lets go.
    canvas.save();
    if (_wind > 0) {
      canvas.translate(_wind * 0.8 * (_offset.isNegative ? -1 : 1), 0);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(3),
      ),
      _body,
    );

    // A few chipped corners, so it reads as rock rather than a crate.
    final chips = Path()
      ..moveTo(0, size.y * 0.28)
      ..lineTo(size.x * 0.22, 0)
      ..lineTo(0, 0)
      ..close()
      ..moveTo(size.x, size.y * 0.62)
      ..lineTo(size.x * 0.74, size.y)
      ..lineTo(size.x, size.y)
      ..close();
    canvas.drawPath(chips, _chip);

    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.3, size.y * 0.42, size.x * 0.4, 2),
      _chip,
    );
    canvas.restore();
  }
}
