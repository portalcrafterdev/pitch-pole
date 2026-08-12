import 'dart:ui';

import '../ui/palette.dart';

/// What the ambient specks in the band are.
enum Motes {
  /// Slow, pulsing, warm. The forest at dusk.
  fireflies,

  /// Falling, cold, steady.
  snow,

  /// Falling fast and straight, in streaks rather than dots.
  rain,

  /// Drifting flecks catching the light, neither warm nor cold.
  dust,
}

/// The look of one place the game is played in.
///
/// Every level used to be the same forest. This is that forest plus four other
/// places, so that running level 300 does not look exactly like running level
/// 3, and so the world can change under the player as a reward for getting
/// somewhere.
///
/// **What a theme may not do is make an obstacle harder to see.** That is not a
/// style preference, it is the game's one hard rule, and it is why these are
/// variations in temperature and lightness rather than a free choice of colour.
/// [Palette] keeps red, amber, violet, magenta, near white steel and sandstone
/// for the cast, so a scenery colour close to any of those would put a killer
/// on a background of its own shade. Every colour below that lands inside the
/// play band or on a surface is therefore muted, and `scene_theme_test.dart`
/// holds them to it.
///
/// The sky is the one exception, and is allowed to be properly colourful: it
/// sits entirely above the ceiling, outside the band, so nothing in it can be
/// mistaken for something that kills.
class SceneTheme {
  const SceneTheme({
    required this.name,
    required this.skyHigh,
    required this.skyLow,
    required this.bandHigh,
    required this.bandLow,
    required this.canopy,
    required this.canopyFar,
    required this.canopyMid,
    required this.trunk,
    required this.earth,
    required this.earthDark,
    required this.moss,
    required this.mossDark,
    required this.mist,
    required this.mote,
    required this.wildlife,
    required this.shaft,
    required this.motes,
    this.coniferBias = 0.5,
    this.deer = true,
    this.clouds = true,
    this.stars = false,
    this.mistAlpha = 0.05,
  });

  /// For debugging and for the test that names a failing theme.
  final String name;

  /// Above the ceiling. Allowed to be bright, being outside the band.
  final Color skyHigh;
  final Color skyLow;

  /// The band the run happens in, top and bottom.
  final Color bandHigh;
  final Color bandLow;

  /// The ceiling's underside, and the two receding tree lines behind the run.
  final Color canopy;
  final Color canopyFar;
  final Color canopyMid;
  final Color trunk;

  /// The floor, and the cap that grows on it.
  final Color earth;
  final Color earthDark;
  final Color moss;
  final Color mossDark;

  /// Low haze, the specks drifting in the band, and whatever lives out there.
  final Color mist;
  final Color mote;
  final Color wildlife;

  /// Light coming down from above.
  final Color shaft;

  final Motes motes;

  /// How many of the trees are conifers, 0 to 1. Shape carries as much of a
  /// place as colour does.
  final double coniferBias;

  final bool deer;
  final bool clouds;
  final bool stars;
  final double mistAlpha;

  /// The colours that sit in the band or on a surface, and therefore have to
  /// stay out of the cast's way. The sky is deliberately absent.
  List<Color> get inBand => [
        bandHigh,
        bandLow,
        canopy,
        canopyFar,
        canopyMid,
        trunk,
        earth,
        earthDark,
        moss,
        mossDark,
      ];

  /// The forest, unchanged: this is what every level looked like before there
  /// were themes, and it is still where the game starts.
  static const forest = SceneTheme(
    name: 'forest',
    skyHigh: Palette.skyHigh,
    skyLow: Palette.skyLow,
    bandHigh: Palette.bandHigh,
    bandLow: Palette.bandLow,
    canopy: Palette.canopy,
    canopyFar: Palette.canopyFar,
    canopyMid: Palette.canopyMid,
    trunk: Palette.trunk,
    earth: Palette.earth,
    earthDark: Palette.earthDark,
    moss: Palette.moss,
    mossDark: Palette.mossDark,
    mist: Palette.mist,
    mote: Palette.firefly,
    wildlife: Palette.wildlife,
    shaft: Palette.shaft,
    motes: Motes.fireflies,
  );

