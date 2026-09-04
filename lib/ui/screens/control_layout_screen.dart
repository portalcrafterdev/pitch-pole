import 'package:flutter/material.dart';

import '../../data/progress_store.dart';
import '../palette.dart';
import '../widgets/touch_controls.dart';

/// Where the player puts the three pads.
///
/// A separate screen rather than a drag handle in the game, because in a level
/// every touch is an input: a jump press that slid a few points would become a
/// move instead of a jump, and the first the player would know of it is a
/// death. Here nothing is live, so a pad can be pushed around freely.
///
/// The play field is drawn behind at its true proportions, because where a pad
/// belongs is a question about what it covers. A thumb parked over the floor
/// line hides the surface the character runs along, and that is only visible
/// if the band is on screen while the pad is being placed.
class ControlLayoutScreen extends StatefulWidget {
  const ControlLayoutScreen({super.key});

  @override
  State<ControlLayoutScreen> createState() => _ControlLayoutScreenState();
}

class _ControlLayoutScreenState extends State<ControlLayoutScreen> {
  /// Held here rather than written straight through, so a drag is one smooth
  /// move and one write instead of sixty writes to disk.
  late Map<ControlPad, Offset> _spots = {
    for (final pad in ControlPad.values) pad: progressStore.padSpot(pad),
  };
  late Map<ControlPad, double> _scales = {
    for (final pad in ControlPad.values) pad: progressStore.padScale(pad),
  };

  ControlPad? _dragging;

  /// The pad the −/+ act on: the last one touched. Something has to be
  /// selected for a stepper to mean anything, and the pad you just moved is
  /// the one you are thinking about.
  ControlPad _selected = ControlPad.jump;

  /// A pinch reports its scale against where the gesture started, so the size
  /// it multiplies has to be the size at that moment rather than the one being
  /// updated as the fingers move — otherwise the pad runs away.
  double _pinchFrom = 1;

  double _diameter(ControlPad pad) => pad.size * _scales[pad]!;

  void _drag(ControlPad pad, Offset delta, Size screen) {
    if (screen.width <= 0 || screen.height <= 0) return;
    final from = _spots[pad]!;
    setState(() {
      _dragging = pad;
      _selected = pad;
      _spots[pad] = clampPadSpot(
        _diameter(pad),
        Offset(
          from.dx + delta.dx / screen.width,
          from.dy + delta.dy / screen.height,
        ),
        screen,
      );
    });
  }

  void _pinch(ControlPad pad, double scale) {
    setState(() {
      if (_dragging != pad) {
        _dragging = pad;
        _selected = pad;
        _pinchFrom = _scales[pad]!;
      }
      _scales[pad] =
          (_pinchFrom * scale).clamp(kMinPadScale, kMaxPadScale).toDouble();
    });
  }

  void _step(double by) {
    final pad = _selected;
    setState(() {
      _scales[pad] =
          (_scales[pad]! + by).clamp(kMinPadScale, kMaxPadScale).toDouble();
    });
    _commit(pad);
  }

  Future<void> _drop(ControlPad pad) async {
    setState(() => _dragging = null);
    await _commit(pad);
  }

  Future<void> _commit(ControlPad pad) async {
    await progressStore.setPadScale(pad, _scales[pad]!);
    await progressStore.setPadSpot(pad, _spots[pad]!);
  }

