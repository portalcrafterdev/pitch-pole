import 'dart:ui';

/// A forest by day: blue sky over the canopy, sunlight coming down through
/// the leaves, and the run itself in the dappled shade underneath.
///
/// The rule that matters has not changed, only how it is kept. Colour is how
/// the player tells safe from lethal at 280 units a second, so **red, yellow,
/// violet and magenta are reserved for things that kill, and green for things
/// that help**. Nothing in the scenery is allowed to use them. Brightness is
/// no longer what separates the cast from the world; saturation is. The world
/// is muted and the cast is not.
///
/// The play band in particular stays a mid tone rather than going pale. The
/// blade is near white steel and would simply vanish against a bright sky.
class Palette {
  const Palette._();

  /// Menus and panels. Deliberately still dark: the shell is not the forest,
  /// and light text on a bright sky would be unreadable.
  static const Color background = Color(0xFF0A1410);
  static const Color surface = Color(0xFF11201A);

  /// Sky above the canopy, and the colour the letterboxing is filled with.
  static const Color skyHigh = Color(0xFF4E9BD0);
  static const Color skyLow = Color(0xFF9FD2E8);
  static const Color cloud = Color(0xFFF2FAFF);

  /// The shade under the canopy, where the run actually happens. Bright enough
  /// to read as daylight, dark enough that steel and bone still show up.
  static const Color bandHigh = Color(0xFF4A7D66);
  static const Color bandLow = Color(0xFF33604D);

  /// Forest floor: warm earth under a moss cap.
  static const Color earth = Color(0xFF5A422C);
  static const Color earthDark = Color(0xFF3C2C1D);
  static const Color moss = Color(0xFF63C471);
  static const Color mossDark = Color(0xFF3C8B4C);

  /// Canopy overhead, and the trees receding behind the run. The far line goes
  /// hazy and blue rather than green, which is how distance actually reads and
  /// keeps the greens of the coins and the finish line to themselves.
  static const Color canopy = Color(0xFF2C6238);

  /// Only a little lighter than the band it sits in. Anything brighter reads
  /// as a foreground object, and worse, lands in the same pale family as the
  /// steel blade — which then gets lost against it.
  static const Color canopyFar = Color(0xFF5C8A7C);
  static const Color canopyMid = Color(0xFF3C7A4E);
  static const Color trunk = Color(0xFF4A3626);

  /// Sunlight through the leaves, and the things drifting in it.
  static const Color shaft = Color(0xFFFFF6C8);
  static const Color mist = Color(0xFFDCEFE4);
  static const Color firefly = Color(0xFFFFF3C4);

  /// Whatever else lives in the forest: deer in the treeline, birds crossing
  /// behind it, moths in the light.
  ///
  /// Darker than the trees now rather than lighter — in daylight a distant
  /// animal reads as a silhouette. It still has to be findable against the
  /// trees and invisible next to an obstacle, because scenery scrolls and
  /// anything with real contrast in it would read as a threat.
  static const Color wildlife = Color(0xFF27503A);
  static const Color moth = Color(0xFFFFFBEA);

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

  /// Fire, erupts from one surface on a rhythm. Three shades so a flame reads
  /// hot in the middle and cooler at the tip.
  static const Color fireCore = Color(0xFFFFF0A8);
  static const Color fireMid = Color(0xFFFF9A2E);
  static const Color fireEdge = Color(0xFFE8452B);

  /// The vent it comes out of, and the glow that warns you it is about to.
  static const Color vent = Color(0xFF4A3A32);
  static const Color ventHot = Color(0xFFFF6A2A);

  /// Violet, hangs in the middle of the band. A hue of its own, because a bat
  /// is answered differently from everything else and must never be mistaken
  /// for something you can jump.
  static const Color bat = Color(0xFFA974F0);
  static const Color batDark = Color(0xFF7245B8);

  /// Magenta, drops out of the canopy on a thread.
  static const Color spider = Color(0xFFE8579B);
  static const Color spiderDark = Color(0xFFB03370);

  /// The thread itself. Dull, because it is drawn well outside the hit box and
  /// must not read as part of the threat.
  static const Color thread = Color(0xFF6E7A72);

  /// Coins. Gold, which is the one hue in the game that is deliberately close
  /// to something lethal — [hopper] is amber, and these are only a step away.
  ///
  /// Two things keep them apart. The gold is lighter and yellower than the
  /// hopper's amber, and the coin carries a dark bronze rim that nothing in
  /// the cast has, so it reads as a metal disc rather than as a small enemy.
  /// A hopper is also five times the area, bounces off a surface, and has a
  /// face.
  static const Color coin = Color(0xFFFFCE3F);
  static const Color coinCore = Color(0xFFFFF6D2);
  static const Color coinEdge = Color(0xFF8A5A12);

  /// The finish line and the accent for anything that means "you are through".
  /// Far brighter than any leaf, so it never gets lost in the forest.
  static const Color door = Color(0xFF35E39A);

  static const Color text = Color(0xFFE8F0E9);
  static const Color textMuted = Color(0xFF7A8F82);
  static const Color star = Color(0xFFFFC85C);
}