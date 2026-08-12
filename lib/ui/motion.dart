import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// True when this build is running under `flutter test`.
///
/// The tool sets this variable for the test process and nothing else sets it,
/// so it is a reliable read and it costs a map lookup once at startup.
final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

/// Whether the menus run their looping ambient animations: the drifting
/// clouds, the turning sun, the bobbing mascot.
///
/// Off by default under test, and that default is the whole point of this
/// file. `pumpAndSettle` waits for every animation to finish, and an ambient
/// loop never does, so a test that pumps the home screen with the scene
/// running does not fail with a useful message: it hangs and then times out.
/// Leaving that to each test file to remember was tried, and forgotten, by the
/// second file that pumped the home screen.
///
/// Turning it off never changes what is on screen, only whether it moves.
/// Every part of the scene is painted by a pure function of elapsed time, so
/// the still menu is the first frame of the moving one rather than a second
/// drawing of it, and a test that measures the layout measures the real thing.
/// A test that wants the loop can still set this to true.
bool ambientMotion = !_underTest;

/// Whether looping motion should run for this build.
///
/// Also answers the platform's own reduce motion setting, so a phone set up
/// for someone who finds movement uncomfortable gets a menu that holds still
/// without anyone having to find a switch inside the game.
bool motionFor(BuildContext context) =>
    ambientMotion && !MediaQuery.of(context).disableAnimations;
