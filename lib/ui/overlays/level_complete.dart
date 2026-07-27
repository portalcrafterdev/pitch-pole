import 'package:flutter/material.dart';

import '../palette.dart';
import '../widgets/confetti_fall.dart';
import '../widgets/star_row.dart';
import 'overlay_panel.dart';

class LevelComplete extends StatelessWidget {
  const LevelComplete({
    super.key,
    required this.stars,
    required this.seconds,
    required this.bestSeconds,
    required this.hasNext,
    required this.onNext,
    required this.onRetry,
    required this.onLevels,
  });

  final int stars;
  final double seconds;

  /// The previous personal best, or null if this is the first finish.
  final double? bestSeconds;

  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    final isBest = bestSeconds == null || seconds < bestSeconds!;
    return Stack(
      children: [
        OverlayPanel(
          title: 'Cleared',
          accent: Palette.door,
          subtitle: isBest
              ? 'New best: ${seconds.toStringAsFixed(1)}s'
              : '${seconds.toStringAsFixed(1)}s  ·  '
                  'best ${bestSeconds!.toStringAsFixed(1)}s',
          actions: [
            if (hasNext)
              PanelButton(
                label: 'NEXT LEVEL',
                icon: Icons.arrow_forward_rounded,
                filled: true,
                accent: Palette.door,
                onPressed: onNext,
              ),
            if (stars < 3)
              PanelButton(
                label: 'RUN IT CLEAN',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            PanelButton(
              label: 'LEVELS',
              icon: Icons.grid_view_rounded,
              onPressed: onLevels,
            ),
          ],
          child: StarRow(stars: stars, size: 38, animate: true),
        ),
        // Falls in front of the panel, but it is over in a couple of seconds
        // and never eats a tap.
        const Positioned.fill(child: ConfettiFall()),
      ],
    );
  }
}
