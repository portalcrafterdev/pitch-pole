import 'dart:math';

import 'package:flutter/material.dart';

import '../palette.dart';

/// A one shot confetti fall, for the moment a level is cleared. It runs once
/// and then sits still, so it never competes with the panel behind it.
class ConfettiFall extends StatefulWidget {
  const ConfettiFall({super.key, this.pieces = 44});

  final int pieces;

  @override
  State<ConfettiFall> createState() => _ConfettiFallState();
}

class _ConfettiFallState extends State<ConfettiFall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  late final List<_Piece> _pieces = _make(widget.pieces);

  /// Seeded, so the same fall plays every time rather than a new random one.
  static List<_Piece> _make(int count) {
    final random = Random(11);
    return List.generate(count, (i) {
      return _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        fall: 0.75 + random.nextDouble() * 0.45,
        drift: (random.nextDouble() * 2 - 1) * 0.14,
        spin: (random.nextDouble() * 2 - 1) * 8,
        size: 5 + random.nextDouble() * 6,
        colour: switch (i % 4) {
          0 => Palette.door,
          1 => Palette.star,
          2 => Palette.player,
          _ => Palette.text,
        },
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.fall,
    required this.drift,
    required this.spin,
    required this.size,
    required this.colour,
  });

  /// Where it starts across the screen, 0 to 1.
  final double x;

  /// How far into the run it is released, in fractions of the run.
  final double delay;

  /// How much of the run it takes to fall past the bottom.
  final double fall;

  final double drift;
  final double spin;
  final double size;
  final Color colour;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Piece> pieces;
  final double progress;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = (progress - piece.delay) / piece.fall;
      if (t <= 0 || t >= 1) continue;

      // Fades out over the last quarter, so nothing pops off the screen edge.
      final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
      _paint.color = piece.colour.withValues(alpha: fade * 0.9);

      canvas.save();
      canvas.translate(
        (piece.x + piece.drift * t) * size.width,
        (-0.1 + t * 1.2) * size.height,
      );
      canvas.rotate(piece.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.size,
          height: piece.size * 0.55,
        ),
        _paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
