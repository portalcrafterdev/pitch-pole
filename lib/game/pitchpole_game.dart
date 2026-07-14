import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/palette.dart';
import 'components/blade_obstacle.dart';
import 'components/bolted_enemy.dart';
import 'components/door.dart';
import 'components/hopper_enemy.dart';
import 'components/stone_obstacle.dart';
import 'components/parallax_backdrop.dart';
import 'components/player.dart';
import 'components/surface_strip.dart';
import 'logic/level_model.dart';
import 'logic/level_simulator.dart';
import 'logic/physics.dart';
import 'logic/run_state.dart';
import 'sound.dart';

/// Owns one level: the fixed step simulation, the scene, and the feel.
///
/// Every rule lives in [LevelSimulator]. This class only feeds it input and
/// draws the result, so what the level tests prove is what the player gets.
class PitchpoleGame extends FlameGame {
  PitchpoleGame({
    required LevelModel level,
    required this.onWin,
    required this.onRunOut,
    this.hapticsEnabled = true,
    bool soundEnabled = true,
    bool musicEnabled = true,
  })  : sim = LevelSimulator(level),
        _sound = SoundPlayer(
          enabled: soundEnabled,
          musicEnabled: musicEnabled,
        ),
        super(
          camera: CameraComponent.withFixedResolution(
            width: kCanvasWidth,
            height: kCanvasHeight,
          ),
        );

  final LevelSimulator sim;

  /// Stars and the finishing time.
  final void Function(int stars, double seconds) onWin;

  /// The last life went and the level restarted from the beginning.
  final VoidCallback onRunOut;

  final bool hapticsEnabled;
  final SoundPlayer _sound;

  LevelModel get level => sim.level;

  late final ValueNotifier<RunState> stateNotifier =
      ValueNotifier(sim.state.copy());

  late final PlayerComponent _player;
  late final DoorComponent _door;
  late final SurfaceStrip _strip;
  late final ParallaxBackdrop _backdrop;
  final List<HopperEnemy> _hoppers = [];
  final List<BladeObstacle> _blades = [];
  final List<StoneObstacle> _stones = [];

  final Random _random = Random();
  final List<RunInput> _queued = [];

  double _accumulator = 0;
  double _deathPause = 0;
  double _winPause = 0;
  double _shake = 0;
  double _shakeFor = 0;
  bool _inputLocked = false;

  /// How long the game holds still after a death before respawning.
  static const double kDeathPause = 0.7;

  /// How long the finish line burst plays before the cleared overlay comes up.
  /// Ending a run should be a moment, not a cut.
  static const double kWinPause = DoorComponent.burstDuration;

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    unawaited(_sound.preload());
    unawaited(_sound.startMusic());

    _backdrop = ParallaxBackdrop();
    _strip = SurfaceStrip();
    camera.backdrop.addAll([_backdrop, _strip]);

    for (final enemy in level.bolted) {
      world.add(BoltedEnemy(enemy));
    }
    for (final enemy in level.hoppers) {
      final component = HopperEnemy(enemy, level.hopPeriod);
      _hoppers.add(component);
      world.add(component);
    }
    for (final blade in level.blades) {
      final component = BladeObstacle(blade);
      _blades.add(component);
      world.add(component);
    }
    for (final stone in level.stones) {
      final component = StoneObstacle(stone);
      _stones.add(component);
      world.add(component);
    }

    _door = DoorComponent(x: level.length);
    world.add(_door);

    _player = PlayerComponent();
    world.add(_player);

