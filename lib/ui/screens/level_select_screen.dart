import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/menu_audio.dart';
import '../../data/progress_store.dart';
import '../chapters.dart';
import '../home_scene/sky_art.dart';
import '../menu_palette.dart';
import '../widgets/bubble_text.dart';
import '../widgets/pressable.dart';
import '../widgets/star_row.dart';
import 'game_screen.dart';

/// Grid geometry, worked out the same way the sliver delegate does it.
///
/// With ten thousand levels the grid has to open where the player actually
/// is, and that means knowing which row a level lands on before anything is
/// laid out.
class _Grid {
  const _Grid(this.columns, this.rowHeight);

  static const double maxTileWidth = 108;
  static const double spacing = 12;
  static const double aspectRatio = 0.95;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 12, 20, 32);

  static const double headerHeight = 42;

  final int columns;
  final double rowHeight;

  /// Rows one chapter takes. Fifty levels never divide evenly by the seven or
  /// eight columns a phone fits, which is exactly why a chapter needs a break
  /// of its own: without one it starts in the middle of a row and there is
  /// nothing on screen that says so.
  int get chapterRows => (kChapterSize / columns).ceil();

  /// A header plus its rows. Every chapter is the same height, which is what
  /// lets the list use a fixed extent: a jump to level 8,472 is arithmetic
  /// rather than a walk through eight thousand tiles.
  double get blockHeight => headerHeight + chapterRows * rowHeight;

  factory _Grid.forWidth(double width) {
    final inner = width - padding.horizontal;
    // The same formula SliverGridDelegateWithMaxCrossAxisExtent uses.
    final columns = ((inner + spacing) / (maxTileWidth + spacing)).ceil().clamp(
      1,
      64,
    );
    final tileWidth = (inner - spacing * (columns - 1)) / columns;
    return _Grid(columns, tileWidth / aspectRatio + spacing);
  }

  /// Where the top of [chapter]'s block sits in the scroll.
  double _topOf(int chapter) => padding.top + (chapter - 1) * blockHeight;

  double _clamp(double target, double viewportHeight, int itemCount) {
    final chapters = (itemCount / kChapterSize).ceil();
    final content = chapters * blockHeight + padding.vertical;
    return target.clamp(0.0, max(0.0, content - viewportHeight));
  }

  /// Scroll offset that puts [index] in the middle of a [viewportHeight] tall
  /// viewport, clamped so it never scrolls past either end.
  double offsetFor(int index, double viewportHeight, int itemCount) {
    final row = (index % kChapterSize) ~/ columns;
    final target =
        _topOf(chapterFor(index + 1)) +
        headerHeight +
        row * rowHeight -
        viewportHeight / 2 +
        rowHeight / 2;
    return _clamp(target, viewportHeight, itemCount);
  }

  /// Scroll offset that puts [chapter]'s header just under the top edge.
  ///
  /// Stepping a chapter is asking to see where one starts, so it lands on the
  /// header rather than centring the first level and leaving the header off
  /// the top of the screen.
  double chapterTop(int chapter, double viewportHeight, int itemCount) =>
      _clamp(_topOf(chapter) - padding.top, viewportHeight, itemCount);
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
  ///
  /// Works off the count rather than the pack, because ids run 1 to [count]
  /// with no gaps — the authoring tool refuses to write a pack where they do
  /// not. That is what lets a ten thousand tile grid be built without reading
  /// a single level.
  int _currentIndex(int count) {
    for (var i = 0; i < count; i++) {
      if (!progressStore.isSolved(i + 1)) return i;
    }
    return count - 1;
  }

  /// Which chapter the header is naming.
  ///
  /// Null until the player steps it, so the bar opens on the chapter they are
  /// actually in rather than on chapter one. Stepping it scrolls the grid;
  /// scrolling the grid does not step it back, because a header that changes
  /// under a moving thumb is a header nobody can aim at.
  int? _shownChapter;

  void _goTo(int levelId, int count, _Grid grid, double viewportHeight) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      grid.offsetFor(levelId - 1, viewportHeight, count),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _stepChapter(int by, int count, _Grid grid, double viewportHeight) {
    final last = chapterFor(count);
    final from = _shownChapter ?? chapterFor(_currentIndex(count) + 1);
    final to = (from + by).clamp(1, last);
    if (to == from) return;
    MenuAudio.instance.tap();
    setState(() => _shownChapter = to);
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      grid.chapterTop(to, viewportHeight, count),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// A number to jump to. At ten thousand levels, stepping a chapter at a time
  /// is still two hundred presses from one end of the pack to the other.
  Future<void> _askForLevel(
    BuildContext context,
    int count,
    _Grid grid,
    double viewportHeight,
  ) async {
    final controller = TextEditingController();
    final wanted = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MenuPalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Go to level',
          style: TextStyle(color: MenuPalette.ink, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: MenuPalette.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            hintText: '1 to $count',
            hintStyle: const TextStyle(color: MenuPalette.inkSoft),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (wanted == null || wanted < 1 || wanted > count || !mounted) return;
    setState(() => _shownChapter = chapterFor(wanted));
    _goTo(wanted, count, grid, viewportHeight);
  }

  /// Loads the tapped level, then replaces this screen with it.
  ///
  /// The tile is built from an id alone, so the level itself is not in hand
  /// when it is tapped. Reading its shard is a few hundred kilobytes off the
  /// bundle, which is quick enough that a spinner would only flicker.
  Future<void> _open(BuildContext context, int levelId) async {
    final navigator = Navigator.of(context);
    final opening = await openingFor(levelId);
    if (opening == null || !context.mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen(level: opening.level, levelCount: opening.levelCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MenuPalette.skyLow,
      // No app bar. It carried the title and the star total on a flat band of
      // sky colour, which meant two header rows stacked on a screen that has
      // 360 points of height: the bar, then the chapter row under it. One row
      // holds all of it and gives the grid back forty points.
      extendBodyBehindAppBar: true,
      // The keyboard the jump dialog raises would otherwise take a third of
      // the page's height, reflowing the grid behind a dialog that covers it.
      // It floats over instead; the dialog has its own route and lifts itself
      // clear of the keyboard regardless.
      resizeToAvoidBottomInset: false,
      // The same sky and hills the home screen stands on, so the grid is a
      // page of that world rather than a settings list in its colours.
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LevelsBackdrop(),
          SafeArea(
              child: FutureBuilder<int>(
                future: levelRepository.count(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: MenuPalette.play),
                    );
                  }
                  final count = snapshot.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final grid = _Grid.forWidth(constraints.maxWidth);

                      // Open on the level the player is actually on. Without this a
                      // pack this long always starts ten thousand tiles away from
                      // wherever they got to.
                      if (!_positioned) {
                        _positioned = true;
                        _controller = ScrollController(
                          initialScrollOffset: grid.offsetFor(
                            _currentIndex(count),
                            constraints.maxHeight,
                            count,
                          ),
                        );
                      }

                      return AnimatedBuilder(
                        animation: progressStore,
                        builder: (context, _) {
                          final next = _currentIndex(count) + 1;
                          return Column(
                            children: [
                              _ChapterBar(
                                shown: _shownChapter ?? chapterFor(next),
                                count: count,
                                stars: progressStore.totalStars,
                                onBack: () => Navigator.of(context).maybePop(),
                                onStep: (by) => _stepChapter(
                                  by,
                                  count,
                                  grid,
                                  constraints.maxHeight,
                                ),
                                onJump: () => _askForLevel(
                                  context,
                                  count,
                                  grid,
                                  constraints.maxHeight,
                                ),
                              ),
                              // One list of chapters rather than one grid of
                              // ten thousand tiles. Fifty levels never divide
                              // evenly by the columns a phone fits, so a flat
                              // grid starts chapter two in the middle of a row
                              // with nothing on screen to say so.
                              //
                              // `itemExtent` is what keeps it cheap: every
                              // chapter is the same height, so the list can
                              // put the thumb at chapter 170 without building
                              // the 169 before it, exactly as the flat grid
                              // could.
                              Expanded(
                                child: ListView.builder(
                                  controller: _controller,
                                  // Springy rather than the flat Android
                                  // clamp. A list that pushes back at its ends
                                  // is the only thing a scroll can say about
                                  // where it has got to.
                                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                  padding: _Grid.padding,
                                  itemExtent: grid.blockHeight,
                                  itemCount: (count / kChapterSize).ceil(),
                                  itemBuilder: (context, block) => _Chapter(
                                    chapter: block + 1,
                                    count: count,
                                    next: next,
                                    onOpen: (id) => _open(context, id),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

}

/// Sky and hills, the first frame of the menu scene without the cast in it.
///
/// Painted rather than a flat gradient so this page stands in the same world
/// the home screen does. Still, and only the two layers that are scenery: a
/// mascot waving at a grid of ten thousand tiles would be one thing too many.
class _LevelsBackdrop extends StatelessWidget {
  const _LevelsBackdrop();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BackdropPainter(), child: const SizedBox.expand());
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintSky(canvas, size, 0);
    paintHills(canvas, size, 0);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

/// Where in the pack you are looking, and a way to be somewhere else.
///
/// Ten thousand tiles in one scroll has no handles on it: the grid opens on
/// the right level and after that the only way to reach anything is a thumb.
/// A chapter step covers fifty at a time and the jump covers the rest.
class _ChapterBar extends StatelessWidget {
  const _ChapterBar({
    required this.shown,
    required this.count,
    required this.stars,
    required this.onStep,
    required this.onJump,
    required this.onBack,
  });

  final int shown;
  final int count;
  final int stars;
  final void Function(int by) onStep;
  final VoidCallback onJump;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A landscape phone cannot carry the wordmark, the chapter, a
        // labelled jump button and the star total on one line. Two things
        // stand down, in the order they can be spared: the jump label first,
        // since the magnifier still says what the button does, and then the
        // wordmark, since the screen it names is the one you are looking at.
        final width = constraints.maxWidth;
        return _row(jumpLabel: width >= 700, wordmark: width >= 740);
      },
    );
  }

  Widget _row({required bool jumpLabel, required bool wordmark}) {
    final first = (shown - 1) * kChapterSize + 1;
    final last = (first + kChapterSize - 1).clamp(1, count);
    final atStart = shown <= 1;
    final atEnd = last >= count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: [
          _RoundStep(icon: Icons.arrow_back_rounded, onTap: onBack, big: true),
          if (wordmark) ...[
            const SizedBox(width: 10),
            const BubbleText(
              text: 'LEVELS',
              keyline: 6,
              gradient: [
                Color(0xFF3D9BF0),
                Color(0xFF3FC9A8),
                Color(0xFF6FD44A),
                Color(0xFFFFC53D),
              ],
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(width: 10),
          // The chapter, its arrows and its range, all in one pill. It was a
          // row of its own under the app bar, which on a 360 point screen cost
          // two of the grid's rows to say one line.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: MenuPalette.ink.withValues(alpha: 0.16),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundStep(
                  icon: Icons.chevron_left_rounded,
                  onTap: atStart ? null : () => onStep(-1),
                  tint: MenuPalette.levels,
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'CHAPTER $shown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MenuPalette.ink,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _RoundStep(
                  icon: Icons.chevron_right_rounded,
                  onTap: atEnd ? null : () => onStep(1),
                  tint: MenuPalette.levels,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onJump,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: MenuPalette.inkSoft,
                    ),
                    if (jumpLabel) ...[
                      const SizedBox(width: 7),
                      const Text(
                        'Go to level',
                        style: TextStyle(
                          color: MenuPalette.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Pushed to the edge. It is a total, not part of the navigation, and
          // sitting against the jump button it read as another control.
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 5, 13, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: MenuPalette.ink.withValues(alpha: 0.16),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: MenuPalette.gold,
                ),
                const SizedBox(width: 7),
                Text(
                  '$stars',
                  style: const TextStyle(
                    color: MenuPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({
    required this.icon,
    required this.onTap,
    this.big = false,
    this.tint,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// What colour the glyph is when it can be pressed. The chapter arrows are
  /// blue so the pair reads as the control and the label between them as the
  /// state it is showing.
  final Color? tint;

  /// The back button, which stands on the sky on its own and so gets the same
  /// moulded tile the home screen gives its two corner buttons. The chapter
  /// arrows sit inside a pill already and stay flat.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    final colour = live
        ? (tint ?? MenuPalette.ink)
        : (tint ?? MenuPalette.inkSoft).withValues(alpha: 0.28);

    if (big) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
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
                BoxShadow(color: Color(0xFFA8BFCC), offset: Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: const Color(0xFF4A6C7C)),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 24, color: colour),
        ),
      ),
    );
  }
}

/// One chapter: a header saying which, then its fifty tiles.
class _Chapter extends StatelessWidget {
  const _Chapter({
    required this.chapter,
    required this.count,
    required this.next,
    required this.onOpen,
  });

  final int chapter;

  /// Levels in the pack, so the last chapter can be short without the list
  /// having to know anything about it.
  final int count;

  final int next;
  final void Function(int levelId) onOpen;

  @override
  Widget build(BuildContext context) {
    final first = (chapter - 1) * kChapterSize + 1;
    final tiles = min(kChapterSize, count - first + 1);

    return Column(
      children: [
        SizedBox(
          height: _Grid.headerHeight,
          child: _ChapterHeader(chapter: chapter, first: first),
        ),
        Expanded(
          child: GridView.builder(
            // The block is a fixed height and the list scrolls it, so this
            // grid must not try to scroll as well: two scrollables inside each
            // other is a thumb that never quite goes where it was sent.
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _Grid.maxTileWidth,
              crossAxisSpacing: _Grid.spacing,
              mainAxisSpacing: _Grid.spacing,
              childAspectRatio: _Grid.aspectRatio,
            ),
            itemCount: tiles,
            itemBuilder: (context, i) {
              final id = first + i;
              return _ArriveIn(
                // Staggered along the row, so a chapter lands as a sweep
                // rather than as one block appearing at once.
                delay: Duration(milliseconds: 18 * (i % kChapterSize)),
                child: _LevelTile(
                  levelId: id,
                  stars: progressStore.starsFor(id),
                  bestSeconds: progressStore.bestSecondsFor(id),
                  unlocked: progressStore.isUnlocked(id),
                  isNext: id == next,
                  onTap: () => onOpen(id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A rule across the grid with the chapter named in the middle of it.
///
/// The header bar at the top of the page names a chapter too, but that one
/// answers "which chapter am I looking at"; this one answers "where does it
/// begin", which is the question a thumb has while it is scrolling.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter, required this.first});

  final int chapter;

  /// The first level in it, which is what decides the band: chapter 6 holds
  /// the boundary at level 300, so the band cannot be read off the chapter
  /// number alone.
  final int first;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _Rule()),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: MenuPalette.ink.withValues(alpha: 0.18),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            'CHAPTER $chapter  ·  ${bandFor(first)}',
            style: const TextStyle(
              color: MenuPalette.ink,
              fontSize: 10,
              height: 1.3,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Expanded(child: _Rule()),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Fades and lifts its child in once, [delay] after it is first built.
///
/// The grid is lazy, so a tile is built the moment it comes near the viewport
/// and this runs as it arrives — which is what makes scrolling a chapter feel
/// like the tiles are coming to meet you rather than like a page of them was
/// already there and the window merely moved.
///
/// Once only. It plays on the way in and never again, so scrolling back over
/// a tile does not make it flash a second time.
class _ArriveIn extends StatefulWidget {
  const _ArriveIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_ArriveIn> createState() => _ArriveInState();
}

class _ArriveInState extends State<_ArriveIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  Timer? _wait;

  @override
  void initState() {
    super.initState();
    // Held so it can be cancelled. A grid of ten thousand tiles builds and
    // throws away a lot of these while a thumb is moving, and a delay that
    // outlives its tile is a callback into a disposed widget.
    _wait = Timer(widget.delay, _in.forward);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        // Clamped, because easeOutBack overshoots past one and an opacity
        // over one throws.
        opacity: _in.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - curve.value)),
          child: Transform.scale(scale: 0.88 + 0.12 * curve.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.levelId,
    required this.stars,
    required this.bestSeconds,
    required this.unlocked,
    required this.isNext,
    required this.onTap,
  });

  final int levelId;
  final int stars;
  final double? bestSeconds;
  final bool unlocked;

  /// The first level not yet solved. Exactly one tile in the grid has this,
  /// which is what makes it findable in a wall of ten thousand.
  final bool isNext;

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
      // Opaque enough to sit on the scenery rather than in it. At a third
      // white the hills and the flowers behind the grid read straight through
      // a locked tile, and a row of them stopped looking like tiles at all.
      fill = Colors.white.withValues(alpha: 0.62);
      edge = Colors.white.withValues(alpha: 0.5);
    } else if (solved) {
      fill = MenuPalette.play;
      edge = const Color(0xFF3F8A1D);
    } else {
      fill = Colors.white;
      edge = const Color(0xFFBFD8E4);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: unlocked
            ? [BoxShadow(color: edge, offset: const Offset(0, 5))]
            : null,
      ),
      child: Pressable(
        // Null on a locked tile: it must not answer a tap it is going to
        // ignore, which is a promise the tile cannot keep.
        onPressed: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                // The next level is the only ringed tile on the page, which is
                // what lets an eye find it in a grid of ten thousand.
                color: isNext
                    ? MenuPalette.play
                    : Colors.white.withValues(alpha: solved ? 0.7 : 0.9),
                width: isNext ? 3 : 2,
              ),
            ),
            // Expand, not the default. A loose Stack sizes a non positioned
            // child to its own content and pins it top left, which is why the
            // level numbers were sitting in the corner of every tile rather
            // than in the middle of it.
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The moulded highlight the buttons have, so a tile reads as
                // the same material as the slab that opened this page.
                Positioned(
                  left: 6,
                  right: 6,
                  top: 3,
                  height: 26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: unlocked ? 0.4 : 0.14),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The number, then one line underneath saying how you
                    // stand with the level: the stars earned on it, or a
                    // padlock if it is not open yet.
                    Text(
                      '$levelId',
                      style: TextStyle(
                        color: solved
                            ? Colors.white
                            : MenuPalette.ink.withValues(
                                alpha: unlocked ? 1 : 0.34,
                              ),
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    // A locked tile puts the padlock exactly where the stars
                    // would have been, so every tile in a row shares one
                    // centre line and the lock lands where the eye is already
                    // looking for the reward.
                    //
                    // It is drawn in the number's own faded ink rather than a
                    // colour of its own. Locked is a state to read at a
                    // glance, not something to be told off about, and a row of
                    // thirteen loud padlocks is why there was none here
                    // before.
                    const SizedBox(height: 6),
                    if (!unlocked)
                      Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: MenuPalette.ink.withValues(alpha: 0.34),
                      )
                    else ...[
                      StarRow(stars: stars, size: 20),
                      if (bestSeconds != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${bestSeconds!.toStringAsFixed(1)}s',
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
                    ],
                  ],
                ),
                if (isNext)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(9, 2, 9, 3),
                        decoration: const BoxDecoration(
                          color: MenuPalette.play,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'NEXT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
