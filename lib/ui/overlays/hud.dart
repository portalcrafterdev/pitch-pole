import 'package:flutter/material.dart';

import '../../game/logic/run_state.dart';
import '../../game/pitchpole_game.dart';
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
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  Text(
                    state.elapsed.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'LEVEL ${game.level.id}',
                    style: const TextStyle(
                      color: Palette.textMuted,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _Lives(lives: state.lives),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_rounded),
                    color: Palette.textMuted,
                    tooltip: 'Pause',
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
                  : Palette.textMuted.withValues(alpha: 0.4),
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
                  height: 3,
                  decoration: BoxDecoration(
                    color: Palette.text.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  height: 3,
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    color: Palette.door,
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
                            ? Palette.door
                            : Palette.textMuted.withValues(alpha: 0.5),
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
