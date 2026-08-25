import 'package:flutter/material.dart';

import '../../data/ads.dart';
import '../menu_palette.dart';
import '../palette.dart';
import 'overlay_panel.dart';

/// Shown only when the last life goes. Ordinary deaths respawn at the last
/// checkpoint after a short pause, with no overlay in the way.
class LevelFailed extends StatelessWidget {
  const LevelFailed({
    super.key,
    required this.onRetry,
    required this.onLevels,
    required this.onExtraLife,
    required this.extraLivesLeft,
  });

  final VoidCallback onRetry;
  final VoidCallback onLevels;

  /// Watch an ad and carry on from the last checkpoint with one more life.
  final VoidCallback onExtraLife;

  /// How many more lives this attempt may still buy back, out of the two a
  /// level allows. At zero the offer is gone and the only way on is to run the
  /// level again from the start.
  final int extraLivesLeft;

  @override
  Widget build(BuildContext context) {
    // Rebuilt as ads load and are spent, because this panel can already be on
    // screen when one arrives.
    return AnimatedBuilder(
      animation: adsController,
      builder: (context, _) => _build(),
    );
  }

  Widget _build() {
    // Two gates, and they are different things. The count is a rule of the
    // game; the loaded ad is a fact about the network. Either one closes the
    // offer, and a button that promises a life it cannot deliver is worse than
    // no button — the player has already accepted the trade by the time it
    // fails.
    final spent = extraLivesLeft <= 0;
    final canRevive = !spent && adsController.canOfferExtraLife;

    return OverlayPanel(
      title: 'Out of lives',
      accent: Palette.bolted,
      subtitle: canRevive
          ? 'Or take one more life and pick the run up at the last '
              'checkpoint.'
          // Said plainly when the two are gone, rather than letting the button
          // vanish and leaving the player to wonder whether the game is
          // broken or the network is.
          : spent
              ? 'That was the second extra life, and two is all a level '
                  'gives. Back to the start — the level never changes, so the '
                  'run you learn is the run that works.'
              : 'Back to the start. The level never changes, so the run you '
                  'learn is the run that works.',
      actions: [
        if (canRevive)
          PanelButton(
            label: 'WATCH AD FOR A LIFE',
            icon: Icons.favorite_rounded,
            filled: true,
            accent: MenuPalette.play,
            onPressed: onExtraLife,
          ),
        PanelButton(
          label: 'RUN IT AGAIN',
          icon: Icons.refresh_rounded,
          filled: true,
          accent: MenuPalette.friend,
          onPressed: onRetry,
        ),
        PanelButton(
          label: 'LEVELS',
          icon: Icons.grid_view_rounded,
          filled: true,
          accent: MenuPalette.levels,
          onPressed: onLevels,
        ),
      ],
    );
  }
}
