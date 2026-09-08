import 'package:flutter/material.dart';

import '../menu_palette.dart';

/// Three stars, earned ones filled. [animate] pops them in one after another.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.stars,
    this.size = 22,
    this.animate = false,
    this.keyline = false,
  });

  final int stars;
  final double size;
  final bool animate;

  /// A white outline around each star, so a row of them reads as the reward
  /// rather than as three icons. Only the big row on the cleared panel wants
  /// it; at tile size the outline eats the star.
  final bool keyline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < stars;
        // Every surface a star lands on is a white card now, so an unearned
        // one is drawn in ink rather than in the muted green that was picked
        // to sit on a near black panel.
        final fill = earned
            ? MenuPalette.gold
            : (keyline
                ? const Color(0xFFDCE8EE)
                : MenuPalette.inkSoft.withValues(alpha: 0.35));
        final glyph = keyline || earned
            ? Icons.star_rounded
            : Icons.star_outline_rounded;

        Widget star = Icon(glyph, size: size, color: fill);
        if (keyline) {
          star = Stack(
            alignment: Alignment.center,
            children: [
              // The outline is a second, larger glyph painted underneath. An
              // icon has no stroke of its own, and a shadow ring would soften
              // where a keyline has to be hard.
              Icon(glyph, size: size * 1.16, color: Colors.white),
              Icon(glyph, size: size, color: fill),
            ],
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.06),
          child: animate && earned
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + i * 140),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: star,
                )
              : star,
        );
      }),
    );
  }
}
