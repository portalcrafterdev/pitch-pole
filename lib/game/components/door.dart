import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/palette.dart';
import '../logic/physics.dart';

/// The end of the level: a chequered finish line spanning the whole band, so
/// it cannot be missed on either surface. Crossing it fires [celebrate].
class DoorComponent extends PositionComponent {
  DoorComponent({required double x})
      : super(
          position: Vector2(x, kCeilingSurfaceY),
          size: Vector2(lineWidth, kBandHeight),
          priority: 4,
        );

  static const double lineWidth = 28;

  /// How long the finishing burst runs. The game holds the scene at least this
  /// long before the overlay, so the player actually sees it.
  static const double burstDuration = 1.1;

  static const double _cell = lineWidth / 2;

  /// How fast the chequers crawl down. Slow enough to read as a flag rather
  /// than a barber pole.
  static const double _scrollSpeed = 26;

  static const int _sparkCount = 26;

  double _t = 0;

  /// Seconds since the player crossed. Negative while the level is still on.
  double _since = -1;

  final List<_Spark> _sparks = _makeSparks();

  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _backing = Paint();
  final Paint _chequer = Paint();
  final Paint _edge = Paint();
  final Paint _frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _spark = Paint();

  /// Seeded, so the burst looks the same every time the level is finished.
  static List<_Spark> _makeSparks() {
    final random = Random(7);
    return List.generate(_sparkCount, (i) {
      return _Spark(
        angle: i / _sparkCount * 2 * pi + random.nextDouble() * 0.5,
        speed: 70 + random.nextDouble() * 120,
        size: 2 + random.nextDouble() * 2.5,
        spin: (random.nextDouble() * 2 - 1) * 9,
        colour: switch (i % 3) {
          0 => Palette.star,
          1 => Palette.door,
          _ => Palette.text,
        },
      );
    });
  }

  bool get isCelebrating => _since >= 0 && _since < burstDuration;

  void celebrate() => _since = 0;

  void reset() => _since = -1;

  @override
  void update(double dt) {
    _t += dt;
    if (_since >= 0) _since += dt;
  }

  @override
  void render(Canvas canvas) {
    final burst = _since < 0 ? 0.0 : min(1.0, _since / burstDuration);
    // Bright at the moment of crossing, gone by the end of the burst.
    final flash = _since < 0 ? 0.0 : (1 - burst) * (1 - burst);
    final breathe = 0.5 + 0.5 * sin(_t * 2.4);

    final rounded = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(5),
    );

    _glow.color =
        Palette.door.withValues(alpha: 0.18 + 0.14 * breathe + 0.5 * flash);
    canvas.drawRRect(rounded, _glow);

    _backing.color = Palette.background.withValues(alpha: 0.85);
    canvas.drawRRect(rounded, _backing);

    // Two columns of chequers crawling downwards, so the line reads as alive
    // from the moment it comes on screen rather than only once it is reached.
    canvas.save();
    canvas.clipRRect(rounded);
    _chequer.color = Color.lerp(Palette.text, Palette.door, 0.1 + 0.6 * flash)!
        .withValues(alpha: 0.9);
    final scroll = (_t * _scrollSpeed) % (_cell * 2);
    final rows = (size.y / _cell).ceil() + 2;
    for (var row = -2; row < rows; row++) {
      for (var col = 0; col < 2; col++) {
        if ((row + col).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * _cell, row * _cell + scroll, _cell, _cell),
          _chequer,
        );
      }
    }
    canvas.restore();

    // The leading edge is the line the player is actually running at, so it
    // gets the brightest colour on screen.
    _edge.color = Palette.door.withValues(alpha: 0.7 + 0.3 * breathe);
    canvas.drawRect(Rect.fromLTWH(0, 0, 2.5, size.y), _edge);

    _frame.color = Palette.door.withValues(alpha: 0.5 + 0.5 * flash);
    canvas.drawRRect(rounded, _frame);

    if (burst > 0 && burst < 1) _renderBurst(canvas, burst);
  }

  /// Rings and confetti, drawn outside the clip so they spill across the band.
  void _renderBurst(Canvas canvas, double burst) {
    final centre = Offset(size.x / 2, size.y / 2);

    for (var i = 0; i < 3; i++) {
      final p = burst - i * 0.13;
      if (p <= 0) continue;
      _ring.color = Palette.door.withValues(alpha: (1 - p) * 0.5);
      canvas.drawCircle(centre, 12 + p * 130, _ring);
    }

    for (final spark in _sparks) {
      // Fast out, then dragging, and falling harder the longer it is in the
      // air, so the confetti settles instead of flying off in a straight line.
      final travel = spark.speed * burst * (1.4 - 0.4 * burst);
      _spark.color = spark.colour.withValues(alpha: (1 - burst) * 0.95);
      canvas.save();
      canvas.translate(
        centre.dx + cos(spark.angle) * travel,
        centre.dy + sin(spark.angle) * travel + 90 * burst * burst,
      );
      canvas.rotate(spark.spin * burst);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: spark.size * 1.8,
          height: spark.size,
        ),
        _spark,
      );
      canvas.restore();
    }
  }
}

/// One piece of confetti. Fixed at construction, never re-rolled.
class _Spark {
  const _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.colour,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color colour;
}
