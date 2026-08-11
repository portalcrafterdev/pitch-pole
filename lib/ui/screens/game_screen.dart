import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ads.dart';
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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levels, required this.index});

  final List<LevelModel> levels;
  final int index;

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

  LevelModel get _level => widget.levels[widget.index];
  bool get _hasNext => widget.index + 1 < widget.levels.length;

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
    );

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
    await adsController.showAtBreak();
    if (!mounted) return;
    _game.paused = false;
    _game.unlockInput();
    _focus.requestFocus();
  }

  @override
  void dispose() {
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
    progressStore.record(_level.id, stars, seconds, coins: coins);
    _game.overlays.add(_complete);
  }

  /// The last life went, which is the only failure the game has: an ordinary
  /// death respawns at the last checkpoint with nothing in the way.
  ///
  /// The overlay goes up first and the ad over the top of it, so dismissing
  /// the ad lands the player on the panel that explains what happened rather
  /// than on a level that is already over.
  void _onRunOut() {
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

  void _restart() {
    _game.overlays
      ..remove(_pause)
      ..remove(_failed)
      ..remove(_complete);
    _game.paused = false;
    _game.restart();
    _focus.requestFocus();
  }

  void _goToLevel(int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(levels: widget.levels, index: index),
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
                  onNext: () => _goToLevel(widget.index + 1),
                  onRetry: _restart,
                  onLevels: _goToLevelSelect,
                ),
            _failed: (context, game) => LevelFailed(
                  onRetry: _restart,
                  onLevels: _goToLevelSelect,
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
