import 'package:flutter/material.dart';

import '../palette.dart';
import 'overlay_panel.dart';

class PauseMenu extends StatelessWidget {
  const PauseMenu({
    super.key,
    required this.levelId,
    required this.seconds,
    required this.onResume,
    required this.onRestart,
    required this.onLevels,
  });

  final int levelId;

  /// How long this level runs at its own speed.
  final double seconds;

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      title: 'Paused',
      subtitle: 'Level $levelId, ${seconds.toStringAsFixed(0)} seconds of '
          'running.',
      actions: [
        PanelButton(
          label: 'RESUME',
          icon: Icons.play_arrow_rounded,
          filled: true,
          accent: Palette.door,
          onPressed: onResume,
        ),
        PanelButton(
          label: 'RESTART LEVEL',
          icon: Icons.refresh_rounded,
          onPressed: onRestart,
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
