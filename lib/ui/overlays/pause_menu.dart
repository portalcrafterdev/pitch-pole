import 'package:flutter/material.dart';

import '../../data/progress_store.dart';
import '../palette.dart';
import 'overlay_panel.dart';

class PauseMenu extends StatelessWidget {
  const PauseMenu({
    super.key,
    required this.levelId,
    required this.seconds,
    required this.onResume,
    required this.onRestart,
    required this.onLevels,
  });

  final int levelId;

  /// How long this level runs at its own speed.
  final double seconds;

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      title: 'Paused',
      subtitle: 'Level $levelId, ${seconds.toStringAsFixed(0)} seconds of '
          'running.',
      // Tapping the screen around the panel resumes, the same as the button.
      // Pausing is the one overlay the player opened on purpose and can leave
      // again unchanged, so it is the only one that closes this way.
      onDismiss: onResume,
      actions: [
        PanelButton(
          label: 'RESUME',
          icon: Icons.play_arrow_rounded,
          filled: true,
          accent: Palette.door,
          onPressed: onResume,
        ),
        PanelButton(
          label: 'RESTART LEVEL',
          icon: Icons.refresh_rounded,
          onPressed: onRestart,
        ),
        PanelButton(
          label: 'LEVELS',
          icon: Icons.grid_view_rounded,
          onPressed: onLevels,
        ),
      ],
      // The scheme and the audio are worth changing here rather than only
      // back on the home screen: you find out what suits you while you are
      // running, not from a menu. Resuming picks both up immediately.
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlSchemeToggle(),
          SizedBox(height: 16),
          _AudioToggles(),
        ],
      ),
    );
  }
}

class _ControlSchemeToggle extends StatelessWidget {
  const _ControlSchemeToggle();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progressStore,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CONTROLS',
            style: TextStyle(
              color: Palette.textMuted,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final scheme in ControlScheme.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SchemeChip(
                    scheme: scheme,
                    selected: progressStore.controlScheme == scheme,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sound and music, each on its own switch.
///
/// Two switches rather than one, because they are turned off for different
/// reasons: the music goes off because you want your own, and the effects go
/// off because you are somewhere you cannot make a noise. Either one alone is
/// a common thing to want.
class _AudioToggles extends StatelessWidget {
  const _AudioToggles();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progressStore,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AUDIO',
            style: TextStyle(
              color: Palette.textMuted,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AudioChip(
                  label: 'SOUND',
                  onIcon: Icons.volume_up_rounded,
                  offIcon: Icons.volume_off_rounded,
                  on: progressStore.soundEnabled,
                  onTap: () => progressStore.setSound(
                    !progressStore.soundEnabled,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AudioChip(
                  label: 'MUSIC',
                  onIcon: Icons.music_note_rounded,
                  offIcon: Icons.music_off_rounded,
                  on: progressStore.musicEnabled,
                  onTap: () => progressStore.setMusic(
                    !progressStore.musicEnabled,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioChip extends StatelessWidget {
  const _AudioChip({
    required this.label,
    required this.onIcon,
    required this.offIcon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData onIcon;
  final IconData offIcon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Palette.door.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Palette.door.withValues(alpha: on ? 0.55 : 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? onIcon : offIcon,
                size: 15,
                color: on ? Palette.door : Palette.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: on ? Palette.door : Palette.textMuted,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchemeChip extends StatelessWidget {
  const _SchemeChip({required this.scheme, required this.selected});

  final ControlScheme scheme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final label = scheme == ControlScheme.halves ? 'HALVES' : 'BUTTONS';
    return Material(
      color: selected
          ? Palette.door.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => progressStore.setControlScheme(scheme),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Palette.door.withValues(alpha: selected ? 0.55 : 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scheme == ControlScheme.halves
                    ? Icons.vertical_split_rounded
                    : Icons.gamepad_rounded,
                size: 15,
                color: selected ? Palette.door : Palette.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Palette.door : Palette.textMuted,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
