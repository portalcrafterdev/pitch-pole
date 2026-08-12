import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../home_scene/home_scene.dart';
import '../home_scene/sky_art.dart';
import '../motion.dart';

/// The menu scene, running or held still.
///
/// Running, it is a Flame game on its own loop. Held still, it is a single
/// `CustomPaint` of the same scene at t = 0 and nothing is ticking at all.
/// Both go through the same painting functions, so the still one is the first
/// frame of the moving one rather than an approximation of it.
///
/// The still branch is not only for the tests. A `GameWidget` schedules a frame
/// forever, which is exactly what a player who has asked their phone for less
/// motion does not want, and exactly what makes `pumpAndSettle` wait for a
/// menu that is never going to finish moving.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key});

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> {
  /// Built once and kept, so a rebuild of the menu above it does not restart
  /// the scene and jump every cloud back to where it began. A game that is
  /// never handed to a `GameWidget` never starts a loop, so this costs nothing
  /// when the scene is held still.
  final HomeScene _scene = HomeScene();

  @override
  Widget build(BuildContext context) {
    if (!motionFor(context)) return const StillScene();

    return GameWidget(
      game: _scene,
      loadingBuilder: (_) => const StillScene(),
    );
  }
}

/// The scene at rest.
class StillScene extends StatelessWidget {
  const StillScene({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StillScenePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _StillScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintScene(canvas, size, 0);

  @override
  bool shouldRepaint(_StillScenePainter oldDelegate) => false;
}
