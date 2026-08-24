import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../data/menu_audio.dart';
import '../../data/progress_store.dart';
import '../menu_palette.dart';
import '../motion.dart';
import '../overlays/overlay_panel.dart';
import '../palette.dart';
import '../widgets/home_backdrop.dart';
import '../widgets/sign_in_button.dart';
import '../widgets/volume_row.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';

/// The front door of the game.
///
/// Two kinds of movement, kept apart on purpose. Behind the menu the scene
/// loops forever on Flame's loop; in front of it every animation is a one shot
/// that plays on arrival and then stops. A menu whose buttons never settle is
/// a menu no test can wait for, and a button that is still moving when a small
/// hand arrives is a button that gets missed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MenuPalette.skyLow,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Outside the SafeArea, so the sky runs under the notch and the home
          // indicator rather than stopping in a grey band short of them.
          const HomeBackdrop(),
          SafeArea(
            child: FutureBuilder<int>(
              // The count, not the pack. The home screen shows how many levels
              // there are and how many are solved, and the second of those
              // comes out of the progress store — so there is no reason to
              // decode ten thousand levels to draw two buttons.
              future: levelRepository.count(),
              builder: (context, snapshot) {
                final levelCount = snapshot.data;
                return AnimatedBuilder(
                  animation: progressStore,
                  builder: (context, _) => Stack(
                    // Without this the stack shrinks to the width of its
                    // content, which pins the whole page to the left of a wide
                    // landscape screen instead of centring it.
                    fit: StackFit.expand,
                    children: [
                      // The game is landscape only, so the page has to survive
                      // a very short viewport. It centres when there is room
                      // and scrolls when there is not, rather than
                      // overflowing.
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
                                  compact ? 10 : 24,
                                  32,
                                  compact ? 10 : 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _PopIn(
                                      order: 0,
                                      child: _TitleSign(compact: compact),
                                    ),
                                    SizedBox(height: compact ? 14 : 26),
                                    if (levelCount == null)
                                      const CircularProgressIndicator(
                                        color: MenuPalette.play,
                                      )
                                    else ...[
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 320,
                                        ),
                                        child: Column(
                                          children: [
                                            _PopIn(
                                              order: 1,
                                              child: PanelButton(
                                                label:
                                                    progressStore.solvedCount ==
                                                            0
                                                        ? 'PLAY'
                                                        : 'CONTINUE',
                                                icon: Icons.play_arrow_rounded,
                                                filled: true,
                                                accent: MenuPalette.play,
                                                compact: compact,
                                                onPressed: () =>
                                                    _openLevel(context, levelCount),
                                              ),
                                            ),
                                            _PopIn(
                                              order: 2,
                                              child: PanelButton(
                                                label: 'LEVELS',
                                                icon: Icons.grid_view_rounded,
                                                filled: true,
                                                accent: MenuPalette.levels,
                                                compact: compact,
                                                onPressed: () =>
                                                    _openAndResumeMusic(
                                                  context,
                                                  (_) =>
                                                      const LevelSelectScreen(),
                                                ),
                                              ),
                                            ),
                                            // Below the two that matter, and
                                            // quieter than both: the whole
                                            // game plays the same signed out.
                                            SizedBox(height: compact ? 2 : 6),
                                            _PopIn(
                                              order: 3,
                                              child:
                                                  SignInButton(compact: compact),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: compact ? 8 : 14),
                                      _PopIn(
                                        order: 4,
                                        child: _ScoreChip(
                                          solved: progressStore.solvedCount,
                                          levels: levelCount,
                                          stars: progressStore.totalStars,
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
                        top: 4,
                        right: 4,
                        child: _RoundButton(
                          icon: Icons.settings_rounded,
                          tooltip: 'Settings',
                          onPressed: () => _showSettings(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Opens a screen, and takes the music back when it closes.
  ///
  /// A level owns the background loop while it is running and stops it on its
  /// way out, which is correct: it cannot know that a menu is what comes next
  /// rather than another level. So the menu asks for it back on the way in,
  /// and pressing PLAY is seamless because the level claims a loop that is
  /// already playing instead of starting a new one.
  void _openAndResumeMusic(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: builder))
        .then((_) => MenuAudio.instance.start());
  }

  /// PLAY, or CONTINUE: opens the first level the player has not solved.
  ///
  /// The level has to be read out of its shard before the screen can be built,
  /// so this is asynchronous where it used to be a list lookup. One shard is a
  /// few hundred kilobytes off the bundle, which is faster than the page
  /// transition it is hidden behind.
  Future<void> _openLevel(BuildContext context, int levelCount) async {
    final opening = await openingFor(progressStore.nextLevel(levelCount));
    if (opening == null || !context.mounted) return;
    _openAndResumeMusic(
      context,
      (_) => GameScreen(
        level: opening.level,
        levelCount: opening.levelCount,
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MenuPalette.card,
      // A landscape phone is about 360 points tall, and the default sheet is
      // capped at just over half of that, which shows two and a half rows.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: progressStore,
        builder: (context, _) => SafeArea(
          // Landscape leaves very little height, so the sheet scrolls.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // A grab handle, because a sheet with no visible edge is a
                // sheet a child does not know can be pushed away.
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: MenuPalette.inkSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 10),
                const _ControlSchemePicker(),
                const Divider(height: 24, indent: 16, endIndent: 16),
                const _SettingsHeading('AUDIO'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: VolumeRow(
                    label: 'SOUND',
                    onIcon: Icons.volume_up_rounded,
                    offIcon: Icons.volume_off_rounded,
                    on: progressStore.soundEnabled,
                    volume: progressStore.soundVolume,
                    onToggle: () =>
                        progressStore.setSound(!progressStore.soundEnabled),
                    onChanged: progressStore.setSoundVolume,
                  ),
                ),
                const _SettingsNote(
                  'Whoosh on flip, click on jump, thud on landing and death',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: VolumeRow(
                    label: 'MUSIC',
                    onIcon: Icons.music_note_rounded,
                    offIcon: Icons.music_off_rounded,
                    on: progressStore.musicEnabled,
                    volume: progressStore.musicVolume,
                    onToggle: () =>
                        progressStore.setMusic(!progressStore.musicEnabled),
                    onChanged: progressStore.setMusicVolume,
                  ),
                ),
                const _SettingsNote('A quiet loop under the run'),
                SwitchListTile(
                  value: progressStore.hapticsEnabled,
                  onChanged: progressStore.setHaptics,
                  activeThumbColor: MenuPalette.play,
                  title: const Text(
                    'Haptics',
                    style: TextStyle(
                      color: MenuPalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Vibration on flip and death',
                    style: TextStyle(color: MenuPalette.inkSoft, fontSize: 12),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.restart_alt_rounded,
                    color: Palette.bolted,
                  ),
                  title: const Text(
                    'Reset progress',
                    style: TextStyle(
                      color: Palette.bolted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Clears every star and relocks every level',
                    style: TextStyle(color: MenuPalette.inkSoft, fontSize: 12),
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

/// Fades and lifts its child into place once, on arrival.
///
/// [order] staggers them down the page out of a single duration, so the title
/// lands before the buttons do. Every one of these finishes: nothing on this
/// screen animates forever, which is what lets a test wait for the page to
/// settle and then measure it.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child, this.order = 0});

  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    final start = (order * 0.13).clamp(0.0, 0.7);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionFor(context)
          ? const Duration(milliseconds: 850)
          : Duration.zero,
      curve: Interval(start, 1, curve: Curves.easeOutBack),
      builder: (context, v, child) => Opacity(
        // easeOutBack overshoots past one on the way in, which is the point of
        // it, but an opacity above one throws.
        opacity: v.clamp(0.0, 1.0),
        // Vertical only. The title and the play button are both asserted to be
        // centred to within two points, and a horizontal entrance that landed
        // a frame late would be a genuinely baffling test failure.
        child: Transform.translate(offset: Offset(0, (1 - v) * 20), child: child),
      ),
      child: child,
    );
  }
}

/// The name, on a painted sign.
///
/// The sign is not decoration. The sky behind it is bright and the letters are
/// a rainbow, and rainbow on pale blue is unreadable; a solid plate under it
/// is what buys the title its contrast back.
class _TitleSign extends StatelessWidget {
  const _TitleSign({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 26,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MenuPalette.gold, width: 3),
        boxShadow: [
          BoxShadow(
            color: MenuPalette.goldDark.withValues(alpha: 0.55),
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One Text, not one per letter. Splitting it would look livelier and
          // would break every test that looks for the title by name.
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: MenuPalette.rainbow,
            ).createShader(rect),
            child: Text(
              'PITCHPOLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 28 : 38,
                letterSpacing: compact ? 4 : 6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Run, flip and jump to the door!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MenuPalette.inkSoft,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// How far you have got, as a badge rather than a line of grey text.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.solved,
    required this.levels,
    required this.stars,
  });

  final int solved;
  final int levels;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 16, color: MenuPalette.goldDark),
          const SizedBox(width: 6),
          Text(
            '$solved of $levels solved',
            style: const TextStyle(
              color: MenuPalette.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.star_rounded, size: 16, color: MenuPalette.gold),
          const SizedBox(width: 4),
          Text(
            '$stars of ${levels * 3}',
            style: const TextStyle(
              color: MenuPalette.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A round white button, for the one control that is not a slab.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            MenuAudio.instance.tap();
            onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: MenuPalette.ink, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            color: MenuPalette.inkSoft,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SettingsNote extends StatelessWidget {
  const _SettingsNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(color: MenuPalette.inkSoft, fontSize: 12),
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
        const _SettingsHeading('TOUCH CONTROLS'),
        const SizedBox(height: 8),
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
          ? MenuPalette.levels.withValues(alpha: 0.14)
          : MenuPalette.cardSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          MenuAudio.instance.tap();
          progressStore.setControlScheme(scheme);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? MenuPalette.levels
                  : MenuPalette.inkSoft.withValues(alpha: 0.18),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? MenuPalette.levels : MenuPalette.inkSoft,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? MenuPalette.levels : MenuPalette.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: MenuPalette.inkSoft,
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
