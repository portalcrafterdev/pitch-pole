import 'package:flutter/material.dart';

import '../palette.dart';

/// One audio channel: a mute button and a level, on one line.
///
/// Used by both the settings sheet and the pause menu, so the two cannot drift
/// apart. The icon is the switch rather than a separate control, because the
/// two things a player wants — *off now* and *a bit quieter* — are the same
/// gesture apart, and a slider dragged to zero is a worse mute than a button:
/// it loses the level you had set.
class VolumeRow extends StatelessWidget {
  const VolumeRow({
    super.key,
    required this.label,
    required this.onIcon,
    required this.offIcon,
    required this.on,
    required this.volume,
    required this.onToggle,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final IconData onIcon;
  final IconData offIcon;
  final bool on;

  /// 0 to 1.
  final double volume;

  final VoidCallback onToggle;
  final ValueChanged<double> onChanged;

  /// Tighter, for the pause menu on a landscape phone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = on ? Palette.door : Palette.textMuted;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      child: Row(
        children: [
          // Bigger than it looks: the whole point is that muting is one tap
          // and does not cost the level you had set.
          IconButton(
            onPressed: onToggle,
            icon: Icon(on ? onIcon : offIcon),
            color: accent,
            iconSize: compact ? 18 : 20,
            visualDensity: VisualDensity.compact,
            tooltip: on ? 'Mute $label' : 'Unmute $label',
          ),
          SizedBox(
            width: compact ? 52 : 62,
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: compact ? 11 : 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: accent,
                inactiveTrackColor: Palette.text.withValues(alpha: 0.12),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.12),
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: compact ? 7 : 8,
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: compact ? 14 : 16,
                ),
              ),
              child: Slider(
                value: volume.clamp(0.0, 1.0),
                // Muted is not the same as silent: the slider keeps showing
                // the level it will come back to, but cannot be dragged while
                // the channel is off, so the two controls never disagree.
                onChanged: on ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: compact ? 34 : 40,
            child: Text(
              '${(volume * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Palette.textMuted,
                fontSize: compact ? 11 : 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
