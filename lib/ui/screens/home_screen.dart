import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../overlays/overlay_panel.dart';
import '../palette.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        child: FutureBuilder<List<LevelModel>>(
          future: levelRepository.loadAll(),
          builder: (context, snapshot) {
            final levels = snapshot.data;
            return AnimatedBuilder(
              animation: progressStore,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const _Title(),
                    const SizedBox(height: 10),
                    const Text(
                      'It never stops running.\nFlip, jump, reach the door.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Palette.textMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (levels == null)
                      const CircularProgressIndicator(
                          color: Palette.textMuted)
                    else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            PanelButton(
                              label: progressStore.solvedCount == 0
                                  ? 'PLAY'
                                  : 'CONTINUE',
                              icon: Icons.play_arrow_rounded,
                              filled: true,
                              accent: Palette.door,
                              onPressed: () {
                                final next =
                                    progressStore.nextLevel(levels.length);
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GameScreen(
                                      levels: levels,
                                      index: next - 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                            PanelButton(
                              label: 'LEVELS',
                              icon: Icons.grid_view_rounded,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LevelSelectScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${progressStore.solvedCount} of ${levels.length} '
                        'solved  ·  ${progressStore.totalStars} of '
                        '${levels.length * 3} stars',
                        style: const TextStyle(
                          color: Palette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showSettings(context),
                      icon: const Icon(Icons.settings_rounded),
                      color: Palette.textMuted,
                      tooltip: 'Settings',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: progressStore,
        builder: (context, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              SwitchListTile(
                value: progressStore.soundEnabled,
                onChanged: progressStore.setSound,
                activeThumbColor: Palette.door,
                title: const Text('Sound',
                    style: TextStyle(color: Palette.text)),
                subtitle: const Text(
                  'Whoosh on flip, click on jump, thud on landing and death',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
              ),
              SwitchListTile(
                value: progressStore.musicEnabled,
                onChanged: progressStore.setMusic,
                activeThumbColor: Palette.door,
                title: const Text('Music',
                    style: TextStyle(color: Palette.text)),
                subtitle: const Text(
                  'A quiet loop under the run',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
              ),
              SwitchListTile(
                value: progressStore.hapticsEnabled,
                onChanged: progressStore.setHaptics,
                activeThumbColor: Palette.door,
                title: const Text('Haptics',
                    style: TextStyle(color: Palette.text)),
                subtitle: const Text(
                  'Vibration on flip and death',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded,
                    color: Palette.bolted),
                title: const Text('Reset progress',
                    style: TextStyle(color: Palette.bolted)),
                subtitle: const Text(
                  'Clears every star and relocks every level',
                  style: TextStyle(color: Palette.textMuted, fontSize: 12),
                ),
                onTap: () async {
                  await progressStore.resetProgress();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PITCHPOLE',
          style: TextStyle(
            color: Palette.text,
            fontSize: 36,
            letterSpacing: 7,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: Divider(color: Palette.door, thickness: 2),
        ),
      ],
    );
  }
}