  Future<void> _reset() async {
    await progressStore.resetPadLayout();
    setState(() {
      _spots = {for (final pad in ControlPad.values) pad: pad.home};
      _scales = {for (final pad in ControlPad.values) pad: 1.0};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = constraints.biggest;
          return Stack(
            children: [
              const Positioned.fill(child: _FieldPreview()),
              // Along the top, and clear of the bottom, because the bottom is
              // where thumbs go and every point of it has to stay available
              // for a pad.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Row(
                    children: [
                      _Action(
                        label: 'RESET',
                        icon: Icons.restart_alt_rounded,
                        // Nothing to put back, so nothing to press. A button
                        // that does nothing is worse than no button.
                        onTap: progressStore.padsMoved ? _reset : null,
                      ),
                      const Expanded(child: _Hint()),
                      _Sizer(
                        pad: _selected,
                        scale: _scales[_selected]!,
                        onStep: _step,
                      ),
                      const SizedBox(width: 10),
                      _Action(
                        label: 'DONE',
                        icon: Icons.check_rounded,
                        filled: true,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              // Last, so the pads are on top of everything. Whatever a pad is
              // dropped on, it can always be picked up again — there is no
              // corner of this screen a pad can be lost behind.
              for (final pad in padsBackToFront(_diameter))
                PlacedPad(
                  key: ValueKey(pad),
                  pad: pad,
                  spot: _spots[pad]!,
                  diameter: _diameter(pad),
                  screen: screen,
                  label: padLabel(pad),
                  dragging: _dragging == pad,
                  // Tapping one is how you say "this is the one the minus and
                  // plus mean". Dragging says it too, but a tap is what a
                  // player reaches for when they only want to resize.
                  onTap: () => setState(() => _selected = pad),
                  onDrag: (delta) => _drag(pad, delta, screen),
                  onPinch: (scale) => _pinch(pad, scale),
                  onDrop: () => _drop(pad),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Minus and plus for the pad last touched.
///
/// A pinch is the natural way to do this and it works, but it needs two hands
/// and it is invisible until somebody guesses at it. This is the same control
/// for a player holding the phone in one hand, and it is what makes the fact
/// that pads *can* be resized visible at all.
class _Sizer extends StatelessWidget {
  const _Sizer({
    required this.pad,
    required this.scale,
    required this.onStep,
  });

  final ControlPad pad;
  final double scale;
  final void Function(double by) onStep;

  /// Ten steps end to end, which is fine enough to land on a size that suits
  /// and coarse enough that a change is visible on the first press.
  static const double _step = 0.12;

  @override
  Widget build(BuildContext context) {
    final accent = padAccent(pad);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            accent: accent,
            onTap: scale > kMinPadScale ? () => onStep(-_step) : null,
          ),
          SizedBox(
            width: 54,
            child: Text(
              padLabel(pad),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: accent.withValues(alpha: 0.75),
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            accent: accent,
            onTap: scale < kMaxPadScale ? () => onStep(_step) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: accent.withValues(alpha: onTap == null ? 0.22 : 0.9),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'DRAG A PAD ANYWHERE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Palette.text.withValues(alpha: 0.85),
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'One finger moves it, two resize it. Kept on this phone.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Palette.text.withValues(alpha: 0.42),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// The band, at its real proportions, so a pad can be judged against what it
/// would cover.
class _FieldPreview extends StatelessWidget {
  const _FieldPreview();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FieldPainter());
}

class _FieldPainter extends CustomPainter {
  /// The virtual canvas, letterboxed exactly as the game letterboxes it.
  static const double _canvasWidth = 560;
  static const double _canvasHeight = 220;
  static const double _floorLine = 170;
  static const double _ceilingLine = 50;
  static const double _thickness = 16;
  static const double _playerX = 90;
  static const double _playerSize = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / _canvasWidth) < (size.height / _canvasHeight)
        ? size.width / _canvasWidth
        : size.height / _canvasHeight;
    final left = (size.width - _canvasWidth * scale) / 2;
    final top = (size.height - _canvasHeight * scale) / 2;

    Rect band(double y, double height) => Rect.fromLTWH(
          left,
          top + y * scale,
          _canvasWidth * scale,
          height * scale,
        );

    final surface = Paint()..color = Palette.earthDark;
    canvas.drawRect(band(_floorLine, _thickness), surface);
    canvas.drawRect(band(_ceilingLine - _thickness, _thickness), surface);

    // The character, where it is locked for the whole level. It is the thing
    // a pad most obviously must not sit on top of.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + (_playerX - _playerSize / 2) * scale,
          top + (_floorLine - _playerSize) * scale,
          _playerSize * scale,
          _playerSize * scale,
        ),
        Radius.circular(4 * scale),
      ),
      Paint()..color = Palette.player,
    );
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => false;
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    final accent = filled ? Palette.door : Palette.text;
    return Material(
      color: filled
          ? accent.withValues(alpha: live ? 0.22 : 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accent.withValues(alpha: live ? 0.55 : 0.18),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: accent.withValues(alpha: live ? 0.9 : 0.3),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: accent.withValues(alpha: live ? 0.9 : 0.3),
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
