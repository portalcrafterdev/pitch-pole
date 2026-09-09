import 'dart:async';

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
import '../../game/logic/run_state.dart';
import '../../game/pitchpole_game.dart';
import '../../game/scene_theme.dart';
import '../overlays/hud.dart';
import '../overlays/level_complete.dart';
import '../overlays/level_failed.dart';
import '../overlays/pause_menu.dart';
import '../palette.dart';
import '../widgets/letterbox.dart';
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
  int _livesLost = 0;
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

    // No banner over a run. The whole screen is a control in the halves
    // scheme and the pads sit in the bottom corners in the other, so one near
    // the play field is a misplaced tap and an accidental click Google bills
    // back. Handed back in [dispose], whichever way the level ended.
    adsController.bannerAllowed = false;
    _openLevel();
  }

  /// Starts the run.
  ///
  /// There is no ad here any more. The break moved to the moment a level is
  /// cleared, so a level now begins the instant it is opened — see [_onWin].
  /// One is lined up while the run is going, so it is loaded by the time the
  /// door is reached.
  void _openLevel() {
    // Counted on opening rather than on a win, so an evening spent failing a
    // hard level still counts as having played.
    unawaited(progressStore.notePlayed());
    adsController.preload();
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
    // Forced, like the clear. The respawn is held until this returns, so the
    // ad is seen before the next life is spent rather than over the top of a
    // character already running again.
    return adsController.showAtBreak(force: true);
  }

  void _applyAudioSettings() => _game.applyAudioSettings(
        sound: progressStore.soundEnabled,
        music: progressStore.musicEnabled,
        soundVolume: progressStore.soundVolume,
        musicVolume: progressStore.musicVolume,
      );

  @override
  void dispose() {
    adsController.bannerAllowed = true;
    progressStore.removeListener(_applyAudioSettings);
    _focus.dispose();
    super.dispose();
  }

  void _onWin(int stars, double seconds) {
    final coins = _game.sim.state.coins;
    setState(() {
      // Read off the run rather than derived from the stars. Three stars is
      // always no lives lost, but one star is anything from two lost to a
      // dozen, and the panel should say which.
      _livesLost = kStartingLives - _game.sim.state.lives;
      _stars = stars;
      _seconds = seconds;
      _coins = coins;
      _previousBest = progressStore.bestSecondsFor(_level.id);
    });
    unawaited(_recordAndAward(stars, seconds, coins));
    _game.overlays.add(_complete);

    // The break, now that the level is behind them rather than in front.
    //
    // The panel goes up first and the ad over the top of it, the same way
    // running out of lives works: dismissing the ad lands the player on the
    // panel that says how the run went rather than on a level that is
    // already over.
    //
    // Forced past the ration, because a clear is the break this game is
    // built around now. Sharing one ration with deaths meant the deaths on
    // the way through a level ate the break the clear was meant to take, so
    // an ad turned up for failing and never for finishing.
    //
    // Not awaited, and it returns immediately when nothing is loaded, so a
    // player with no connection reaches the panel exactly as fast as they
    // did before ads existed.
    unawaited(adsController.showAtBreak(force: true));
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
    unawaited(adsController.showAtBreak(force: true));
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

  /// Back to the front door, whatever route was taken to get here.
  ///
  /// Popped to the root rather than pushed, because a level can be opened from
  /// the home screen or from level select and pushing a third copy of home on
  /// top of either would leave the back gesture walking through screens the
  /// player already left.
  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

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
          // The level's own place, so the bands above and below continue
          // this scene rather than the forest every level used to be.
          backgroundBuilder: (context) =>
              Letterbox(
                theme: SceneTheme.resolve(
                  _level.id,
                  progressStore.sceneryChoice,
                ),
              ),
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
                  levelId: _level.id,
                  stars: _stars,
                  livesLost: _livesLost,
                  seconds: _seconds,
                  bestSeconds: _previousBest,
                  coins: _coins,
                  totalCoins: _level.coins.length,
                  hasNext: _hasNext,
                  onNext: () => _goToLevel(_level.id + 1),
                  onRetry: _restart,
                  onLevels: _goToLevelSelect,
                  onHome: _goHome,
                ),
            _failed: (context, game) => LevelFailed(
                  onRetry: _restart,
                  onHome: _goHome,
                  onExtraLife: _watchForExtraLife,
                  extraLivesLeft: kMaxRewardedLives - _revivesUsed,
                ),
            _pause: (context, game) => PauseMenu(
                  levelId: _level.id,
                  seconds: _level.seconds,
                  onResume: _closePause,
                  onRestart: _restart,
                  onLevels: _goToLevelSelect,
                  onHome: _goHome,
                ),
          },
          initialActiveOverlays: const [_controls, _hud],
        ),
      ),
    );
  }
}

