import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../palette.dart';
import '../widgets/star_row.dart';
import 'game_screen.dart';

/// Grid geometry, worked out the same way the sliver delegate does it.
///
/// With fifteen hundred levels the grid has to open where the player actually
/// is, and that means knowing which row a level lands on before anything is
/// laid out.
class _Grid {
  const _Grid(this.columns, this.rowHeight);

  static const double maxTileWidth = 108;
  static const double spacing = 12;
  static const double aspectRatio = 0.95;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 12, 20, 32);

  final int columns;
  final double rowHeight;

  factory _Grid.forWidth(double width) {
    final inner = width - padding.horizontal;
    // The same formula SliverGridDelegateWithMaxCrossAxisExtent uses.
    final columns =
        ((inner + spacing) / (maxTileWidth + spacing)).ceil().clamp(1, 64);
    final tileWidth = (inner - spacing * (columns - 1)) / columns;
    return _Grid(columns, tileWidth / aspectRatio + spacing);
  }

  /// Scroll offset that puts [index] in the middle of a [viewportHeight] tall
  /// viewport, clamped so it never scrolls past either end.
  double offsetFor(int index, double viewportHeight, int itemCount) {
    final row = index ~/ columns;
    final rows = (itemCount / columns).ceil();
    final content = rows * rowHeight + padding.vertical;
    final target =
        padding.top + row * rowHeight - viewportHeight / 2 + rowHeight / 2;
    return target.clamp(0.0, max(0.0, content - viewportHeight));
  }
}

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  ScrollController? _controller;

  /// Set once, the first time the levels arrive, so rebuilds from the progress
  /// store never yank the list back under the player's thumb.
  bool _positioned = false;

  /// The scroll position is owned here rather than left to the default, so it
  /// survives the rebuilds the progress store triggers.

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// The level the player is actually on: the first one they have not solved.
  int _currentIndex(List<LevelModel> levels) {
    for (var i = 0; i < levels.length; i++) {
      if (!progressStore.isSolved(levels[i].id)) return i;
    }
    return levels.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      appBar: AppBar(
        backgroundColor: Palette.background,
        elevation: 0,
        foregroundColor: Palette.text,
        title: const Text(
          'LEVELS',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 4,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: progressStore,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Palette.star),
                  const SizedBox(width: 6),
                  Text(
                    '${progressStore.totalStars}',
                    style: const TextStyle(
                      color: Palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<LevelModel>>(
        future: levelRepository.loadAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Palette.textMuted),
            );
          }
          final levels = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final grid = _Grid.forWidth(constraints.maxWidth);

              // Open on the level the player is actually on. Without this a
              // pack this long always starts fifteen hundred tiles away from
              // wherever they got to.
              if (!_positioned) {
                _positioned = true;
                _controller = ScrollController(
                  initialScrollOffset: grid.offsetFor(
                    _currentIndex(levels),
                    constraints.maxHeight,
                    levels.length,
                  ),
                );
              }

              return AnimatedBuilder(
                animation: progressStore,
                builder: (context, _) => GridView.builder(
                  controller: _controller,
                  padding: _Grid.padding,
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _Grid.maxTileWidth,
                    crossAxisSpacing: _Grid.spacing,
                    mainAxisSpacing: _Grid.spacing,
                    childAspectRatio: _Grid.aspectRatio,
                  ),
                  itemCount: levels.length,
                  itemBuilder: (context, index) => _LevelTile(
                    level: levels[index],
                    stars: progressStore.starsFor(levels[index].id),
                    bestSeconds:
                        progressStore.bestSecondsFor(levels[index].id),
                    unlocked: progressStore.isUnlocked(levels[index].id),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            GameScreen(levels: levels, index: index),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.stars,
    required this.bestSeconds,
    required this.unlocked,
    required this.onTap,
  });

  final LevelModel level;
  final int stars;
  final double? bestSeconds;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final solved = stars > 0;
    return Material(
      color: unlocked ? Palette.surface : Palette.surface.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: solved
                  ? Palette.door.withValues(alpha: 0.35)
                  : Palette.text.withValues(alpha: unlocked ? 0.1 : 0.04),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked)
                Icon(
                  Icons.lock_rounded,
                  size: 22,
                  color: Palette.textMuted.withValues(alpha: 0.5),
                )
              else
                Text(
                  '${level.id}',
                  style: TextStyle(
                    color: solved ? Palette.door : Palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              if (unlocked)
                StarRow(stars: stars, size: 15)
              else
                const SizedBox(height: 15),
              const SizedBox(height: 3),
              Text(
                bestSeconds == null ? ' ' : '${bestSeconds!.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
