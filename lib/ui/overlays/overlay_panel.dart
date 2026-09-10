import 'package:flutter/material.dart';

import '../../data/menu_audio.dart';
import '../menu_palette.dart';
import '../widgets/bubble_text.dart';
import '../widgets/tap_ring.dart';
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
    this.titleGradient,
    this.subtitleAbove = false,
    this.centerContent = false,
  });

  final String title;
  final Color accent;
  final String? subtitle;

  /// Fills the title with these instead of [accent], in the same bubble
  /// treatment the menus use for their headings. Set only where the title is
  /// the reward — a panel that says a life was lost should not be celebrating.
  final List<Color>? titleGradient;

  /// Puts the subtitle over the title rather than under it. Which level was
  /// cleared is the label; CLEARED is the headline, and a headline reads first
  /// wherever it is on the page.
  final bool subtitleAbove;

  /// Centres the left column even in the two column layout.
  ///
  /// Off by default: a panel whose body is a line of prose reads better ranged
  /// left. On the cleared panel the body is a row of stars and a strip of
  /// numbers, and a heading ranged left over a centred row of stars looks like
  /// two things that were laid out separately — because they were.
  final bool centerContent;
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
                      // A white rim with the accent as a moulded lip below it,
                      // the same way every slab on the page is built. The rim
                      // was the accent itself, which put a hard coloured line
                      // around a white card and read as a border rather than
                      // as an edge.
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [MenuPalette.card, MenuPalette.cardSoft],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _deepen(accent, 0.13),
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Palette.background.withValues(alpha: 0.45),
                          offset: const Offset(0, 14),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: twoColumn ? _twoColumn(short) : _oneColumn(short),
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
        if (child != null) ...[SizedBox(height: short ? 12 : 20), child!],
        SizedBox(height: short ? 14 : 24),
        ..._spacedActions(short),
      ],
    );
  }

  /// The actions with air between them.
  ///
  /// A slab already carries a moulded lip, and stacked with only that between
  /// them four buttons read as one block of colour rather than as four things
  /// you can press. Kept small on a short screen: these panels fit three or
  /// four buttons into about 360 points of height, and the gaps come out of
  /// the same budget.
  List<Widget> _spacedActions(bool short) {
    final gap = SizedBox(height: short ? 6 : 8);
    return [
      for (var i = 0; i < actions.length; i++) ...[if (i > 0) gap, actions[i]],
    ];
  }

  Widget _twoColumn(bool short) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerContent
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            // The buttons decide the row's height, and a panel with no body
            // has a short left side, so the heading was sitting at the top of
            // a tall white space. Centred, it lines up with the buttons
            // instead. Panels that do have a body keep their heading at the
            // top, where it belongs.
            mainAxisAlignment: child == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              ..._heading(short, center: centerContent),
              if (child != null) ...[SizedBox(height: short ? 12 : 18), child!],
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
            children: _spacedActions(short),
          ),
        ),
      ],
    );
  }

  List<Widget> _heading(bool short, {required bool center}) {
    final gradient = titleGradient;
    final heading = gradient == null
        ? Text(
            title.toUpperCase(),
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: accent,
              fontSize: short ? 20 : 22,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            ),
          )
        : BubbleText(
            text: title.toUpperCase(),
            textAlign: center ? TextAlign.center : TextAlign.start,
            keyline: short ? 7 : 8,
            gradient: gradient,
            shadow: _deepen(accent, 0.13).withValues(alpha: 0.45),
            style: TextStyle(
              color: Colors.white,
              fontSize: short ? 28 : 32,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          );

    final label = subtitle == null
        ? null
        : Text(
            subtitle!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: MenuPalette.inkSoft,
              // Above the headline it is a label on the result, so it is set
              // small and wide like one. Under the headline it is a sentence
              // about the result, and reads as body.
              fontSize: subtitleAbove ? 12 : (short ? 13 : 14),
              height: 1.35,
              letterSpacing: subtitleAbove ? 2 : 0,
              fontWeight: subtitleAbove ? FontWeight.w900 : FontWeight.w600,
            ),
          );

    if (subtitleAbove) {
      return [
        if (label != null) ...[label, const SizedBox(height: 4)],
        heading,
      ];
    }

    return [
      heading,
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

/// The other end of [_deepen], for the top of a slab's gradient.
///
/// Saturation comes down as lightness goes up. Lifting lightness alone turns a
/// saturated accent neon at the top of the button, which reads as a colour
/// error rather than as light falling on it.
Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation - 0.04).clamp(0.0, 1.0))
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
/// A dark ring around each letter, and a hard drop under it.
///
/// Drawn as eight offset shadows rather than a stroked paint, because a
/// stroke needs a second [Text] behind the first and a [TextStyle] is the
/// only thing a label like this actually carries.
///
/// **Only ever put on light text over a colour.** The same ring around dark
/// text closes the counters and fills the glyph in solid, which is exactly
/// what it did to the trophy and star counts when it was inherited by every
/// style in the app instead of asked for here.
List<Shadow> keylineShadows(double width) => [
  for (final at in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(0.7, 0.7),
    Offset(-0.7, 0.7),
    Offset(0.7, -0.7),
    Offset(-0.7, -0.7),
  ])
    Shadow(
      color: MenuPalette.ink,
      offset: Offset(at.dx * width, at.dy * width),
    ),
  Shadow(
    color: MenuPalette.ink.withValues(alpha: 0.34),
    offset: Offset(0, width * 1.8),
  ),
];

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
    this.sublabel,
    this.trailing,
    this.hero = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final Color accent;

  /// A quiet second line under the label. Setting it makes the slab taller and
  /// left aligns the label, because a two line block centred against a wide
  /// button reads as floating rather than as the start of a row.
  final String? sublabel;

  /// Anything the button should carry on its right — the level number and its
  /// stars, on the one button that opens a level.
  final Widget? trailing;

  /// The primary action on a page. Taller, with a larger label and icon, so
  /// the eye lands on it before anything else. Only one button on a screen
  /// should ever set this.
  final bool hero;

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

