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
                  // The level in a chip of its own, with the clock stacked
                  // beside it. A clean run of any level in the pack takes
                  // exactly thirty seconds by construction, so the clock is a
                  // personal best check; the level number is the thing that
                  // says where you are in ten thousand.
                  _Pill(
                    padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
                    child: Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF63B8F5), Color(0xFF2E82D8)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF2266AE),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${game.level.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                              shadows: [
                                Shadow(color: Color(0x33000000), offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'LEVEL',
                              style: TextStyle(
                                color: MenuPalette.inkSoft,
                                fontSize: 8,
                                height: 1.2,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${state.elapsed.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                color: MenuPalette.ink,
                                fontSize: 16,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
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
                  // Asked of the game rather than read off the state: a death
                  // still being handled has not given its life back to the
                  // simulator yet, and the hearts must not wait for it.
                  _Pill(child: _Lives(lives: game.livesShown)),
                  const SizedBox(width: 8),
                  // A round slab, the same as the settings button on the home
                  // screen. Pausing mid run is done in a hurry, so it gets a
                  // target rather than a bare glyph over moving scenery.
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: onPause,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF6FAFC), Color(0xFFCBDCE6)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFA8BFCC),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.pause_rounded,
                          color: Color(0xFF4A6C7C),
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
  const _Pill({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        // The same moulded edge the menus use, so the HUD is made of the same
        // material as the buttons that opened the level.
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: MenuPalette.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 4),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(16, 0, 14, 10),
        child: Row(
          children: [
            Expanded(
              // Was a 6 point hairline at 55% white over a bright forest,
              // which is close to invisible — and it is the only thing on
              // screen that says how far the door is. Opaque, twice as thick,
              // with a knob on it you can actually find.
              child: SizedBox(
                height: 22,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: MenuPalette.ink.withValues(alpha: 0.22),
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          height: 10,
                          width: (constraints.maxWidth - 4) * progress,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF8DDB4E), MenuPalette.play],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      for (final checkpoint in checkpoints)
                        Positioned(
                          left: constraints.maxWidth * checkpoint - 2,
                          child: Container(
                            width: 4,
                            height: checkpoint <= progress ? 18 : 15,
                            decoration: BoxDecoration(
                              color: checkpoint <= progress
                                  ? const Color(0xFF3E8318)
                                  : MenuPalette.ink.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      // Where the character is on the track. The bar was a
                      // measurement; this makes it a position.
                      Positioned(
                        left: (constraints.maxWidth - 22) * progress,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Palette.player,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: MenuPalette.ink.withValues(alpha: 0.24),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            // The door, so the end of the bar is the thing you are running at
            // rather than the end of a bar.
            Container(
              width: 18,
              height: 22,
              decoration: BoxDecoration(
                color: MenuPalette.play,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 2.4),
              ),
              alignment: const Alignment(0.5, 0),
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
