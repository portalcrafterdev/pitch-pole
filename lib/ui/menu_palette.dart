import 'dart:ui';

/// Colours for the menus, and only for the menus.
///
/// [Palette] carries a rule that the whole game leans on: red, yellow, violet
/// and magenta mean a thing that kills, green means a thing that helps, and
/// the scenery may not spend those hues on decoration. At 280 units a second
/// colour is how a player tells safe from lethal, and a pretty background that
/// borrowed the wrong hue would cost them a life.
///
/// None of these are ever drawn while a level is running, so none of them can
/// cost that read. That is what buys the menus the freedom to be loud: the
/// shell is allowed to be a bright toybox precisely because it is not the
/// forest, and nothing here follows the player into a run.
class MenuPalette {
  const MenuPalette._();

  /// Sky, top to bottom. It ends warm rather than blue so the horizon reads as
  /// afternoon light rather than as more sky.
  static const Color skyTop = Color(0xFF3BB8F5);
  static const Color skyMid = Color(0xFF8FE0FF);
  static const Color skyLow = Color(0xFFDFF5FF);
  static const Color horizon = Color(0xFFFFEDBE);

  static const Color sun = Color(0xFFFFD84D);
  static const Color sunGlow = Color(0xFFFFF6C0);

  static const Color cloud = Color(0xFFFFFFFF);

  /// Rolling ground under the sky. Far is paler and bluer, which is how
  /// distance actually reads.
  static const Color hillFar = Color(0xFF86D98C);
  static const Color hillNear = Color(0xFF54BE68);
  static const Color grass = Color(0xFF3EA855);
  static const Color grassDark = Color(0xFF2E8442);

  /// Text on a bright sky. Near black would be harsh on a page this cheerful,
  /// so the darkest ink is a deep blue green instead.
  static const Color ink = Color(0xFF123240);
  static const Color inkSoft = Color(0xFF4C6E7A);

  /// Panels and sheets that sit over the sky.
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardSoft = Color(0xFFEFF9FF);

  /// The button colours. Each is deep enough to carry white text, because a
  /// pastel fill with white on it is the usual way a bright design becomes
  /// unreadable.
  static const Color play = Color(0xFF23C26B);
  static const Color levels = Color(0xFF3D9BF0);
  static const Color friend = Color(0xFFFF9838);
  static const Color pink = Color(0xFFFF6FA5);
  static const Color purple = Color(0xFF9B6BF5);

  /// Coins and stars, the two things that mean "well done".
  static const Color gold = Color(0xFFFFC93C);
  static const Color goldDark = Color(0xFFD9970F);

  /// The rainbow the title is filled with, in order.
  static const List<Color> rainbow = [
    Color(0xFFFF6FA5),
    Color(0xFFFF9838),
    Color(0xFFFFC93C),
    Color(0xFF23C26B),
    Color(0xFF3D9BF0),
    Color(0xFF9B6BF5),
  ];
}
