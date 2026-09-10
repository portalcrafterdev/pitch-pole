import 'package:flutter/material.dart';

import '../../data/menu_audio.dart';
import '../menu_palette.dart';
import 'tap_ring.dart';

/// A tap target that visibly gives under a thumb.
///
/// The slabs in [PanelButton] already do this: their lip loses five points on
/// the press and the top face travels down into it, which is the whole reason
/// they read as objects. Everything else in the menus was an [InkWell] — and a
/// Material ripple on a white card under a bright sky is close to invisible,
/// so the round tiles, the level tiles and the swatches all took a tap and
/// showed nothing for it.
///
/// A scale rather than a ripple, for the same reason the slabs use a lip: a
/// thing that moves when pressed reads as a thing you pressed, and it works
/// the same on a green tile, a white card and a faded locked one.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.scale = 0.94,
    this.borderRadius,
    this.ringColour = MenuPalette.ink,
  });

  final Widget child;

  /// Null leaves the target inert and the press dead, which is what a locked
  /// level tile wants: it must not answer a tap it is going to ignore.
  final VoidCallback? onPressed;

  /// How far it gives. Small targets need less travel to read than large ones.
  final double scale;

  /// Clips the ring to the shape, so a round tile does not throw a square of
  /// colour past its own corners.
  final BorderRadius? borderRadius;

  /// The ring drawn out of the finger. Ink by default, which sits on the pale
  /// cards and the green tiles alike.
  final Color ringColour;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  bool _down = false;

  /// Where the last tap landed, and how far its ring has opened. The scale
  /// says the button took the press; the ring says where the finger was.
  Offset? _at;
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: kTapRingDuration,
  );

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _set(bool down) {
    if (widget.onPressed == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque, so a gap inside the child is still the button. A small target
      // with holes in it is a small target.
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        if (widget.onPressed == null) return;
        // On the press rather than the release, so the sound lands with the
        // button going down. A blip that waits for the finger to lift reads
        // as a delay rather than as feedback.
        MenuAudio.instance.tap();
        _at = details.localPosition;
        _ring.forward(from: 0);
        _set(true);
      },
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            widget.child,
            // Sized to the child and clipped to its shape, behind an
            // [IgnorePointer] so the thing drawn to acknowledge a tap can
            // never swallow the next one.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: widget.borderRadius ?? BorderRadius.zero,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _ring,
                      builder: (context, _) => CustomPaint(
                        painter: TapRingPainter(
                          at: _at,
                          progress: _ring.value,
                          colour: widget.ringColour,
                          radius: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
