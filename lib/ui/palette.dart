import 'dart:ui';

/// One flat dark background. The spikes and the door are the only high
/// contrast things on screen.
class Palette {
  const Palette._();

  static const Color background = Color(0xFF0F1218);
  static const Color block = Color(0xFF1B2130);
  static const Color blockEdge = Color(0xFF232B3D);
  static const Color surface = Color(0xFF161B26);

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

  static const Color door = Color(0xFF35E39A);

  static const Color text = Color(0xFFE8EDF5);
  static const Color textMuted = Color(0xFF77839A);
  static const Color star = Color(0xFFFFC85C);
}
