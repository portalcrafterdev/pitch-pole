import 'package:flutter/material.dart';

import '../menu_palette.dart';

/// Three stars, earned ones filled. [animate] pops them in one after another.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.stars,
    this.size = 22,
    this.animate = false,
  });

  final int stars;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < stars;
        final star = Icon(
          earned ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          // Every surface a star lands on is a white card now, so an unearned
          // one is drawn in ink rather than in the muted green that was picked
          // to sit on a near black panel.
          color: earned
              ? MenuPalette.gold
              : MenuPalette.inkSoft.withValues(alpha: 0.35),
        );
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