class _PanelButtonState extends State<PanelButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;

  /// Where the last press landed, and how far its ring has opened. The lip
  /// sinking says the slab took the press; the ring says where the thumb was.
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
    //
    // Thirteen percent, not twenty. Twenty took the green so far down that the
    // lip came out olive rather than a shade of the button above it, and the
    // whole slab read as dirty. A moulded edge is the same colour in shadow,
    // not a different colour.
    final lip = widget.filled ? _deepen(accent, 0.13) : _deepen(fill, 0.10);

    // The slab is lit from above: the top of the gradient is the fill with
    // light on it, the bottom is the fill itself. One accent still defines the
    // whole button, so no caller has to know about any of this.
    final crown = _lighten(fill, widget.filled ? 0.13 : 0.05);

    // White on a pale fill is the usual way a bright design becomes
    // unreadable, so the label picks its own colour off the fill it lands on
    // rather than trusting the caller to have chosen a dark enough accent.
    final onFill = !widget.filled
        ? accent
        : (fill.computeLuminance() > 0.45 ? MenuPalette.ink : Colors.white);

    final rest = compact ? 6.0 : 7.0;
    final lipDepth = _down ? 2.0 : rest;
    final tall = widget.sublabel != null || widget.trailing != null;
    final height = widget.hero
        ? (compact ? 56.0 : 66.0)
        : tall
        ? (compact ? 54.0 : 62.0)
        : (compact ? 44.0 : 52.0);
    // Scaled with the button rather than fixed, so a tall slab is a pill and
    // a short one is still a rounded rectangle instead of both being the same
    // corner on different heights.
    final radius = height * 0.38;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
      child: GestureDetector(
        // Opaque, so the gap between the icon and the label is still the
        // button. A small target with holes in it is a small target.
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          _at = details.localPosition;
          _ring.forward(from: 0);
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
          height: height,
          width: double.infinity,
          // Sinks by exactly what the lip loses, so the top face travels and
          // the bottom edge stays put.
          transform: Matrix4.translationValues(0, rest - lipDepth, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [crown, fill],
            ),
            borderRadius: BorderRadius.circular(radius),
            // A full white rim rather than a translucent one. It is what
            // separates the slab from whatever it is standing on, and at 45%
            // over a bright sky there was nothing there to see.
            border: Border.all(
              color: widget.filled ? Colors.white : Colors.white,
              width: 3,
            ),
            boxShadow: [
              // Hard edged rather than blurred: this is a moulded edge, not a
              // shadow, and a blur would read as the button floating.
              BoxShadow(color: lip, offset: Offset(0, lipDepth)),
              // And then a real shadow under the lip, so the slab sits on the
              // page instead of being pasted onto it.
              BoxShadow(
                color: MenuPalette.ink.withValues(alpha: 0.16),
                offset: Offset(0, lipDepth + 3),
                blurRadius: 10,
              ),
            ],
          ),
          // Keeps the label off the border. Without it a label long enough to
          // be scaled down lands hard against both edges, which reads as text
          // bursting out of the slab rather than as a smaller label.
          padding: EdgeInsets.symmetric(horizontal: tall ? 16 : 14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The ring out of the thumb, clipped to the slab so it never
              // throws a square of colour past the corners, and behind an
              // [IgnorePointer] so it cannot swallow the press after it.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _ring,
                        builder: (context, _) => CustomPaint(
                          painter: TapRingPainter(
                            at: _at,
                            progress: _ring.value,
                            colour: Colors.white,
                            radius: height,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The highlight. A rounded band across the top third, fading
              // out: the single cheapest thing that turns a flat rectangle
              // into something moulded.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height * 0.36,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(
                          alpha: widget.filled ? 0.34 : 0.55,
                        ),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: tall
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: widget.hero ? 30 : (tall ? 26 : 22),
                      color: onFill,
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Shrunk to fit rather than clipped or ellipsed. A label
                  // here is an instruction, so losing the end of it is worse
                  // than losing a point of size, and a long one overflowed the
                  // row outright before this.
                  Flexible(
                    // Tight when the slab is tall, so the label block fills the
                    // middle and pushes the trailing content to the right edge.
                    fit: tall ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: tall
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: onFill,
                              fontSize: widget.hero ? 26 : (tall ? 18 : 16),
                              fontWeight: FontWeight.w900,
                              letterSpacing: widget.hero ? 2 : 1.2,
                              height: 1.1,
                              shadows: widget.filled
                                  ? keylineShadows(widget.hero ? 2.0 : 1.5)
                                  : const [
                                      Shadow(
                                        color: Color(0x3A000000),
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                        if (widget.sublabel != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.sublabel!,
                              maxLines: 1,
                              style: TextStyle(
                                color: onFill.withValues(alpha: 0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 10),
                    widget.trailing!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
