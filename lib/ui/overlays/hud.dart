import 'package:flutter/material.dart';

import '../../game/logic/run_state.dart';
import '../../game/pitchpole_game.dart';
import '../menu_palette.dart';
import '../palette.dart';

/// Top bar: elapsed time, level number, lives, pause.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game, required this.onPause});

  final PitchpoleGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RunState>(
      valueListenable: game.stateNotifier,
      builder: (context, state, _) => Column(
        children: [
          // Pills rather than a dark veil across the top.
          //
          // The veil was there because light text over a bright sky washes
          // out, and it worked, but it put a band of near black across the top
          // quarter of a game that is otherwise a sunny forest. Each group
          // carries its own white pill instead: the contrast is local to the
          // text that needs it, the sky stays visible between them, and it is
          // the same shape language as the menus.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  _Pill(
                    child: Row(
                      children: [
                        Text(
                          state.elapsed.toStringAsFixed(1),
                          style: const TextStyle(
                            color: MenuPalette.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'LEVEL ${game.level.id}',
                          style: const TextStyle(
                            color: MenuPalette.inkSoft,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (game.level.coins.isNotEmpty) ...[
                    _Pill(
                      child: _Coins(
                        collected: state.coins,
                        total: game.level.coins.length,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _Pill(child: _Lives(lives: state.lives)),
                  const SizedBox(width: 8),
                  // A round slab, the same as the settings button on the home
                  // screen. Pausing mid run is done in a hurry, so it gets a
                  // target rather than a bare glyph over moving scenery.
                  Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPause,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.pause_rounded,
                          color: MenuPalette.ink,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _ProgressBar(
            progress: (state.x / game.level.length).clamp(0.0, 1.0),
            checkpoints: [
              for (final checkpoint in game.level.checkpoints)
                checkpoint / game.level.length,
            ],
            reached: state.checkpointX,
          ),
        ],
      ),
    );
  }
}

/// A white lozenge, so a group of readings keeps its contrast wherever the
/// level happens to be bright behind it.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// Coins picked up out of the coins on this level.
///
/// Shown as a fraction rather than a running total, because a coin is worth
/// nothing on its own: what the player is chasing is all of them on one run.
class _Coins extends StatelessWidget {
  const _Coins({required this.collected, required this.total});

  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = collected == total;
    return Row(
      children: [
        Icon(
          Icons.monetization_on_rounded,
          size: 15,
          color: complete ? MenuPalette.goldDark : MenuPalette.gold,
        ),
        const SizedBox(width: 6),
        Text(
          '$collected/$total',
          style: TextStyle(
            color: complete ? MenuPalette.goldDark : MenuPalette.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Lives extends StatelessWidget {
  const _Lives({required this.lives});

  final int lives;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(kStartingLives, (i) {
        final alive = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedScale(
            scale: alive ? 1 : 0.82,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              alive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: alive
                  ? Palette.bolted
                  : MenuPalette.inkSoft.withValues(alpha: 0.3),
            ),
          ),
        );
      }),
    );
  }
}

/// A thin bar along the bottom edge with a tick at each checkpoint.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.checkpoints,
    required this.reached,
  });

  final double progress;
  final List<double> checkpoints;
  final double reached;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: 10,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    color: MenuPalette.play,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                for (final checkpoint in checkpoints)
                  Positioned(
                    left: constraints.maxWidth * checkpoint - 1,
                    child: Container(
                      width: 2,
                      height: checkpoint <= progress ? 10 : 7,
                      decoration: BoxDecoration(
                        color: checkpoint <= progress
                            ? MenuPalette.play
                            : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
