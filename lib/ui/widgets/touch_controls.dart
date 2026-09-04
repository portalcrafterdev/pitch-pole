import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/progress_store.dart';
import '../../game/logic/run_state.dart';
import '../palette.dart';

/// Touch input, in whichever of the two schemes the player picked.
///
/// The schemes never overlap. In [ControlScheme.halves] the whole screen is
/// two targets and there are no buttons at all; in [ControlScheme.buttons]
/// only the pads take a tap and the rest of the screen is inert. A thumb
/// resting on dead screen must never flip you into a blade.
class TouchControls extends StatelessWidget {
  const TouchControls({
    super.key,
    required this.onInput,
    required this.gravityUp,
    this.scheme = ControlScheme.halves,
    this.enabled = true,
    this.showHints = false,
  });

  final void Function(RunInput input) onInput;

  /// Which way the character is pulled right now, so the controls can say
  /// where they will send you.
  final bool gravityUp;

  final ControlScheme scheme;
  final bool enabled;

  /// The first level labels the controls, once.
  final bool showHints;

  @override
  Widget build(BuildContext context) => switch (scheme) {
        ControlScheme.halves => _Halves(
            onInput: onInput,
            gravityUp: gravityUp,
            enabled: enabled,
            showHints: showHints,
          ),
        ControlScheme.buttons => _Buttons(
            onInput: onInput,
            gravityUp: gravityUp,
            enabled: enabled,
            showHints: showHints,
          ),
      };
}

/// The left half of the screen flips, the right half jumps. Every target is
/// half the screen, so there is nothing small to miss.
///
/// The flip is a toggle here, because a half cannot say which way it goes. On
/// a keyboard, and on the buttons, the flips stay absolute.
class _Halves extends StatelessWidget {
  const _Halves({
    required this.onInput,
    required this.gravityUp,
    required this.enabled,
    required this.showHints,
  });

  final void Function(RunInput input) onInput;
  final bool gravityUp;
  final bool enabled;
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Half(
            label: gravityUp ? 'FLIP DOWN' : 'FLIP UP',
            icon: gravityUp
                ? Icons.keyboard_double_arrow_down_rounded
                : Icons.keyboard_double_arrow_up_rounded,
            accent: Palette.door,
            showHint: showHints,
            onTap: enabled
                ? () => onInput(
                      gravityUp ? RunInput.flipDown : RunInput.flipUp,
                    )
                : null,
          ),
        ),
        Expanded(
          child: _Half(
            label: 'JUMP',
            icon: Icons.height_rounded,
            accent: Palette.text,
            showHint: showHints,
            onTap: enabled ? () => onInput(RunInput.jump) : null,
          ),
        ),
      ],
    );
  }
}

class _Half extends StatefulWidget {
  const _Half({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    required this.showHint,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool showHint;

  @override
  State<_Half> createState() => _HalfState();
}

class _HalfState extends State<_Half> {
  double _flash = 0;

  void _tap() {
    widget.onTap?.call();
    if (widget.onTap == null) return;
    setState(() => _flash = 1);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _flash = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: widget.accent.withValues(alpha: 0.10 * _flash),
        child: widget.showHint
            // Low in the frame, over the earth below the floor line rather
            // than across the band. A label in the middle of the play area
            // competes with the obstacles the player is meant to be reading.
            ? Align(
                alignment: const Alignment(0, 0.78),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 24,
                      color: widget.accent.withValues(alpha: 0.30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.accent.withValues(alpha: 0.30),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// Three pads, wherever the player has put them. Up and down on the left and
/// jump on the right to begin with, but none of that is fixed: each pad is
/// dragged to its own spot in the arrange screen and kept there.
///
/// The flips are absolute here, exactly like the arrow keys: pressing the
/// surface you are already on does nothing, so there is no toggle to lose
/// track of.
///
/// A pad is never dragged during a run. Every touch in a level is an input, so
/// a jump press that slid a few points would become a move instead of a jump —
/// the same failure as a thumb resting on live screen, arriving from the other
/// direction. Moving one is a deliberate trip to [ControlLayoutScreen].
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.onInput,
    required this.gravityUp,
    required this.enabled,
    required this.showHints,
  });

  final void Function(RunInput input) onInput;
  final bool gravityUp;
  final bool enabled;
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        return Stack(
          // The rest of the screen is inert: in this scheme only the pads take
          // a tap, so there is nothing here to sit under a resting thumb.
          children: [
            for (final pad in padsBackToFront(progressStore.padDiameter))
              PlacedPad(
                key: ValueKey(pad),
                pad: pad,
                spot: progressStore.padSpot(pad),
                screen: screen,
                label: showHints ? padLabel(pad) : null,
                current: switch (pad) {
                  ControlPad.ceiling => gravityUp,
                  ControlPad.floor => !gravityUp,
                  ControlPad.jump => false,
                },
                onTap: enabled ? () => onInput(padInput(pad)) : null,
              ),
          ],
        );
      },
    );
  }
}

