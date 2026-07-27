import 'package:flutter/material.dart';

import '../palette.dart';
import 'overlay_panel.dart';

/// Shown only when the last life goes. Ordinary deaths respawn at the last
/// checkpoint after a short pause, with no overlay in the way.
class LevelFailed extends StatelessWidget {
  const LevelFailed({
    super.key,
    required this.onRetry,
    required this.onLevels,
  });

  final VoidCallback onRetry;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      title: 'Out of lives',
      accent: Palette.bolted,
      subtitle: 'Back to the start. The level never changes, so the run you '
          'learn is the run that works.',
      actions: [
        PanelButton(
          label: 'RUN IT AGAIN',
          icon: Icons.refresh_rounded,
          filled: true,
          accent: Palette.bolted,
          onPressed: onRetry,
        ),
        PanelButton(
          label: 'LEVELS',
          icon: Icons.grid_view_rounded,
          onPressed: onLevels,
        ),
      ],
    );
  }
}
