import 'package:flutter/material.dart';

import '../../game/logic/run_state.dart';
import '../palette.dart';

/// The shipping control scheme: the left half of the screen flips, the right
/// half jumps. Every touch target is half the screen, so there is nothing
/// small to miss.
///
/// The flip is a toggle here, because there is no room for two separate flip
/// pads. On a keyboard the flips stay absolute.
class TouchControls extends StatelessWidget {
  const TouchControls({
    super.key,
    required this.onInput,
    required this.gravityUp,
    this.enabled = true,
    this.showHints = false,
  });

  final void Function(RunInput input) onInput;

  /// Which way the character is pulled right now, so the flip half can say
  /// where it will send you.
  final bool gravityUp;

  final bool enabled;

  /// The first level shows what the halves do, once.
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
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 30,
                      color: widget.accent.withValues(alpha: 0.28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.accent.withValues(alpha: 0.28),
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
