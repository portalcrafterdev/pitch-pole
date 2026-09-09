import 'package:flutter/material.dart';

import '../data/ads.dart';
import 'widgets/ad_banner.dart';
import 'widgets/steady_insets.dart';

/// What every screen in the game sits inside.
///
/// Two things live here rather than on the pages themselves.
///
/// [SteadyInsets] holds a page to the insets it has with the system bars
/// hidden, so a bar that shows itself for three seconds does not relayout
/// everything underneath it.
///
/// And the banner. There is exactly one for the whole app, below the
/// navigator rather than in each menu's `bottomNavigationBar`, because a
/// banner per screen does not work: the home screen stays alive underneath
/// the level select, so the two asked the same unit for an ad at the same
/// moment and the second was declined. Releasing one on the way in and
/// asking for another on the way out only moved the problem — a fresh
/// request every few seconds is declined for the same reason. One ad, loaded
/// once, kept across every menu, is what the unit will serve.
Widget appShell(BuildContext context, Widget? child) {
  return SteadyInsets(
    child: Column(
      children: [
        Expanded(child: child ?? const SizedBox.shrink()),
        // Zero height while a run is on, and zero height until an ad has
        // loaded, so the pages below run to the bottom edge either way.
        AnimatedBuilder(
          animation: adsController,
          builder: (context, _) =>
              adsController.bannerAllowed ? const AdBanner() : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}
