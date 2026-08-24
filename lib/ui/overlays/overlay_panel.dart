import 'package:flutter/material.dart';

import '../../data/menu_audio.dart';
import '../menu_palette.dart';
import '../palette.dart';

/// Below this, the screen is a landscape phone and height is the scarce thing.
const double _shortViewport = 460;

/// And this much width is enough to put the buttons beside the panel's content
/// rather than under it.
const double _wideViewport = 560;

/// The shared look for every full screen overlay.
///
/// The hard part of this is not the look, it is that a landscape phone leaves
/// about 360 points of height and these panels have a title, a subtitle, a body
/// and three buttons to fit into it. Stacked in one column the pause menu came
/// to around 570 points and had to be scrolled, which for a menu opened
/// mid level is close to useless: you pause to change one thing and have to go
/// looking for it.
///
/// So on a short screen the buttons move to a column of their own beside the
/// content. That roughly halves the height, and everything is on screen at
/// once. On anything taller the original single column is kept, because there
/// the extra width would just push the two halves apart.
class OverlayPanel extends StatelessWidget {
  const OverlayPanel({
    super.key,
    required this.title,
    this.accent = MenuPalette.ink,
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
    final scrim = LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < _shortViewport;
        final twoColumn = short && constraints.maxWidth >= _wideViewport;

        return Container(
          color: Palette.background.withValues(alpha: 0.82),
          child: Center(
            // Kept, even though the point of the layout above is that it does
            // not need to scroll. A phone with the font size turned all the way
            // up is still a phone, and a panel that overflows is worse than one
            // that scrolls.
            child: SingleChildScrollView(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.96 + 0.04 * v, child: child),
                ),
                // Swallows taps that land on the panel itself, so only the
                // screen around it dismisses. The buttons still work: of two
                // tap recognizers over the same pixel the innermost one takes
                // the gesture, and every button is deeper than this.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    margin: EdgeInsets.all(short ? 12 : 28),
                    padding: EdgeInsets.fromLTRB(
                      short ? 20 : 28,
                      short ? 14 : 26,
                      short ? 20 : 28,
                      short ? 12 : 22,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: twoColumn ? 640 : 380,
                    ),
                    decoration: BoxDecoration(
                      color: MenuPalette.card,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: _deepen(accent, 0.18).withValues(alpha: 0.5),
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: twoColumn
                        ? _twoColumn(short)
                        : _oneColumn(short),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  Widget _oneColumn(bool short) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._heading(short, center: true),
        if (child != null) ...[
          SizedBox(height: short ? 12 : 20),
          child!,
        ],
        SizedBox(height: short ? 14 : 24),
        ...actions,
      ],
    );
  }

  Widget _twoColumn(bool short) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // The buttons decide the row's height, and a panel with no body
            // has a short left side, so the heading was sitting at the top of
            // a tall white space. Centred, it lines up with the buttons
            // instead. Panels that do have a body keep their heading at the
            // top, where it belongs.
            mainAxisAlignment:
                child == null ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              ..._heading(short, center: false),
              if (child != null) ...[
                SizedBox(height: short ? 12 : 18),
                child!,
              ],
            ],
          ),
        ),
        const SizedBox(width: 22),
        // Sized for the longest label the game has, which is WATCH AD FOR A
        // LIFE on the out of lives panel. It was 208, set when RESTART LEVEL
        // was the longest, and the rewarded life button then had to shrink so
        // far that its label ran the full width of the slab and read as
        // bursting out of it.
        SizedBox(
          width: 244,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ),
      ],
    );
  }

  List<Widget> _heading(bool short, {required bool center}) {
    return [
      Text(
        title.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: accent,
          fontSize: short ? 20 : 22,
          letterSpacing: 3,
          fontWeight: FontWeight.w900,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(
          subtitle!,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: MenuPalette.inkSoft,
            fontSize: short ? 13 : 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ];
  }
}

/// The lip a slab sits on, and the shade its fill darkens to.
Color _deepen(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
      .toColor();
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
    this.accent = MenuPalette.ink,
    this.compact,
    this.surface = MenuPalette.card,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final Color accent;

  /// Shorter, for a landscape phone where the whole page has to fit in about
  /// 340 points of height.
  ///
  /// Null asks the screen, which is what the overlays want: they are built by
  /// callers that have no idea how tall the viewport is, and every one of them
  /// wants the short version on a phone held sideways.
  final bool? compact;

  /// What an unfilled button is sitting on, so its own fill can be blended
  /// against it and come out opaque. See the fill below for why that matters.
  final Color surface;

  @override
  State<PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<PanelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final compact =
        widget.compact ?? MediaQuery.sizeOf(context).height < _shortViewport;
    final accent = widget.accent;

    // Opaque either way, and that is not a style choice. The lip below is a
    // hard edged shadow rather than a blurred one, and it sits only a few
    // points behind the face, so a translucent face lets the lip show straight
    // through the whole button and the slab comes out the colour of its own
    // shadow. Blended against the panel it lands on instead.
    final fill = widget.filled
        ? accent
        : Color.alphaBlend(accent.withValues(alpha: 0.14), widget.surface);

    // Taken off the fill rather than off the accent, so a quiet button gets a
    // lip darker than itself instead of a paler one.
    final lip = widget.filled ? _deepen(accent, 0.16) : _deepen(fill, 0.10);

    // White on a pale fill is the usual way a bright design becomes
    // unreadable, so the label picks its own colour off the fill it lands on
    // rather than trusting the caller to have chosen a dark enough accent.
    final onFill = !widget.filled
        ? accent
        : (fill.computeLuminance() > 0.45 ? MenuPalette.ink : Colors.white);

    final rest = compact ? 5.0 : 6.0;
    final lipDepth = _down ? 2.0 : rest;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
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
          height: compact ? 44 : 52,
          width: double.infinity,
          // Sinks by exactly what the lip loses, so the top face travels and
          // the bottom edge stays put.
          transform: Matrix4.translationValues(0, rest - lipDepth, 0),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.filled
                  ? Colors.white.withValues(alpha: 0.45)
                  : accent.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              // Hard edged rather than blurred: this is a moulded edge, not a
              // shadow, and a blur would read as the button floating.
              BoxShadow(color: lip, offset: Offset(0, lipDepth)),
            ],
          ),
          // Keeps the label off the border. Without it a label long enough to
          // be scaled down lands hard against both edges, which reads as text
          // bursting out of the slab rather than as a smaller label.
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
