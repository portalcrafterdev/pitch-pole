import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/achievements.dart';
import '../../data/games_auth.dart';
import '../../data/leaderboards.dart';
import '../../data/level_repository.dart';
import '../../data/menu_audio.dart';
import '../../data/progress_store.dart';
import '../../game/scene_theme.dart';
import '../menu_palette.dart';
import '../motion.dart';
import '../overlays/overlay_panel.dart';
import '../palette.dart';
import '../widgets/bubble_text.dart';
import '../widgets/home_backdrop.dart';
import '../widgets/pressable.dart';
import '../widgets/sign_in_button.dart';
import '../widgets/volume_row.dart';
import 'control_layout_screen.dart';
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
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
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
                                        // Narrower than the page. A slab this
                                        // round needs to be about five times
                                        // as wide as it is tall or the corners
                                        // stop reading as a pill and start
                                        // reading as a rectangle.
                                        constraints: const BoxConstraints(
                                          maxWidth: 364,
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
                                                hero: true,
                                                accent: MenuPalette.play,
                                                compact: compact,
                                                onPressed: () => _openLevel(
                                                  context,
                                                  levelCount,
                                                ),
                                              ),
                                            ),
                                            // On top of the lip the slab
                                            // already carries. Three stacked
                                            // controls with only the moulded
                                            // edge between them read as one
                                            // block of colour rather than as
                                            // three things you can press.
                                            SizedBox(height: compact ? 6 : 10),
                                            _PopIn(
                                              order: 2,
                                              child: PanelButton(
                                                label: 'LEVELS',
                                                icon: Icons.grid_view_rounded,
                                                filled: true,
                                                hero: true,
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
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: compact ? 8 : 14),
                                      _PopIn(
                                        order: 4,
                                        child: _StatBar(
                                          solved: progressStore.solvedCount,
                                          stars: progressStore.totalStars,
                                          streak: progressStore.streak,
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
                      // Both out of the column entirely, so they cost the
                      // layout no height on a short screen. Signing in used to
                      // be a slab in the middle of the page; it is an account,
                      // not an action, and it belongs up here with settings.
                      Positioned(
                        top: 2,
                        right: 12,
                        // One builder over the whole row, because two of
                        // the four tiles come and go with the account.
                        child: AnimatedBuilder(
                          animation: gamesAuth,
                          builder: (context, _) => Row(
                            children: [
                              // Named for what pressing it does. Signed out
                              // that is signing in; once there is an account
                              // there is nothing left to sign into and the
                              // tile is the profile it opens.
                              _IconTile(
                                label: gamesAuth.isSignedIn
                                    ? 'PROFILE'
                                    : 'SIGN IN',
                                onPressed: () => openProfile(context),
                                child: const _MascotFace(),
                              ),
                              const SizedBox(width: 10),
                              // Their own tiles rather than rows two taps
                              // down inside the profile sheet, but only once
                              // there is an account. Section 15's reason
                              // holds: signed out there is nothing behind
                              // either of them, and a menu item that does
                              // nothing is worse than no menu item.
                              if (gamesAuth.isSignedIn) ...[
                                _IconTile(
                                  label: 'RANKS',
                                  onPressed: () => leaderboards.show(),
                                  child: const Icon(
                                    Icons.leaderboard_rounded,
                                    size: 24,
                                    color: MenuPalette.levels,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _IconTile(
                                  label: 'AWARDS',
                                  onPressed: () => achievements.show(),
                                  child: const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 24,
                                    color: MenuPalette.gold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              _IconTile(
                                label: 'SETTINGS',
                                onPressed: () => _showSettings(context),
                                child: const Icon(
                                  Icons.settings_rounded,
                                  size: 24,
                                  color: Color(0xFF4A6C7C),
                                ),
                              ),
                            ],
                          ),
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
      (_) => GameScreen(level: opening.level, levelCount: opening.levelCount),
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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
                // Two columns on a landscape phone. In one, the sheet ran a
                // long way past the fold, so haptics and Reset progress were
                // only findable by scrolling something that did not look
                // scrollable. Side by side it all fits at 360 points.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    final controls = _SettingsControlsColumn(context: context);
                    const audio = _SettingsAudioColumn();
                    if (!wide) {
                      return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SettingsControlsColumn(),
                          Divider(height: 24, indent: 16, endIndent: 16),
                          _SettingsAudioColumn(),
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: controls),
                          const VerticalDivider(width: 24, indent: 8),
                          const Expanded(child: audio),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 24, indent: 16, endIndent: 16),
                // Full width rather than in a column: it is a row of six
                // swatches, and six of anything does not fit in half a
                // landscape phone.
                const _SceneryPicker(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The left half of the settings sheet: how the game is driven, and the one
/// destructive thing on the page.
class _SettingsControlsColumn extends StatelessWidget {
  const _SettingsControlsColumn({this.context});

  /// Only so the reset row can pop the sheet it is standing in. Null when the
  /// column is built inline, which is the narrow layout.
  final BuildContext? context;

  @override
  Widget build(BuildContext buildContext) {
    final sheet = context ?? buildContext;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ControlSchemePicker(),
        const SizedBox(height: 4),
        ListTile(
          leading: const Icon(Icons.restart_alt_rounded, color: Palette.bolted),
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
            if (sheet.mounted) Navigator.of(sheet).pop();
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The right half: everything you can hear or feel.
class _SettingsAudioColumn extends StatelessWidget {
  const _SettingsAudioColumn();

  /// Listens to the store itself.
  ///
  /// This widget is built as a const, so an ancestor rebuilding does not
  /// rebuild it — Flutter sees the identical instance and skips the subtree.
  /// Without this the sliders render whatever the volume was when the sheet
  /// opened and then never move again, which is exactly the bug the control
  /// scheme picker below already had to solve.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progressStore,
    builder: (context, _) => _rows(),
  );

  Widget _rows() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingsHeading('AUDIO'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: VolumeRow(
            label: 'SOUND',
            onIcon: Icons.volume_up_rounded,
            offIcon: Icons.volume_off_rounded,
            on: progressStore.soundEnabled,
            volume: progressStore.soundVolume,
            onToggle: () => progressStore.setSound(!progressStore.soundEnabled),
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
            onToggle: () => progressStore.setMusic(!progressStore.musicEnabled),
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
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A square icon button with its name under it, for the two things on the
/// home screen that are not the game — your account and the settings.
///
/// Labelled, because two unlabelled glyphs in a corner is a guess. They are
/// the same moulded material as the slabs, only small.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The label is inside the tap target, not under it. Left as a sibling it
    // looked like part of the button and was not, which is the kind of miss
    // nobody reports — they just think the button is broken.
    return Pressable(
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF6FAFC), Color(0xFFCBDCE6)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFFA8BFCC), offset: Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: child,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: MenuPalette.ink,
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Colors.white, offset: Offset(0, 1.5)),
                Shadow(color: Colors.white, offset: Offset(1.2, 0)),
                Shadow(color: Colors.white, offset: Offset(-1.2, 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The character's head, as the profile icon. The player is the character, so
/// the account button is its face rather than a generic silhouette.
class _MascotFace extends StatelessWidget {
  const _MascotFace();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 26,
    height: 26,
    child: CustomPaint(painter: _FacePainter()),
  );
}

class _FacePainter extends CustomPainter {
  const _FacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.translate(s / 2, s / 2);

    final dark = Paint()..color = const Color(0xFF2C6FD1);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(side * s * 0.25, -s * 0.34);
      canvas.rotate(side * 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.20, height: s * 0.36),
        dark,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, s * 0.06),
          width: s * 0.76,
          height: s * 0.72,
        ),
        Radius.circular(s * 0.26),
      ),
      Paint()..color = const Color(0xFF5AA6FA),
    );

    for (final side in [-1.0, 1.0]) {
      final centre = Offset(side * s * 0.16, -s * 0.02);
      canvas.drawCircle(
        centre,
        s * 0.11,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        centre + Offset(s * 0.02, 0),
        s * 0.055,
        Paint()..color = const Color(0xFF12161F),
      );
    }

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, s * 0.20),
        width: s * 0.26,
        height: s * 0.20,
      ),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF12161F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => false;
}

/// The three totals, in one bar with rules between them.
///
/// One bar rather than three pills: they are the same kind of fact read at the
/// same moment, and three separate containers made them look like three
/// separate things.
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.solved,
    required this.stars,
    required this.streak,
  });

  final int solved;
  final int stars;

  /// Days played in a row. Zero is not drawn: a brand new player being shown a
  /// nothing they have already failed at is a poor first thing to read.
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: MenuPalette.ink.withValues(alpha: 0.16),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatCell(
            icon: Icons.emoji_events_rounded,
            tint: MenuPalette.goldDark,
            value: '$solved',
          ),
          const _StatRule(),
          _StatCell(
            icon: Icons.star_rounded,
            tint: MenuPalette.gold,
            value: '$stars',
          ),
          if (streak > 0) ...[
            const _StatRule(),
            _StatCell(
              icon: Icons.local_fire_department_rounded,
              tint: MenuPalette.friend,
              // Singular on day one, because "1 DAYS" is the kind of thing
              // that makes a game look unfinished.
              value: streak == 1 ? '1 DAY' : '$streak DAYS',
              valueTint: MenuPalette.friend,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.tint,
    required this.value,
    this.valueTint,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final Color? valueTint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: tint),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueTint ?? MenuPalette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRule extends StatelessWidget {
  const _StatRule();

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: 22,
    color: MenuPalette.inkSoft.withValues(alpha: 0.20),
  );
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
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 20),
          child: child,
        ),
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
    // No card behind it any more. The keyline is what lifts the wordmark off
    // the sky, and a white panel under a white outline was two solutions to
    // the same problem stacked on each other.
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 2 : 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BubbleTitle(compact: compact),
          SizedBox(height: compact ? 3 : 5),
          Text(
            'Run, flip and jump to the door!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MenuPalette.ink,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              shadows: const [
                Shadow(color: Colors.white, offset: Offset(0, 2)),
                Shadow(color: Colors.white, offset: Offset(0, -1)),
                Shadow(color: Colors.white, offset: Offset(1.5, 0)),
                Shadow(color: Colors.white, offset: Offset(-1.5, 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wordmark, in the shared bubble treatment.
class _BubbleTitle extends StatelessWidget {
  const _BubbleTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => BubbleText(
    text: 'PITCHPOLE',
    keyline: compact ? 7 : 9,
    gradient: MenuPalette.rainbow,
    style: TextStyle(
      color: Colors.white,
      fontSize: compact ? 30 : 40,
      letterSpacing: compact ? 3 : 5,
      fontWeight: FontWeight.w900,
    ),
  );
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
/// Which of the five places every level is set in, or none of them.
///
/// The scenery normally changes every ten levels, which is how getting
/// somewhere shows on screen. Some players would rather it did not move, and
/// some just prefer one of them, so the rotation is the default rather than
/// the rule. Nothing here changes a level: a theme is temperature and
/// lightness, and `scene_theme_test.dart` holds every one of them to leaving
/// the cast findable.
class _SceneryPicker extends StatelessWidget {
  const _SceneryPicker();

  @override
  Widget build(BuildContext context) {
    // Listens to the store itself, for the same reason the control scheme
    // picker does: built as a const, an ancestor rebuilding skips the subtree
    // and the highlight sticks where it was when the sheet opened.
    return AnimatedBuilder(
      animation: progressStore,
      builder: (context, _) => _rows(),
    );
  }

  Widget _rows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingsHeading('SCENERY'),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const _SceneryChip(theme: null, label: 'BY LEVEL'),
              for (final theme in SceneTheme.all) ...[
                const SizedBox(width: 10),
                _SceneryChip(theme: theme, label: theme.name.toUpperCase()),
              ],
            ],
          ),
        ),
        _SettingsNote(
          progressStore.sceneryChoice == null
              ? 'A new place every ten levels'
              : 'Every level set in the same place',
        ),
      ],
    );
  }
}

/// One swatch: the sky, the band and the ground it would paint, stacked.
///
/// Painted from the theme's own colours rather than drawn as an icon, so the
/// button is a sample of the thing it selects and cannot drift away from it.
class _SceneryChip extends StatelessWidget {
  const _SceneryChip({required this.theme, required this.label});

  /// Null is the rotation, which has no colours of its own to show.
  final SceneTheme? theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = progressStore.sceneryChoice == theme?.name;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          MenuAudio.instance.tap();
          progressStore.setScenery(theme?.name);
        },
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? MenuPalette.play : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? const Color(0xFF3F8A1D)
                          : MenuPalette.ink.withValues(alpha: 0.18),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: theme == null
                    ? Container(
                        color: MenuPalette.card,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: MenuPalette.levels,
                          size: 22,
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ColoredBox(
                              color: theme!.skyHigh,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: ColoredBox(
                              color: theme!.bandLow,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ColoredBox(
                              color: theme!.earthDark,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? MenuPalette.play : MenuPalette.inkSoft,
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        // Only offered with buttons on, because with halves there are no pads
        // to place. A row that opens a screen with nothing in it is worse than
        // a row that is not there.
        if (progressStore.controlScheme == ControlScheme.buttons)
          const _ArrangePadsRow(),
      ],
    );
  }
}

/// Opens the screen where the three pads are dragged into place.
class _ArrangePadsRow extends StatelessWidget {
  const _ArrangePadsRow();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.open_with_rounded, color: MenuPalette.levels),
      title: const Text(
        'Arrange the buttons',
        style: TextStyle(color: MenuPalette.ink, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        progressStore.padsMoved
            ? 'Moved. Drag them again, or put them back.'
            : 'Drag each pad to wherever your thumbs are',
        style: const TextStyle(color: MenuPalette.inkSoft, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: MenuPalette.inkSoft,
      ),
      onTap: () {
        MenuAudio.instance.tap();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ControlLayoutScreen()),
        );
      },
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
