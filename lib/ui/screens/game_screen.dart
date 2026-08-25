import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/achievement_rules.dart';
import '../../data/achievements.dart';
import '../../data/ads.dart';
import '../../data/cloud_save.dart';
import '../../data/leaderboards.dart';
import '../../data/level_repository.dart';
import '../../data/progress_store.dart';
import '../../game/logic/level_model.dart';
import '../../game/logic/physics.dart';
import '../../game/logic/run_state.dart';
import '../../game/pitchpole_game.dart';
import '../overlays/hud.dart';
import '../overlays/level_complete.dart';
import '../overlays/level_failed.dart';
import '../overlays/pause_menu.dart';
import '../palette.dart';
import '../widgets/touch_controls.dart';
import 'level_select_screen.dart';

/// Loads [levelId] out of its shard and opens it.
///
/// The pack is sharded, so reaching a level is asynchronous where it used to be
/// a list lookup. It is one asset read of a few hundred kilobytes, and the
/// shard holding the next level is nearly always the one already in memory, so
/// there is nothing here worth showing a spinner for. A level that does not
/// exist does nothing rather than throwing: the id comes from a grid built off
/// the pack's own count, so the only way to miss is a pack that shrank.
Future<LevelOpening?> openingFor(int levelId) async {
  final level = await levelRepository.byId(levelId);
  if (level == null) return null;
  return LevelOpening(level, await levelRepository.count());
}

/// A level and how many there are, which is all [GameScreen] needs to know
/// about the pack it came from.
class LevelOpening {
  const LevelOpening(this.level, this.levelCount);

  final LevelModel level;
  final int levelCount;
}