/// How much room a pad's label takes under its circle.
const double kPadLabelHeight = 14;

/// The pads largest first, so the smallest is painted — and therefore hit
/// tested — on top.
///
/// Sizes are the player's to set, and nothing stops them putting a large pad
/// over a small one. Ordering by size means the small one always keeps its own
/// circle: it can still be pressed in a level, and still be picked up and
/// moved in the arrange screen. Painted in a fixed order instead, a big jump
/// pad could swallow a ceiling pad whole and there would be nothing left to
/// grab.
List<ControlPad> padsBackToFront(double Function(ControlPad pad) diameter) =>
    ControlPad.values.toList()
      ..sort((a, b) => diameter(b).compareTo(diameter(a)));

/// What each pad does. Absolute, exactly like the arrow keys: pressing the
/// surface you are already on does nothing, so there is no toggle to lose
/// track of.
RunInput padInput(ControlPad pad) => switch (pad) {
      ControlPad.ceiling => RunInput.flipUp,
      ControlPad.floor => RunInput.flipDown,
      ControlPad.jump => RunInput.jump,
    };

String padLabel(ControlPad pad) => switch (pad) {
      ControlPad.ceiling => 'CEILING',
      ControlPad.floor => 'FLOOR',
      ControlPad.jump => 'JUMP',
    };

Color padAccent(ControlPad pad) =>
    pad == ControlPad.jump ? Palette.text : Palette.door;

IconData padIcon(ControlPad pad) => switch (pad) {
      ControlPad.ceiling => Icons.keyboard_double_arrow_up_rounded,
      ControlPad.floor => Icons.keyboard_double_arrow_down_rounded,
      ControlPad.jump => Icons.height_rounded,
    };

/// One pad at the fractional spot the player put it, with its label hung
/// underneath rather than inside the circle.
///
/// Shared with the arrange screen so that what is dragged there and what is
/// pressed in a run are laid out by the same arithmetic. Two copies of this
/// sum would drift, and a pad that moves when you leave the editor is worse
/// than a pad that cannot be moved at all.
class PlacedPad extends StatelessWidget {
  const PlacedPad({
    super.key,
    required this.pad,
    required this.spot,
    required this.screen,
    this.onTap,
    this.label,
    this.current = false,
    this.dragging = false,
    this.diameter,
    this.onDrag,
    this.onPinch,
    this.onDrop,
  });

  final ControlPad pad;
  final Offset spot;
  final Size screen;
  final VoidCallback? onTap;
  final String? label;

  /// True when pressing this would do nothing, because the character is
  /// already on that surface.
  final bool current;

  /// Drawn lifted, for the arrange screen.
  final bool dragging;

  /// The drawn and pressed size, defaulting to whatever the player has set.
  /// The arrange screen passes its own while a pinch is in flight.
  final double? diameter;

