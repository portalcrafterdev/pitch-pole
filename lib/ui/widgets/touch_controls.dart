import 'package:flutter/material.dart';

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

/// Up and down on the left, jump on the right. The flips are absolute here,
/// exactly like the arrow keys: pressing the surface you are already on does
/// nothing, so there is no toggle to lose track of.
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
    return SafeArea(
      // The game runs full bleed, so the reported insets are zero and a pad
      // would sit right on the bottom edge, where the system's back and home
      // gestures live. A press meant for jump would leave the game.
      minimum: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pad(
                icon: Icons.keyboard_double_arrow_up_rounded,
                label: showHints ? 'CEILING' : null,
                accent: Palette.door,
                // The one you are already on is shown as spent, so the pair
                // reads as a state rather than as two identical buttons.
                current: gravityUp,
                onTap: enabled ? () => onInput(RunInput.flipUp) : null,
              ),
              const SizedBox(height: 10),
              _Pad(
                icon: Icons.keyboard_double_arrow_down_rounded,
                label: showHints ? 'FLOOR' : null,
                accent: Palette.door,
                current: !gravityUp,
                onTap: enabled ? () => onInput(RunInput.flipDown) : null,
              ),
            ],
          ),
          // Inert: in this scheme only the pads take a tap.
          const Expanded(child: SizedBox.expand()),
          _Pad(
            icon: Icons.height_rounded,
            label: showHints ? 'JUMP' : null,
            accent: Palette.text,
            size: 84,
            onTap: enabled ? () => onInput(RunInput.jump) : null,
          ),
        ],
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
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? label;
  final double size;

  /// True when pressing this would do nothing, because the character is
  /// already on that surface.
  final bool current;

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.size,
            height: widget.size,
            transform: _down
                ? (Matrix4.identity()..scaleByDouble(0.92, 0.92, 1, 1))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: _down ? 0.30 : 0.13),
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
          if (widget.label != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.label!,
              style: TextStyle(
                color: accent.withValues(alpha: 0.45),
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}