/// Levels cleared since the app was opened.
///
/// Deliberately not persisted: 'ten in a row' means one sitting, and a count
/// that survived a restart would make it mean nothing.
int levelsClearedThisSession = 0;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    required this.levelCount,
  });

  /// The level being played. Handed in already loaded rather than looked up
  /// here, so the screen itself stays synchronous and testable.
  final LevelModel level;

  /// How many levels are in the pack, which is the only thing this screen uses
  /// the rest of the pack for: deciding whether there is a next level.
  final int levelCount;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const String _hud = 'hud';
  static const String _controls = 'controls';
  static const String _complete = 'complete';
  static const String _failed = 'failed';
  static const String _pause = 'pause';

  late final PitchpoleGame _game;
  final FocusNode _focus = FocusNode();

  int _stars = 0;
  int _coins = 0;
  double _seconds = 0;
  double? _previousBest;

  /// Lives bought back with an ad on this attempt, capped at
  /// [kMaxRewardedLives]. Reset by [_restart], and naturally zero on a new
  /// level because that is a new screen.
  int _revivesUsed = 0;

  LevelModel get _level => widget.level;
  bool get _hasNext => _level.id < widget.levelCount;

  @override
  void initState() {
    super.initState();
    _game = PitchpoleGame(
      level: _level,
      hapticsEnabled: progressStore.hapticsEnabled,
      soundEnabled: progressStore.soundEnabled,
      musicEnabled: progressStore.musicEnabled,
      onWin: _onWin,
      onRunOut: _onRunOut,
      onLifeLost: _onLifeLost,
    );

    // The volumes have to be on the player before onLoad starts the music,
    // or the loop begins at full and drops when the first change arrives.
    _applyAudioSettings();

    // Sound, music and both volumes are all adjustable from the pause menu,
    // so the run has to pick changes up rather than waiting for the next
    // level.
    progressStore.addListener(_applyAudioSettings);

    // Held still until the break ad is out of the way. The level is already
    // on screen behind it, so the player sees where they are about to be
    // rather than a black screen with an ad on it.
    _game.paused = true;
    _game.lockInput();
    unawaited(_openLevel());
  }

  /// The ad before a level starts.
  ///
  /// Awaited, but [AdsController.showAtBreak] returns straight away when
  /// nothing is loaded, so this is not a wait the player can be made to sit
  /// through: no ad means the run simply starts.
  Future<void> _openLevel() async {
    // Counted here rather than on a win, so an evening spent failing a hard
    // level still counts as having played. Before the ad, because whether an
    // ad happened to be loaded has nothing to do with whether they turned up.
    unawaited(progressStore.notePlayed());

    await adsController.showAtBreak();
    if (!mounted) return;
    _game.paused = false;
    _game.unlockInput();
    _focus.requestFocus();
  }

  /// A life went. An ad goes in the gap before the checkpoint, and the
  /// respawn waits on this.
  ///
  /// Returns as soon as there is nothing loaded, which is most of the time on
  /// a bad connection, so the respawn stays as immediate as it ever was.
  Future<void> _onLifeLost() {
    unawaited(progressStore.recordDeath(_level.id));
    // Line the extra life up now, while there is still a life in hand. It has
    // to be loaded *before* the last one goes: fetching it at the moment the
    // panel appears means the offer arrives after the player has already read
    // the panel and decided, or does not arrive at all.
    adsController.preloadRewarded();
    return adsController.showAtBreak();
  }

  void _applyAudioSettings() => _game.applyAudioSettings(
        sound: progressStore.soundEnabled,
        music: progressStore.musicEnabled,
        soundVolume: progressStore.soundVolume,
        musicVolume: progressStore.musicVolume,
      );

  @override
  void dispose() {
    progressStore.removeListener(_applyAudioSettings);
    _focus.dispose();
    super.dispose();
  }

  void _onWin(int stars, double seconds) {
    final coins = _game.sim.state.coins;
    setState(() {
      _stars = stars;
      _seconds = seconds;
      _coins = coins;
      _previousBest = progressStore.bestSecondsFor(_level.id);
    });
    unawaited(_recordAndAward(stars, seconds, coins));
    _game.overlays.add(_complete);
  }

  /// Saves the result, then works out what it earned.
  ///
  /// Awarding happens after the save so every rule reads the same totals the
  /// player can see, and it is awaited by nothing on screen: an achievement is
  /// a note sent after the fact and must never hold up the cleared panel.
  Future<void> _recordAndAward(int stars, double seconds, int coins) async {
    await progressStore.record(
      _level.id,
      stars,
      seconds,
      coins: coins,
      coinsOnLevel: _level.coins.length,
    );

    levelsClearedThisSession++;

    await awardFor(
      RunOutcome(
        levelId: _level.id,
        stars: stars,
        coins: coins,
        coinsOnLevel: _level.coins.length,
        runSpeed: _level.runSpeed,
        jumps: _game.jumpsUsed,
        flips: _game.flipsUsed,
        deathsOnLevel: progressStore.deathsFor(_level.id),
        levelsThisSession: levelsClearedThisSession,
      ),
      progressStore,
      achievements,
    );

    // Same standing as an achievement: a note sent after the fact, awaited by
    // nothing on screen, and read by no part of a run. The figure is taken off
    // the store rather than off this run, so a replay of an old level submits
    // the same total as anything else.
    await leaderboards.submitTotals(progressStore);

    // Queued rather than sent. Finishing a level is the moment there is
    // something new worth keeping, but a player running through short levels
    // would upload every thirty seconds, so the write waits for the run to
    // settle. Returns immediately either way.
    cloudSave.scheduleSave();
  }

  /// The last life went, which is the only failure the game has: an ordinary
  /// death respawns at the last checkpoint with nothing in the way.
  ///
  /// The overlay goes up first and the ad over the top of it, so dismissing
  /// the ad lands the player on the panel that explains what happened rather
  /// than on a level that is already over.
  void _onRunOut() {
    // The last life is still a life lost, and it does not come through
    // _onLifeLost — that gate only runs when there is something to respawn to.
    unawaited(progressStore.recordDeath(_level.id));
    _game.overlays.add(_failed);
    unawaited(adsController.showAtBreak());
  }

  void _openPause() {
    _game.lockInput();
    _game.paused = true;
    _game.overlays.add(_pause);
  }

  void _closePause() {
    _game.overlays.remove(_pause);
    _game.paused = false;
    _game.unlockInput();
    _focus.requestFocus();
  }

  /// Watch a rewarded ad for one more life, and carry on from the last
  /// checkpoint instead of the start of the level.
  ///
  /// The reward is granted only by the SDK's own earned callback, so closing
  /// the ad early gives nothing — but it also costs nothing: the panel is
  /// still there with the same three ways out. A run is never lost because an
  /// ad failed to play.
  Future<void> _watchForExtraLife() async {
    // Guarded here as well as in the panel, because the panel is only a view:
    // an ad that finished as the count ran out must not slip a third life
    // through on a callback.
    if (_revivesUsed >= kMaxRewardedLives) return;

    final earned = await adsController.showForExtraLife();
    if (!mounted || !earned) return;

    // Counted only once the SDK says the ad was watched, so an ad closed early
    // costs the player nothing — neither a life nor one of their two chances.
    _revivesUsed++;

    _game.overlays.remove(_failed);
    _game.revive();
    _focus.requestFocus();
  }

  void _restart() {
    _game.overlays
      ..remove(_pause)
      ..remove(_failed)
      ..remove(_complete);
    _game.paused = false;
    // A new attempt, so the two chances come back. The cap is on grinding one
    // attempt out an ad at a time, not on how often a level may be played.
    _revivesUsed = 0;
    _game.restart();
    _focus.requestFocus();
  }

  Future<void> _goToLevel(int levelId) async {
    final opening = await openingFor(levelId);
    if (opening == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: opening.level,
          levelCount: opening.levelCount,
        ),
      ),
    );
  }

  void _goToLevelSelect() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LevelSelectScreen()),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      // Up and Down are absolute, never a toggle.
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _game.press(RunInput.flipUp);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _game.press(RunInput.flipDown);
      case LogicalKeyboardKey.space:
        _game.press(RunInput.jump);
      case LogicalKeyboardKey.keyR:
        _restart();
      case LogicalKeyboardKey.escape:
        if (_game.overlays.isActive(_pause)) {
          _closePause();
        } else {
          _openPause();
        }
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GameWidget<PitchpoleGame>(
          game: _game,
          backgroundBuilder: (context) => const _Letterbox(),
          overlayBuilderMap: {
            // The controls sit under the HUD, so the pause button still wins.
            _controls: (context, game) => AnimatedBuilder(
                  animation: progressStore,
                  builder: (context, _) => ValueListenableBuilder<RunState>(
                    valueListenable: game.stateNotifier,
                    builder: (context, state, _) => TouchControls(
                      onInput: game.press,
                      gravityUp: state.gravityUp,
                      scheme: progressStore.controlScheme,
                      showHints: _level.id == 1,
                    ),
                  ),
                ),
            _hud: (context, game) => Hud(game: game, onPause: _openPause),
            _complete: (context, game) => LevelComplete(
                  stars: _stars,
                  seconds: _seconds,
                  bestSeconds: _previousBest,
                  coins: _coins,
                  totalCoins: _level.coins.length,
                  hasNext: _hasNext,
                  onNext: () => _goToLevel(_level.id + 1),
                  onRetry: _restart,
                  onLevels: _goToLevelSelect,
                ),
            _failed: (context, game) => LevelFailed(
                  onRetry: _restart,
                  onLevels: _goToLevelSelect,
                  onExtraLife: _watchForExtraLife,
                  extraLivesLeft: kMaxRewardedLives - _revivesUsed,
                ),
            _pause: (context, game) => PauseMenu(
                  levelId: _level.id,
                  seconds: _level.seconds,
                  onResume: _closePause,
                  onRestart: _restart,
                  onLevels: _goToLevelSelect,
                ),
          },
          initialActiveOverlays: const [_controls, _hud],
        ),
      ),
    );
  }
}