  /// Snow. The band goes slate rather than white on purpose: the blade is near
  /// white steel, and a pale band is the one thing that would lose it.
  static const winter = SceneTheme(
    name: 'winter',
    skyHigh: Color(0xFF7FA8CC),
    skyLow: Color(0xFFCFE2EE),
    bandHigh: Color(0xFF5E7A88),
    bandLow: Color(0xFF445C69),
    canopy: Color(0xFF31505C),
    canopyFar: Color(0xFF7C93A0),
    canopyMid: Color(0xFF456672),
    trunk: Color(0xFF4A3B33),
    earth: Color(0xFF6E727A),
    earthDark: Color(0xFF4B4E55),
    // Snow in shadow rather than snow in sun. The first pass had this near
    // white, which put the floor cap within touching distance of the blade,
    // and a blade is near white steel that sweeps the whole band.
    moss: Color(0xFFAFC6D6),
    mossDark: Color(0xFF86A2B4),
    mist: Color(0xFFE8F2F8),
    mote: Color(0xFFF2F8FC),
    wildlife: Color(0xFF2C4450),
    shaft: Color(0xFFE8F4FF),
    motes: Motes.snow,
    coniferBias: 0.85,
    mistAlpha: 0.07,
  );

  /// The same woods after dark, lit by a moon that is not drawn.
  static const night = SceneTheme(
    name: 'night',
    skyHigh: Color(0xFF14203A),
    skyLow: Color(0xFF3A5474),
    bandHigh: Color(0xFF3F4F63),
    bandLow: Color(0xFF2C3849),
    canopy: Color(0xFF20303F),
    canopyFar: Color(0xFF56687C),
    canopyMid: Color(0xFF2E3F51),
    trunk: Color(0xFF33291F),
    earth: Color(0xFF3E3428),
    earthDark: Color(0xFF2A231B),
    moss: Color(0xFF4E7A63),
    mossDark: Color(0xFF33553F),
    mist: Color(0xFFBFD0E4),
    mote: Palette.firefly,
    wildlife: Color(0xFF1B2A36),
    shaft: Color(0xFFCFE0FF),
    motes: Motes.fireflies,
    clouds: false,
    stars: true,
    mistAlpha: 0.04,
  );

  /// Open high ground, wind and haze, hardly any trees.
  static const highland = SceneTheme(
    name: 'highland',
    skyHigh: Color(0xFF5C93B5),
    skyLow: Color(0xFFBFD8DE),
    bandHigh: Color(0xFF5D7C74),
    bandLow: Color(0xFF445D57),
    canopy: Color(0xFF32574E),
    canopyFar: Color(0xFF6E8C86),
    canopyMid: Color(0xFF44685F),
    trunk: Color(0xFF4B4034),
    earth: Color(0xFF5E5344),
    earthDark: Color(0xFF3F3830),
    // Clearly green rather than grey green: the first pass sat close enough
    // to sandstone to blur into a stone obstacle.
    moss: Color(0xFF5F9A76),
    mossDark: Color(0xFF3F6E54),
    mist: Color(0xFFDCE8E8),
    mote: Color(0xFFE4EFEA),
    wildlife: Color(0xFF2A483F),
    shaft: Color(0xFFF0F6E8),
    motes: Motes.dust,
    coniferBias: 0.15,
    mistAlpha: 0.09,
  );

  /// Rain, and the flat grey light that comes with it.
  static const rain = SceneTheme(
    name: 'rain',
    skyHigh: Color(0xFF4E6675),
    skyLow: Color(0xFF93A9B4),
    bandHigh: Color(0xFF4C6A6B),
    bandLow: Color(0xFF354E50),
    canopy: Color(0xFF264945),
    canopyFar: Color(0xFF5F807E),
    canopyMid: Color(0xFF37605A),
    trunk: Color(0xFF3E332A),
    earth: Color(0xFF4C4034),
    earthDark: Color(0xFF322B23),
    moss: Color(0xFF5EA083),
    mossDark: Color(0xFF3B7059),
    mist: Color(0xFFD2E2E4),
    mote: Color(0xFFD6E7EC),
    wildlife: Color(0xFF23423C),
    shaft: Color(0xFFDDEAEC),
    motes: Motes.rain,
    coniferBias: 0.6,
    deer: false,
    mistAlpha: 0.08,
  );

  static const List<SceneTheme> all = [forest, winter, night, highland, rain];

  /// How many levels a theme lasts before the next one.
  ///
  /// Ten rather than one, so a place is somewhere you are rather than
  /// something that flickers past, and rather than a hundred, so a player who
  /// only ever plays the first fifty levels still sees more than one.
  static const int levelsPerTheme = 10;

  /// The theme for a level, which is fixed for that level forever.
  ///
  /// Derived rather than stored, so the level pack does not have to be
  /// regenerated to change any of this, and so a level always looks the same
  /// however it was reached.
  static SceneTheme forLevel(int levelId) {
    final block = ((levelId - 1) ~/ levelsPerTheme).abs();
    return all[block % all.length];
  }
}
