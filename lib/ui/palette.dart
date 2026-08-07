import 'dart:ui';

/// A dark forest at dusk. Everything in the world is a near black green or
/// brown, so the cast and the finish line stay the only high contrast things
/// on screen.
class Palette {
  const Palette._();

  static const Color background = Color(0xFF0A1410);
  static const Color surface = Color(0xFF11201A);

  /// Forest floor: earth under a moss cap.
  static const Color earth = Color(0xFF1D1710);
  static const Color earthDark = Color(0xFF130F0A);
  static const Color moss = Color(0xFF4FA45F);
  static const Color mossDark = Color(0xFF2C6B3A);

  /// Canopy overhead, and the trees receding behind the run.
  static const Color canopy = Color(0xFF112016);
  static const Color canopyFar = Color(0xFF0E1A14);
  static const Color canopyMid = Color(0xFF13251A);
  static const Color trunk = Color(0xFF1A2C1E);

  /// Low light through the leaves, and the things drifting in it.
  static const Color shaft = Color(0xFFBFE8A8);
  static const Color mist = Color(0xFF6FA98A);
  static const Color firefly = Color(0xFFD9F07A);

  /// Blue, so the two enemy colours stay the loud ones.
  static const Color player = Color(0xFF3E8EF7);
  static const Color playerDark = Color(0xFF2C6FD1);

  /// Red, fixed to a surface.
  static const Color bolted = Color(0xFFEE4B55);
  static const Color boltedDark = Color(0xFFC8323B);

  /// Yellow, bounces in place.
  static const Color hopper = Color(0xFFEFA229);
  static const Color hopperDark = Color(0xFFC97F13);

  /// Every face uses the same two colours, so the cast reads as one set.
  static const Color eyeWhite = Color(0xFFFFFFFF);
  static const Color eyePupil = Color(0xFF12161F);

  /// Steel, sweeps the whole band.
  static const Color blade = Color(0xFFE2E9F3);
  static const Color bladeEdge = Color(0xFF93A2B8);

  /// Stone, slams across the band and is winched back.
  static const Color stone = Color(0xFFA98F6F);
  static const Color stoneDark = Color(0xFF7C6549);

  /// The finish line and the accent for anything that means "you are through".
  /// Far brighter than any leaf, so it never gets lost in the forest.
  static const Color door = Color(0xFF35E39A);

  static const Color text = Color(0xFFE8F0E9);
  static const Color textMuted = Color(0xFF7A8F82);
  static const Color star = Color(0xFFFFC85C);
}