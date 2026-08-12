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
  });

  final VoidCallback onRetry;
  final VoidCallback onLevels;

  /// Watch an ad and carry on from the last checkpoint with one more life.
  final VoidCallback onExtraLife;

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
    // Only offered when an ad is actually loaded. A button that promises a
    // life and then cannot deliver one is worse than no button: the player
    // has already decided to accept the trade by the time it fails.
    final canRevive = adsController.canOfferExtraLife;

    return OverlayPanel(
      title: 'Out of lives',
      accent: Palette.bolted,
      subtitle: canRevive
          ? 'Or take one more life and pick the run up at the last '
              'checkpoint.'
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
