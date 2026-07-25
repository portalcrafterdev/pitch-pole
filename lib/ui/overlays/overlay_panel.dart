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
  });

  final String title;
  final Color accent;
  final String? subtitle;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 52,
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
