import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/ads.dart';
import 'data/games_auth.dart';
import 'data/progress_store.dart';
import 'game/sound.dart';
import 'ui/palette.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The play field is 560 by 220, so portrait would letterbox the game into a
  // thin strip across the middle. Landscape only, and both ways round, so the
  // phone can be held either way. Setting this overrides a device rotation
  // lock, which is the whole point: the player should never have to unlock
  // rotation by hand to be able to see the level.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full bleed, so the status and navigation bars do not eat the band.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await progressStore.load();

  // Not awaited. Reconnecting to Play Games or Game Center means a round trip
  // to the platform, and reaching the menu must never wait on a network. The
  // button updates itself when the answer arrives. It also only reaches the
  // platform at all if the player has signed in before, so a fresh install
  // gets no account prompt it did not ask for.
  unawaited(gamesAuth.load());

  // Also not awaited, and for a stronger reason: this one starts a network
  // fetch. The first ad has the whole of the menu and the level select to
  // arrive in, and if it does not arrive the first level simply starts
  // without one.
  unawaited(adsController.initialize());

  // Build the sound pools while the menu is up, so the first jump of the
  // first level lands as quickly as the thousandth. Not awaited: a device
  // with no working audio should still reach the menu immediately.
  if (progressStore.soundEnabled) unawaited(SoundPlayer.warmUp());

  runApp(const PitchpoleApp());
}

class PitchpoleApp extends StatelessWidget {
  const PitchpoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitchpole',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.door,
          brightness: Brightness.dark,
          surface: Palette.surface,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: const HomeScreen(),
    );
  }
}
