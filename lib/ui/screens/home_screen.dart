import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../overlays/overlay_panel.dart';
import '../palette.dart';
import '../widgets/sign_in_button.dart';
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
              builder: (context, _) => Stack(
                // Without this the stack shrinks to the width of its content,
                // which pins the whole page to the left of a wide landscape
                // screen instead of centring it.
                fit: StackFit.expand,
                children: [
                  // The game is landscape only, so the page has to survive a
                  // very short viewport. It centres when there is room and
                  // scrolls when there is not, rather than overflowing.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 420;
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              32,
                              compact ? 14 : 28,
                              32,
                              compact ? 14 : 28,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Title(compact: compact),
                                SizedBox(height: compact ? 8 : 10),
                                Text(
                                  'It never stops running.\n'
                                  'Flip, jump, reach the door.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Palette.textMuted,
                                    fontSize: compact ? 12 : 14,
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: compact ? 20 : 48),
                                if (levels == null)
                                  const CircularProgressIndicator(
                                    color: Palette.textMuted,
                                  )
                                else ...[
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    child: Column(
                                      children: [
                                        PanelButton(
                                          label: progressStore.solvedCount == 0
                                              ? 'PLAY'
                                              : 'CONTINUE',
                                          icon: Icons.play_arrow_rounded,
                                          filled: true,
                                          accent: Palette.door,
                                          compact: compact,
                                          onPressed: () {
                                            final next = progressStore
                                                .nextLevel(levels.length);
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
                                          compact: compact,
                                          onPressed: () =>
                                              Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const LevelSelectScreen(),
                                            ),
                                          ),
                                        ),
                                        // Below the two that matter, and
                                        // quieter than both: the whole game
                                        // plays the same signed out.
                                        SizedBox(height: compact ? 2 : 6),
                                        SignInButton(compact: compact),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 6 : 12),
                                  Text(
                                    '${progressStore.solvedCount} of '
                                    '${levels.length} solved  ·  '
                                    '${progressStore.totalStars} of '
                                    '${levels.length * 3} stars',
                                    style: const TextStyle(
                                      color: Palette.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Out of the column entirely, so it costs the layout no
                  // height on a short screen.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: () => _showSettings(context),
                      icon: const Icon(Icons.settings_rounded),
                      color: Palette.textMuted,
                      tooltip: 'Settings',
                    ),
                  ),
                ],
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
      // A landscape phone is about 360 points tall, and the default sheet is
      // capped at just over half of that, which shows two and a half rows.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: progressStore,
        builder: (context, _) => SafeArea(
          // Landscape leaves very little height, so the sheet scrolls.
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const _ControlSchemePicker(),
              const Divider(height: 24, indent: 16, endIndent: 16),
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
      ),
    );
  }
}

/// The two touch schemes, as an either or. Picking one turns the other off,
/// which is the point: they must never both be live.
class _ControlSchemePicker extends StatelessWidget {
  const _ControlSchemePicker();

  @override
  Widget build(BuildContext context) {
    // Listens to the store itself. This widget is built as a const, so an
    // ancestor rebuilding does not rebuild it: Flutter sees the identical
    // widget instance and skips the subtree, which left the highlight stuck
    // on whichever scheme was selected when the sheet opened.
    return AnimatedBuilder(
      animation: progressStore,
      builder: (context, _) => _buildCards(),
    );
  }

  Widget _buildCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'TOUCH CONTROLS',
            style: TextStyle(
              color: Palette.textMuted,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _SchemeCard(
                  scheme: ControlScheme.halves,
                  icon: Icons.vertical_split_rounded,
                  title: 'Screen halves',
                  detail: 'Left flips, right jumps. No buttons.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SchemeCard(
                  scheme: ControlScheme.buttons,
                  icon: Icons.gamepad_rounded,
                  title: 'Buttons',
                  detail: 'Up and down, jump. Screen taps ignored.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.scheme,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final ControlScheme scheme;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final selected = progressStore.controlScheme == scheme;
    return Material(
      color: selected
          ? Palette.door.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => progressStore.setControlScheme(scheme),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Palette.door.withValues(alpha: selected ? 0.55 : 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Palette.door : Palette.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Palette.door : Palette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: Palette.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PITCHPOLE',
          style: TextStyle(
            color: Palette.text,
            fontSize: compact ? 26 : 36,
            letterSpacing: compact ? 5 : 7,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: compact ? 92 : 120,
          child: const Divider(color: Palette.door, thickness: 2),
        ),
      ],
    );
  }
}
