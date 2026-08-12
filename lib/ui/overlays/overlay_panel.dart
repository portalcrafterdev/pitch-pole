import 'package:flutter/material.dart';

import '../../data/menu_audio.dart';
import '../menu_palette.dart';
import '../palette.dart';

/// The shared look for every full screen overlay.
class OverlayPanel extends StatelessWidget {
  const OverlayPanel({
    super.key,
    required this.title,
    this.accent = Palette.text,
    this.subtitle,
    this.child,
    required this.actions,
    this.onDismiss,
  });

  final String title;
  final Color accent;
  final String? subtitle;
  final Widget? child;
  final List<Widget> actions;

  /// What tapping the screen around the panel does, if anything.
  ///
  /// Only the pause menu sets this. Losing a life or finishing a level is a
  /// thing that happened to the player and has to be acknowledged, so those
  /// two panels are deliberately not dismissible: there is nothing to go back
  /// to behind them, and a stray tap on a dead screen should not choose
  /// between retry and quit on the player's behalf.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scrim = Container(
      color: Palette.background.withValues(alpha: 0.88),
      child: Center(
        child: SingleChildScrollView(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 16),
                child: child,
              ),
            ),
            // Swallows taps that land on the panel itself, so only the screen
            // around it dismisses. The buttons still work: of two tap
            // recognizers over the same pixel the innermost one takes the
            // gesture, and every button is deeper than this.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Palette.textMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 20),
                      child!,
                    ],
                    const SizedBox(height: 24),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (onDismiss == null) return scrim;

    return GestureDetector(
      // Opaque, so the tap is consumed here rather than falling through to the
      // touch controls underneath. With the halves scheme the whole screen is
      // a control, and a tap that both resumed the run and flipped gravity
      // would drop the player through the floor the instant they came back.
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: scrim,
    );
  }
}

/// Primary action inside an overlay, and the only button shape the game uses.
///
/// It is a solid slab with a hard lip under it rather than an outline, and it
/// sinks onto that lip when pressed. That is worth the few extra lines: an
/// outlined button asks the player to know that an outline means "tappable",
/// and the youngest player here cannot read the label to begin with. A thing
/// that looks like a physical button and visibly goes down when pushed does
/// not need reading.
class PanelButton extends StatefulWidget {
  const PanelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.accent = Palette.text,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final Color accent;

  /// Shorter, for a landscape phone where the whole page has to fit in about
  /// 340 points of height.
  final bool compact;

  @override
  State<PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<PanelButton> {
  bool _down = false;

  /// The lip the button sits on, and the shade the fill darkens to.
  static Color _deepen(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    // Opaque either way, and that is not a style choice. The lip below is a
    // hard edged shadow rather than a blurred one, and it sits only a few
    // points behind the face, so a translucent face lets the lip show straight
    // through the whole button and the slab comes out the colour of its own
    // shadow. Blended against the panel it lands on instead.
    final fill = widget.filled
        ? accent
        : Color.alphaBlend(accent.withValues(alpha: 0.14), Palette.surface);

    // Taken off the fill rather than off the accent, so a quiet button on a
    // dark panel gets a lip darker than itself instead of a pale one.
    final lip = widget.filled ? _deepen(accent, 0.16) : _deepen(fill, 0.05);

    // White on a pale fill is the usual way a bright design becomes
    // unreadable, so the label picks its own colour off the fill it lands on
    // rather than trusting the caller to have chosen a dark enough accent.
    final onFill = !widget.filled
        ? accent
        : (fill.computeLuminance() > 0.45 ? MenuPalette.ink : Colors.white);

    final lipDepth = _down ? 2.0 : (widget.compact ? 5.0 : 6.0);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 8 : 10),
      child: GestureDetector(
        // Opaque, so the gap between the icon and the label is still the
        // button. A small target with holes in it is a small target.
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          // On the press rather than on the release, so the sound lands with
          // the button going down. A blip that waits for the finger to lift
          // reads as a delay rather than as feedback.
          MenuAudio.instance.tap();
          setState(() => _down = true);
        },
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: widget.compact ? 44 : 52,
          width: double.infinity,
          // Sinks by exactly what the lip loses, so the top face travels and
          // the bottom edge stays put.
          transform: Matrix4.translationValues(
            0,
            (widget.compact ? 5.0 : 6.0) - lipDepth,
            0,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.filled
                  ? Colors.white.withValues(alpha: 0.45)
                  : accent.withValues(alpha: 0.45),
              width: 2,
            ),
            boxShadow: [
              // Hard edged rather than blurred: this is a moulded edge, not a
              // shadow, and a blur would read as the button floating.
              BoxShadow(color: lip, offset: Offset(0, lipDepth)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: onFill),
                const SizedBox(width: 10),
              ],
              // Shrunk to fit rather than clipped or ellipsed. A label here is
              // an instruction, so losing the end of it is worse than losing a
              // point of size, and a long one overflowed the row outright
              // before this.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: onFill,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
