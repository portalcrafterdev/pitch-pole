import 'package:flutter/material.dart';

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

/// Primary action inside an overlay.
class PanelButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
      child: SizedBox(
        width: double.infinity,
        height: compact ? 44 : 52,
        child: Material(
          color: filled ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withValues(alpha: filled ? 0.55 : 0.16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: accent),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
