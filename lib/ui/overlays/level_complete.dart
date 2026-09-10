import 'package:flutter/material.dart';

import '../../data/ads.dart';
import '../chapters.dart';
import '../menu_palette.dart';
import '../widgets/confetti_fall.dart';
import '../widgets/star_row.dart';
import 'overlay_panel.dart';

class LevelComplete extends StatelessWidget {
  const LevelComplete({
    super.key,
    required this.levelId,
    required this.stars,
    required this.livesLost,
    required this.seconds,
    required this.bestSeconds,
    required this.coins,
    required this.totalCoins,
    required this.hasNext,
    required this.onNext,
    required this.onRetry,
    required this.onLevels,
    required this.onHome,
  });

  /// The level just cleared. The panel never named it, which on a pack of ten
  /// thousand is the one label worth carrying.
  final int levelId;

  final int stars;

  /// Lives lost on the run, out of three.
  final int livesLost;

  final double seconds;

  /// The previous personal best, or null if this is the first finish.
  final double? bestSeconds;

  /// Coins picked up on this run, out of the coins on the level.
  final int coins;
  final int totalCoins;

  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onLevels;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    // Held until the break is out of the way. The stars pop in one at a time
    // and the confetti falls once, and both used to start the moment this was
    // built — which is the same moment the ad opens over the top of it. The
    // whole celebration played behind the ad, and dismissing it landed the
    // player on three stars already sitting still.
    return AnimatedBuilder(
      animation: adsController,
      builder: (context, _) => _panel(context, !adsController.isShowingAd),
    );
  }

  Widget _panel(BuildContext context, bool celebrate) {
    final isBest = bestSeconds == null || seconds < bestSeconds!;
    return Stack(
      children: [
        OverlayPanel(
          title: 'Cleared',
          accent: MenuPalette.play,
          // Green through to orange: the word finishes on the colour of the
          // retry button under it, which is the thing to do next if the stars
          // are short.
          titleGradient: const [
            Color(0xFF6FD44A),
            Color(0xFFA8D63C),
            Color(0xFFFFC53D),
            Color(0xFFFF9838),
          ],
          // Which level, and which part of the pack. Above the headline, not
          // under it: it is the label on the result, and CLEARED is the
          // result. The clock moved into the strip below with the other two
          // numbers, where it can be read against the coins and the lives
          // instead of standing alone as the headline.
          subtitleAbove: true,
          centerContent: true,
          subtitle: 'LEVEL $levelId  ·  ${bandFor(levelId)}',
          actions: [
            if (hasNext)
              PanelButton(
                label: 'NEXT LEVEL',
                icon: Icons.arrow_forward_rounded,
                filled: true,
                accent: MenuPalette.play,
                onPressed: onNext,
              ),
            if (stars < 3)
              PanelButton(
                label: 'RUN IT CLEAN',
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
            // Quieter than the three above it, and last, because it is the one
            // that ends the session rather than continuing it.
            PanelButton(
              label: 'HOME',
              icon: Icons.home_rounded,
              accent: MenuPalette.inkSoft,
              onPressed: onHome,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarRow(stars: stars, size: 44, animate: celebrate, keyline: true),
              const SizedBox(height: 12),
              _RunStrip(
                seconds: seconds,
                bestSeconds: bestSeconds,
                isBest: isBest,
                coins: coins,
                totalCoins: totalCoins,
                livesLost: livesLost,
              ),
            ],
          ),
        ),
        // Falls in front of the panel, but it is over in a couple of seconds
        // and never eats a tap.
        if (celebrate) const Positioned.fill(child: ConfettiFall()),
      ],
    );
  }
}

/// The run in three numbers, side by side.
///
/// It was a time in the subtitle and a coin count in a row of its own under
/// the stars, which meant the two things you compare after a clear were never
/// next to each other. A clean sweep and a new best are each called out,
/// because those are the two reasons to come back to a level you have beaten.
class _RunStrip extends StatelessWidget {
  const _RunStrip({
    required this.seconds,
    required this.bestSeconds,
    required this.isBest,
    required this.coins,
    required this.totalCoins,
    required this.livesLost,
  });

  final double seconds;
  final double? bestSeconds;
  final bool isBest;
  final int coins;
  final int totalCoins;
  final int livesLost;

  @override
  Widget build(BuildContext context) {
    final swept = totalCoins > 0 && coins == totalCoins;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: MenuPalette.cardSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      // Each cell takes a share of the strip rather than its natural width.
      // Fixed, the three of them overflowed the panel by a few points on a
      // short phone, and "EVERY COIN" is wider than "COINS" so it only did it
      // on the runs worth celebrating.
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              value: '${seconds.toStringAsFixed(1)}s',
              label: isBest ? 'NEW BEST' : 'TIME',
              tint: isBest ? MenuPalette.play : MenuPalette.ink,
            ),
          ),
          if (totalCoins > 0) ...[
            const _StatDivider(),
            Expanded(
              child: _Stat(
                value: '$coins/$totalCoins',
                label: swept ? 'EVERY COIN' : 'COINS',
                tint: swept ? MenuPalette.goldDark : MenuPalette.ink,
              ),
            ),
          ],
          const _StatDivider(),
          Expanded(
            child: _Stat(
              value: '$livesLost',
              label: livesLost == 1 ? 'LIFE LOST' : 'LIVES LOST',
              tint: MenuPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tint});

  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 16,
              height: 1.05,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: MenuPalette.inkSoft,
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 2,
        height: 24,
        color: MenuPalette.inkSoft.withValues(alpha: 0.18),
      );
}