  /// Set only by the arrange screen. In a level these stay null, so a press
  /// that slides is still a press and can never turn into a move or a resize.
  final void Function(Offset delta)? onDrag;
  final void Function(double scale)? onPinch;
  final VoidCallback? onDrop;

  @override
  Widget build(BuildContext context) {
    final size = diameter ?? progressStore.padDiameter(pad);
    final at = clampPadSpot(size, spot, screen);
    final centre = Offset(at.dx * screen.width, at.dy * screen.height);
    final half = size / 2;

    return Positioned(
      left: centre.dx - half,
      top: centre.dy - half,
      width: size,
      // Room for the label under the circle. The circle keeps its own size, so
      // where the pad reads as being and where it takes a press are the same
      // number of points; the label only widens what can be grabbed to drag.
      height: size + (label == null ? 0 : kPadLabelHeight),
      child: _Pad(
        icon: padIcon(pad),
        accent: padAccent(pad),
        size: size,
        label: label,
        current: current,
        lifted: dragging,
        onTap: onTap,
        onDrag: onDrag,
        onPinch: onPinch,
        onDrop: onDrop,
      ),
    );
  }
}

class _Pad extends StatefulWidget {
  const _Pad({
    required this.icon,
    required this.accent,
    required this.onTap,
    this.label,
    this.size = 62,
    this.current = false,
    this.lifted = false,
    this.onDrag,
    this.onPinch,
    this.onDrop,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? label;
  final double size;
  final void Function(Offset delta)? onDrag;
  final void Function(double scale)? onPinch;
  final VoidCallback? onDrop;

  /// True when pressing this would do nothing, because the character is
  /// already on that surface.
  final bool current;

  /// Drawn as picked up, while it is being dragged in the arrange screen.
  final bool lifted;

  @override
  State<_Pad> createState() => _PadState();
}

class _PadState extends State<_Pad> {
  bool _down = false;

  void _press() {
    if (widget.onTap == null) return;
    widget.onTap!();
    setState(() => _down = true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _down = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.onTap != null && !widget.current;
    final accent = widget.accent;
    final pressed = _down || widget.lifted;

    final onDrag = widget.onDrag;
    final editing = onDrag != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      // One recognizer for both, because a scale gesture is a pan gesture with
      // more fingers: a single finger reports a focal point that moves and a
      // scale of 1, and a second finger starts changing the scale. Two
      // separate recognizers would fight over the same pointers.
      onScaleStart: editing ? (_) => HapticFeedback.selectionClick() : null,
      onScaleUpdate: !editing
          ? null
          : (d) {
              if (d.pointerCount > 1) {
                widget.onPinch?.call(d.scale);
              } else {
                onDrag(d.focalPointDelta);
              }
            },
      onScaleEnd: editing ? (_) => widget.onDrop?.call() : null,
      // A stack rather than a column, because the box this sits in is exactly
      // the circle plus [kPadLabelHeight] and a column that adds up to its own
      // box to the last decimal place will overflow on the rounding.
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.size,
            height: widget.size,
            transform: switch ((_down, widget.lifted)) {
              // Down shrinks, lifted grows. A pad being dragged has to read as
              // held rather than as pressed, or the arrange screen looks like
              // it is firing inputs.
              (true, _) => Matrix4.identity()..scaleByDouble(0.92, 0.92, 1, 1),
              (_, true) => Matrix4.identity()..scaleByDouble(1.12, 1.12, 1, 1),
              _ => Matrix4.identity(),
            },
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: pressed ? 0.30 : 0.13),
              border: Border.all(
                color: accent.withValues(alpha: live ? 0.62 : 0.24),
                width: 2,
              ),
            ),
            child: Icon(
              widget.icon,
              size: widget.size * 0.46,
              color: accent.withValues(alpha: live ? 0.95 : 0.42),
            ),
          ),
          if (widget.label != null)
            Positioned(
              top: widget.size,
              left: 0,
              right: 0,
              child: Text(
                widget.label!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.45),
                  fontSize: 9,
                  height: 1.3,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}