/// Fills the letterbox with the two colours the scene already ends on.
///
/// The play field is a fixed 560 by 220, which is a wider shape than any phone
/// held sideways, so it is scaled to the screen's width and leaves a band above
/// and below. Those bands are unavoidable — stretching the field would show
/// some players more of the level than others, and the whole pack is tuned on
/// everyone seeing the same distance ahead.
///
/// What is avoidable is them being black, which reads as the game failing to
/// fill the screen. The canvas ends on flat sky along its top edge and flat
/// deep soil along its bottom, so continuing those two colours outwards makes
/// the forest run to both edges instead.
class _Letterbox extends StatelessWidget {
  const _Letterbox();

  @override
  Widget build(BuildContext context) => const CustomPaint(
        painter: _LetterboxPainter(),
        size: Size.infinite,
      );
}

class _LetterboxPainter extends CustomPainter {
  const _LetterboxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The same fit the fixed resolution viewport does, so the seam lands in
    // exactly the same place.
    final scale = min(size.width / kCanvasWidth, size.height / kCanvasHeight);
    final bar = (size.height - kCanvasHeight * scale) / 2;

    // Nothing to fill: the screen is wider than the field, so what is left
    // over is at the sides rather than above and below. No flat colour can
    // stand in for the scene there, since a vertical slice of it runs sky,
    // band, earth. No phone is this shape; a very wide window can be.
    if (bar <= 0) return;

    // A pixel of overlap. The game is drawn on top of this, so the only thing
    // it can cause is the seam being covered rather than a hairline of black
    // showing through it at some fractional scale.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, bar + 1),
      Paint()..color = Palette.skyHigh,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - bar - 1, size.width, bar + 1),
      Paint()..color = Palette.earthDark,
    );
  }

  @override
  bool shouldRepaint(_LetterboxPainter oldDelegate) => false;
}