    camera.viewfinder.position = _cameraTarget();
    _syncScene();
  }

  Vector2 _cameraTarget() => Vector2(
        sim.state.x + kCanvasWidth / 2 - kPlayerScreenX,
        kCanvasHeight / 2,
      );

  bool get acceptsInput =>
      !_inputLocked && sim.state.isRunning && _deathPause <= 0;

  void lockInput() => _inputLocked = true;
  void unlockInput() => _inputLocked = false;

  /// Queued, then drained at the next fixed step, so input never lands
  /// mid step and break determinism.
  void press(RunInput input) {
    if (!acceptsInput || input == RunInput.none) return;
    _queued.add(input);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_winPause > 0) {
      // The simulation has already stopped. Everything still ticks, so the
      // finish line burst and the character's cheer play out on screen.
      _winPause = max(0, _winPause - dt);
      if (_winPause == 0) _announceWin();
    } else if (_deathPause > 0) {
      _deathPause = max(0, _deathPause - dt);
      if (_deathPause == 0) _respawn();
    } else if (sim.state.isRunning && !_inputLocked) {
      // Fixed timestep with an accumulator: the same level behaves the same
      // on a 60 and a 120 hertz screen.
      _accumulator += min(dt, 0.25);
      while (_accumulator >= kFixedStep && sim.state.isRunning) {
        _accumulator -= kFixedStep;
        _drainInput();
        final wasAirborne = !sim.state.grounded;
        sim.step();
        if (wasAirborne && sim.state.grounded && sim.state.isRunning) {
          _player.onLand();
          _sound.play(Sfx.land, volume: 0.7);
        }
        if (!sim.state.isRunning) _onRunEnded();
      }
    }

    _advanceShake(dt);
    _syncScene();
  }

  void _drainInput() {
    if (_queued.isEmpty) return;
    for (final input in _queued) {
      final before = sim.state.gravityUp;
      final grounded = sim.state.grounded;
      sim.input(input);
      if (input == RunInput.jump && grounded) {
        _player.onJump();
        _sound.play(Sfx.jump, volume: 0.8);
      } else if (sim.state.gravityUp != before) {
        _player.onFlip(toCeiling: sim.state.gravityUp);
        _sound.play(Sfx.flip);
        _haptic(HapticFeedback.selectionClick);
      }
    }
    _queued.clear();
  }

  void _onRunEnded() {
    if (sim.state.status == RunStatus.won) {
      _sound.play(Sfx.land, volume: 0.9);
      _haptic(HapticFeedback.lightImpact);
      _inputLocked = true;
      _door.celebrate();
      _player.onCheer(gravityUp: sim.state.gravityUp);
      _winPause = kWinPause;
      return;
    }

    _sound.play(Sfx.death);
    _haptic(HapticFeedback.heavyImpact);
    _player.onDeath();
    _shakeCamera();
    _deathPause = kDeathPause;
  }

  /// Hands the result to the screen, once the burst has been seen.
  void _announceWin() {
    final lives = sim.state.lives;
    onWin(
      lives >= kStartingLives ? 3 : (lives == 2 ? 2 : 1),
      sim.state.elapsed,
    );
  }

  void _respawn() {
    final wasLastLife = sim.outOfLives;
    sim.respawn();
    _player.reset();
    _accumulator = 0;
    _queued.clear();
    camera.viewfinder.position = _cameraTarget();
    if (wasLastLife) {
      _inputLocked = true;
      onRunOut();
    }
  }

  /// Full restart: back to the start of the level with three lives and a
  /// fresh clock.
  void restart() {
    sim.restart();
    _player.reset();
    _door.reset();
    _accumulator = 0;
    _deathPause = 0;
    _winPause = 0;
    _queued.clear();
    _inputLocked = false;
    camera.viewfinder.position = _cameraTarget();
    _syncScene();
  }

  void _syncScene() {
    final state = sim.state;

    _player.syncTo(state.x, state.y, state.vy);

    final levelTime = state.levelTimeAt(level.runSpeed);
    for (final hopper in _hoppers) {
      hopper.syncTo(levelTime);
    }
    for (final blade in _blades) {
      blade.syncTo(levelTime);
    }
    for (final stone in _stones) {
      stone.syncTo(levelTime);
    }

    if (_shake == 0) camera.viewfinder.position = _cameraTarget();
    final left = camera.viewfinder.position.x - kCanvasWidth / 2;
    _strip.scrollX = left;
    _backdrop.scrollX = left;

    stateNotifier.value = state.copy();
  }

  void _shakeCamera({double amount = 4, double duration = 0.3}) {
    _shake = duration;
    _shakeFor = duration;
    _shakeAmount = amount;
  }

  double _shakeAmount = 4;

  void _advanceShake(double dt) {
    if (_shake <= 0) return;
    _shake = max(0, _shake - dt);
    final decay = _shakeFor == 0 ? 0.0 : _shake / _shakeFor;
    final home = _cameraTarget();
    camera.viewfinder.position = _shake == 0
        ? home
        : home +
            Vector2(
              _random.nextDouble() * 2 - 1,
              _random.nextDouble() * 2 - 1,
            ) *
                (_shakeAmount * decay);
  }

  void _haptic(Future<void> Function() feedback) {
    if (hapticsEnabled) feedback();
  }

  @override
  void onRemove() {
    unawaited(_sound.stopMusic());
    stateNotifier.dispose();
    super.onRemove();
  }
}
