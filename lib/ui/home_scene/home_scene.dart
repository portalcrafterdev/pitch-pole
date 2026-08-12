import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../menu_palette.dart';
import 'sky_art.dart';

/// The menu backdrop, as a Flame game.
///
/// The game already runs on Flame, so the menu runs on the same loop rather
/// than on a pile of `AnimationController`s. That buys the real thing a Flutter
/// animation cannot give without being rebuilt into one: a component tree. Each
/// moving part is its own component with its own clock and its own priority, so
/// the sun can be lifted out, a cloud added, or the mascot reordered without any
/// of them knowing about each other.
///
/// What it deliberately does not do is own the drawing. Every component defers
/// to a pure function in [sky_art.dart], because the same scene has to be
/// paintable with no loop at all: a device asking for reduced motion, and the
/// widget tests, both render it at t = 0 through a plain `CustomPainter`. One
/// set of brush strokes, two ways of driving it, and no chance of the still
/// version quietly drifting away from the moving one.
class HomeScene extends FlameGame {
  /// Painted under everything, and the colour of any pixel the scene has not
  /// reached yet on the first frame.
  @override
  Color backgroundColor() => MenuPalette.skyLow;

  @override
  Future<void> onLoad() async {
    // Priorities are the paint order, back to front. They are spaced so a new
    // component can be slotted between two without renumbering the rest.
    await addAll([
      _ArtComponent(paintSky, priority: 0),
      _ArtComponent(paintSun, priority: 10),
      _ArtComponent(paintBirds, priority: 20),
      _ArtComponent(paintClouds, priority: 30),
      _ArtComponent(paintHills, priority: 40),
      _ArtComponent(paintCoins, priority: 50),
      _ArtComponent(paintMascot, priority: 60),
      _ArtComponent(paintSparks, priority: 70),
    ]);
  }
}

/// One layer of the scene: a clock, and the function that draws it.
///
/// The clock wraps at ten minutes. Nothing in the scene has a period longer
/// than a minute, so the wrap lands mid loop for something, but a float that
/// has been accumulating for a week has lost enough precision to make the
/// sparkles visibly step, and that is the worse of the two.
class _ArtComponent extends Component {
  _ArtComponent(this.art, {required super.priority});

  final void Function(Canvas canvas, Size size, double t) art;

  double _t = 0;

  @override
  void update(double dt) {
    _t = (_t + dt) % 600;
  }

  @override
  void render(Canvas canvas) {
    final size = findGame()?.size;
    if (size == null) return;
    art(canvas, Size(size.x, size.y), _t);
  }
}
