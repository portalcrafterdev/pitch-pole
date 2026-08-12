import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/sound.dart';
import 'progress_store.dart';

/// The sound the game makes when it is not running a level.
///
/// Every sound the game had lived inside `PitchpoleGame`: the music started in
/// its `onLoad` and stopped when it was removed, and the effects fired off the
/// simulation. That is the right home for all of them, and it left the whole
/// of the front of the game silent. A player who opened Pitchpole and pressed
/// PLAY heard nothing at all until the first level had loaded, and a button
/// press made no sound anywhere in the app.
///
/// This owns the two things that are not part of a run: the bed under the
/// menus, and the blip a button makes.
///
/// It deliberately does not own a second music player. There is one background
/// player for the whole app, and [SoundPlayer] already arbitrates who is
/// allowed to drive it, so the menus queue up behind exactly the same rule the
/// levels do. That is what makes pressing PLAY seamless: the level claims the
/// loop that is already playing rather than restarting it.
class MenuAudio {
  MenuAudio._();

  static final MenuAudio instance = MenuAudio._();

  /// Built once and kept, because ownership of the background loop is identity
  /// based. A fresh player per screen would hand the music between strangers.
  final SoundPlayer _player = SoundPlayer(enabled: true, musicEnabled: true);

  bool _listening = false;

  /// Starts the menu bed and begins following the settings.
  ///
  /// Safe to call as often as you like. It is called at start up and again
  /// every time a menu comes back to the front, because the level that was on
  /// top stopped the music on its way out.
  Future<void> start() async {
    _readSettings();

    // The stored music level, put on the player *before* the loop starts.
    //
    // Without this the bed began at full volume every launch and only dropped
    // to the saved level once the slider was touched, which reads as the
    // setting having been forgotten: the slider showed the right number while
    // the game played the wrong one. It is deliberately not in
    // [_readSettings], which runs again on every settings change and compares
    // the two values to decide whether to move a loop that is already
    // playing; syncing it there would make that comparison always equal.
    _player.musicVolume = progressStore.musicVolume;

    if (!_listening) {
      _listening = true;
      progressStore.addListener(_onSettingsChanged);
    }

    // The blip comes out of the same warm pools as the run's effects, so the
    // first press of PLAY is as quick as the hundredth.
    if (_player.enabled) await SoundPlayer.warmUp();

    await _player.startMusic();
  }

  /// Stops the bed. Only used when the player turns music off.
  Future<void> stop() => _player.stopMusic();

  /// Test seam: the player the menus drive, to check what the settings put on
  /// it without reaching an audio device.
  @visibleForTesting
  SoundPlayer get debugPlayer => _player;

  /// The blip under a button.
  ///
  /// Fire and forget, and silent rather than throwing if the pools are not up
  /// yet: a button that will not click is not a button that should not work.
  void tap() => _player.play(Sfx.tap, volume: Mix.tap);

  void _readSettings() {
    _player.enabled = progressStore.soundEnabled;
    _player.musicEnabled = progressStore.musicEnabled;
    _player.soundVolume = progressStore.soundVolume;
  }

  void _onSettingsChanged() {
    final wasMusicOn = _player.musicEnabled;
    _readSettings();

    // The slider is applied through the player rather than set on it, so
    // dragging it is heard while it moves instead of at the next level.
    if (_player.musicVolume != progressStore.musicVolume) {
      unawaited(_player.applyMusicVolume(progressStore.musicVolume));
    }

    if (_player.musicEnabled == wasMusicOn) return;
    unawaited(_player.musicEnabled ? _player.startMusic() : stop());
  }
}
