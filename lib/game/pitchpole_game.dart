import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/palette.dart';
import 'components/bat_enemy.dart';
import 'components/blade_obstacle.dart';
import 'components/bolted_enemy.dart';
import 'components/coin_pickup.dart';
import 'components/door.dart';
import 'components/fire_obstacle.dart';
import 'components/hopper_enemy.dart';
import 'components/spider_enemy.dart';
import 'components/stone_obstacle.dart';
import 'components/parallax_backdrop.dart';
import 'components/player.dart';
import 'components/surface_strip.dart';
import 'logic/level_model.dart';
import 'logic/level_simulator.dart';
import 'logic/physics.dart';
import 'logic/run_state.dart';
import 'scene_theme.dart';
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
    this.onLifeLost,
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

  /// A life went, but not the last one.
  ///
  /// The respawn waits on whatever this returns, which is what lets an ad sit
  /// between the death and the checkpoint. Null means respawn straight away —
  /// that is what the tests use, and it is the behaviour to fall back to if
  /// the ad break is ever taken out again.
  final Future<void> Function()? onLifeLost;

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
  final List<FireObstacle> _fires = [];
  final List<BatEnemy> _bats = [];
  final List<SpiderEnemy> _spiders = [];
  final List<CoinPickup> _coins = [];

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

  /// Behind the canvas, which is only ever seen for the instant before the
  /// first frame is drawn.
  ///
  /// The letterbox above and below the canvas is not this: it is painted by
  /// `_Letterbox` in `game_screen.dart`, which continues the sky at the top
  /// and the soil at the bottom. One colour could never have done that job —
  /// sky reads fine above the canopy and like water below the earth.
  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    unawaited(_sound.preload());
    unawaited(_sound.startMusic());

    // The place this level is set in, derived from its number so it is fixed
    // for that level forever and costs the level pack nothing.
    final theme = SceneTheme.forLevel(level.id);
    _backdrop = ParallaxBackdrop(theme: theme);
    _strip = SurfaceStrip(theme: theme);
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

    for (final fire in level.fires) {
      final component = FireObstacle(fire);
      _fires.add(component);
      world.add(component);
    }

    for (final bat in level.bats) {
      final component = BatEnemy(bat);
      _bats.add(component);
      world.add(component);
    }

    for (final spider in level.spiders) {
      final component = SpiderEnemy(spider);
      _spiders.add(component);
      world.add(component);
    }

    for (final coin in level.coins) {
      final component = CoinPickup(coin);
      _coins.add(component);
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
        if (sim.justCollected.isNotEmpty) _onCoinsCollected();
        if (wasAirborne && sim.state.grounded && sim.state.isRunning) {
          _player.onLand();
          _sound.play(Sfx.land, volume: Mix.land);
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
        _sound.play(Sfx.jump, volume: Mix.jump);
      } else if (sim.state.gravityUp != before) {
        _player.onFlip(toCeiling: sim.state.gravityUp);
        _sound.play(Sfx.flip, volume: Mix.flip);
        _haptic(HapticFeedback.selectionClick);
      }
    }
    _queued.clear();
  }

  /// Pops the coins the simulator just picked up. One click however many
  /// landed on the same step, so a cluster does not stack into a clatter.
  void _onCoinsCollected() {
    for (final i in sim.justCollected) {
      _coins[i].collect();
    }
    _sound.play(Sfx.jump, volume: Mix.coin);
  }

  void _onRunEnded() {
    if (sim.state.status == RunStatus.won) {
      _sound.play(Sfx.win, volume: Mix.win);
      _haptic(HapticFeedback.lightImpact);
      _inputLocked = true;
      _door.celebrate();
      _player.onCheer(gravityUp: sim.state.gravityUp);
      _winPause = kWinPause;
      return;
    }

    _sound.play(Sfx.death, volume: Mix.death);
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
    if (sim.outOfLives) {
      // Nothing is reset here, on purpose. The extra life a player can earn
      // continues the run from the last checkpoint, and respawn() on the last
      // life throws exactly that away by putting the level back to the start.
      // Whatever happens next decides: [revive] continues, [restart] resets.
      _inputLocked = true;
      onRunOut();
      return;
    }

    final gate = onLifeLost;
    if (gate == null) {
      _completeRespawn();
      return;
    }

    // Held here until the screen says go. Input is locked and the run is
    // already dead, so update() does nothing at all in the meantime — the
    // character stays where it died rather than the level ticking on behind
    // whatever is being shown.
    _inputLocked = true;
    unawaited(gate().then((_) {
      if (isMounted) _completeRespawn();
    }));
  }

  void _completeRespawn() {
    sim.respawn();
    _syncCoins();
    _player.reset();
    _accumulator = 0;
    _queued.clear();
    _inputLocked = false;
    camera.viewfinder.position = _cameraTarget();
  }

  /// Applies the sound and music switches to the run already in progress.
  ///
  /// The player changes these from the pause menu, mid level, and expects to
  /// hear the result when they resume rather than on the next level.
  void applyAudioSettings({
    required bool sound,
    required bool music,
    double soundVolume = 1,
    double musicVolume = 1,
  }) {
    if (sound && !_sound.enabled) {
      // The pools are only built when sound was on at start up, so turning it
      // on mid run has to warm them or the rest of the level is silent.
      unawaited(SoundPlayer.warmUp());
    }
    _sound.enabled = sound;
    _sound.soundVolume = soundVolume;

    if (musicVolume != _sound.musicVolume) {
      unawaited(_sound.applyMusicVolume(musicVolume));
    }

    if (music == _sound.musicEnabled) return;
    _sound.musicEnabled = music;
    unawaited(music ? _sound.startMusic() : _sound.stopMusic());
  }

  /// An extra life, beyond the three the level starts with. Picks the run up
  /// at the last checkpoint rather than the beginning.
  void revive() {
    sim.revive();
    _syncCoins();
    _player.reset();
    _accumulator = 0;
    _deathPause = 0;
    _queued.clear();
    _inputLocked = false;
    camera.viewfinder.position = _cameraTarget();
    _syncScene();
  }

  /// Full restart: back to the start of the level with three lives and a
  /// fresh clock.
  void restart() {
    sim.restart();
    _syncCoins();
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

  /// Brings the coins back in line with the simulator after a respawn or a
  /// restart. The simulator is the authority on which ones are gone.
  void _syncCoins() {
    for (var i = 0; i < _coins.length; i++) {
      if (sim.isCollected(i)) {
        _coins[i].collect();
      } else {
        _coins[i].reset();
      }
    }
  }

  void _syncScene() {
    final state = sim.state;

    _player.syncTo(state.x, state.y, state.vy, grounded: state.grounded);

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
    for (final fire in _fires) {
      fire.syncTo(levelTime);
    }
    for (final bat in _bats) {
      bat.syncTo(levelTime);
    }
    for (final spider in _spiders) {
      spider.syncTo(levelTime);
    }
    for (final coin in _coins) {
      coin.syncTo(levelTime);
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
