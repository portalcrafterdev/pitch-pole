import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/menu_audio.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../menu_palette.dart';
import '../widgets/ad_banner.dart';
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
      backgroundColor: MenuPalette.skyLow,
      appBar: AppBar(
        // The same colour the gradient below it starts on, so the seam does
        // not show. The body deliberately does not run behind the bar: the
        // grid's top padding is fixed, and the scroll maths that opens the
        // page on the right level is derived from it, so a bar floating over
        // the top row would sit on the tiles rather than above them.
        backgroundColor: MenuPalette.skyTop,
        elevation: 0,
        foregroundColor: MenuPalette.ink,
        title: const Text(
          'LEVELS',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: progressStore,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: MenuPalette.gold),
                    const SizedBox(width: 6),
                    Text(
                      '${progressStore.totalStars}',
                      style: const TextStyle(
                        color: MenuPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Browsing, not playing: nothing here is timed and nothing is a
      // control, so it is the one screen a banner belongs on.
      bottomNavigationBar: const AdBanner(),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MenuPalette.skyTop, MenuPalette.skyMid, MenuPalette.skyLow],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: FutureBuilder<List<LevelModel>>(
          future: levelRepository.loadAll(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: MenuPalette.play),
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

    // Three states, told apart by fill before anything is read: a solved
    // level is green, an open one is white, a locked one is faded back into
    // the sky. A child scrolling this is looking for "where can I go", and
    // that answer should not depend on reading a four digit number.
    final Color fill;
    final Color edge;
    if (!unlocked) {
      fill = Colors.white.withValues(alpha: 0.34);
      edge = Colors.white.withValues(alpha: 0.45);
    } else if (solved) {
      fill = MenuPalette.play;
      edge = const Color(0xFF15A257);
    } else {
      fill = Colors.white;
      edge = const Color(0xFFBFD8E4);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: unlocked
            ? [BoxShadow(color: edge, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: unlocked
              ? () {
                  MenuAudio.instance.tap();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: solved
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!unlocked)
                  Icon(
                    Icons.lock_rounded,
                    size: 22,
                    color: MenuPalette.ink.withValues(alpha: 0.35),
                  )
                else
                  Text(
                    '${level.id}',
                    style: TextStyle(
                      color: solved ? Colors.white : MenuPalette.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const SizedBox(height: 6),
                if (unlocked)
                  StarRow(stars: stars, size: 15)
                else
                  const SizedBox(height: 15),
                const SizedBox(height: 3),
                Text(
                  bestSeconds == null
                      ? ' '
                      : '${bestSeconds!.toStringAsFixed(1)}s',
                  style: TextStyle(
                    color: solved
                        ? Colors.white.withValues(alpha: 0.9)
                        : MenuPalette.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
