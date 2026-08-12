import 'package:flutter/material.dart';

import '../../data/menu_audio.dart';
import '../../data/progress_store.dart';
import '../menu_palette.dart';
import '../widgets/volume_row.dart';
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
      accent: MenuPalette.levels,
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
          accent: MenuPalette.play,
          onPressed: onResume,
        ),
        PanelButton(
          label: 'RESTART LEVEL',
          icon: Icons.refresh_rounded,
          filled: true,
          accent: MenuPalette.friend,
          onPressed: onRestart,
        ),
        PanelButton(
          label: 'LEVELS',
          icon: Icons.grid_view_rounded,
          filled: true,
          accent: MenuPalette.levels,
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
          SizedBox(height: 12),
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
              color: MenuPalette.inkSoft,
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
              color: MenuPalette.inkSoft,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          VolumeRow(
            label: 'SOUND',
            onIcon: Icons.volume_up_rounded,
            offIcon: Icons.volume_off_rounded,
            on: progressStore.soundEnabled,
            volume: progressStore.soundVolume,
            onToggle: () =>
                progressStore.setSound(!progressStore.soundEnabled),
            onChanged: progressStore.setSoundVolume,
            compact: true,
          ),
          VolumeRow(
            label: 'MUSIC',
            onIcon: Icons.music_note_rounded,
            offIcon: Icons.music_off_rounded,
            on: progressStore.musicEnabled,
            volume: progressStore.musicVolume,
            onToggle: () =>
                progressStore.setMusic(!progressStore.musicEnabled),
            onChanged: progressStore.setMusicVolume,
            compact: true,
          ),
        ],
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
          ? MenuPalette.levels.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          MenuAudio.instance.tap();
          progressStore.setControlScheme(scheme);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              // The unselected edge is grey rather than a faded accent. On the
              // dark panel this used to sit on, a 16% accent was visible; on
              // white it is not there at all, and a chip with no visible edge
              // does not read as something you can press.
              color: selected
                  ? MenuPalette.levels
                  : MenuPalette.inkSoft.withValues(alpha: 0.35),
              width: selected ? 2 : 1.5,
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
                color: selected ? MenuPalette.levels : MenuPalette.inkSoft,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? MenuPalette.levels : MenuPalette.inkSoft,
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
