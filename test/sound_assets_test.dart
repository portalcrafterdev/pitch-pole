import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/menu_audio.dart';
import 'package:pitchpole/data/progress_store.dart';
import 'package:pitchpole/game/sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ascii(ByteData data, int offset, int length) => String.fromCharCodes([
      for (var i = 0; i < length; i++) data.getUint8(offset + i),
    ]);

void main() {
  // The music tests reach a platform channel. Without a binding that call
  // never gets a reply at all and the test hangs instead of failing; with one
  // it comes straight back as unimplemented, which is the path a phone with
  // no working audio takes too.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // The background player is one object for the whole app, so ownership of
    // it outlives a test unless it is handed back.
    final owner = SoundPlayer.debugMusicOwner;
    if (owner is SoundPlayer) await owner.stopMusic();
  });

  test('every sound the game asks for exists', () {
    expect(Sfx.all,
        ['land.wav', 'flip.wav', 'jump.wav', 'death.wav', 'win.wav', 'tap.wav']);

    for (final name in [...Sfx.all, Music.loop]) {
      expect(File('assets/audio/$name').existsSync(), isTrue,
          reason: 'missing assets/audio/$name, run tool/make_sounds.dart');
    }
  });

  test('the sounds are playable 16 bit mono WAV', () {
    for (final name in Sfx.all) {
      final bytes = File('assets/audio/$name').readAsBytesSync();
      final data = ByteData.sublistView(bytes);

      expect(_ascii(data, 0, 4), 'RIFF', reason: '$name is not a RIFF file');
      expect(_ascii(data, 8, 4), 'WAVE', reason: '$name is not a WAVE file');
      expect(data.getUint16(20, Endian.little), 1, reason: '$name is not PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: '$name is not mono');
      expect(data.getUint16(34, Endian.little), 16,
          reason: '$name is not 16 bit');

      final declared = data.getUint32(40, Endian.little);
      expect(bytes.length, 44 + declared,
          reason: '$name declares $declared bytes of audio it does not have');
      expect(declared, greaterThan(0), reason: '$name is silent');
    }
  });

  test('every file is written loud enough to hear on a phone speaker', () {
    // The generators each had their own hand tuned output multiplier, which
    // left the music peaking more than five times below full scale. Playback
    // volume cannot rescue that: it is a multiplier, and a fraction of very
    // little is still very little. Every file is normalised now, so the
    // balance is set in Mix and nowhere else.
    for (final name in [...Sfx.all, Music.loop]) {
      final data =
          ByteData.sublistView(File('assets/audio/$name').readAsBytesSync());
      final samples = data.getUint32(40, Endian.little) ~/ 2;

      var loudest = 0;
      for (var i = 0; i < samples; i++) {
        final level = data.getInt16(44 + i * 2, Endian.little).abs();
        if (level > loudest) loudest = level;
      }

      expect(loudest / 32767, closeTo(0.92, 0.01),
          reason: '$name peaks at ${(loudest / 32767 * 100).round()}% of full '
              'scale, run tool/make_sounds.dart');
    }
  });

  test('the sounds are short enough to fire on every press', () {
    for (final name in Sfx.all) {
      final data = ByteData.sublistView(File('assets/audio/$name').readAsBytesSync());
      final rate = data.getUint32(24, Endian.little);
      final millis = data.getUint32(40, Endian.little) / 2 / rate * 1000;

      expect(millis, lessThan(500), reason: '$name runs $millis ms, too long');
    }
  });

  test('the music loop is a whole number of seconds of playable audio', () {
    // It plays end to end forever, so a wrong header here is not a glitch,
    // it is a click every eight seconds for the length of the run.
    final data =
        ByteData.sublistView(File('assets/audio/${Music.loop}').readAsBytesSync());

    expect(_ascii(data, 0, 4), 'RIFF');
    expect(data.getUint16(22, Endian.little), 1, reason: 'not mono');
    final rate = data.getUint32(24, Endian.little);
    final seconds = data.getUint32(40, Endian.little) / 2 / rate;

    expect(seconds, closeTo(8, 0.01),
        reason: 'CLAUDE.md asks for an eight second loop');
  });

  group('the background loop survives a level change', () {
    // There is one background player for the whole app but a SoundPlayer per
    // level, and moving to the next level starts the new level's music before
    // the old level has finished tearing itself down. Ownership is what stops
    // the outgoing level silencing the incoming one.
    //
    // No audio plugin exists under `flutter test`, so the play itself fails
    // and is swallowed. Ownership is claimed before that happens, which is
    // exactly the part being checked.
    test('the level being left behind does not stop it', () async {
      final leaving = SoundPlayer(enabled: false, musicEnabled: true);
      final arriving = SoundPlayer(enabled: false, musicEnabled: true);

      await leaving.startMusic();
      expect(SoundPlayer.debugMusicOwner, same(leaving));

      await arriving.startMusic();
      expect(SoundPlayer.debugMusicOwner, same(arriving),
          reason: 'the level starting up takes the music over');

      await leaving.stopMusic();
      expect(SoundPlayer.debugMusicOwner, same(arriving),
          reason: 'this is the bug: the outgoing level tidying up must not '
              'silence the level that just started');

      await arriving.stopMusic();
      expect(SoundPlayer.debugMusicOwner, isNull,
          reason: 'but the owner still stops it on the way out');
    });

    test('music off never claims it', () async {
      final silent = SoundPlayer(enabled: true, musicEnabled: false);
      await silent.startMusic();

      expect(SoundPlayer.debugMusicOwner, isNull);
    });
  });

  group('the menus have a bed of their own', () {
    // The whole front of the game used to be silent: every sound lived inside
    // PitchpoleGame, so nothing played until a level had loaded. The menus
    // queue up behind the same ownership rule the levels do, which is what
    // makes pressing PLAY seamless rather than a restart.
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await progressStore.load();
    });

    test('the menu holds the loop, and hands it to the level', () async {
      await MenuAudio.instance.start();
      expect(SoundPlayer.debugMusicOwner, isNotNull,
          reason: 'the menu starts the bed before a level ever exists');

      final level = SoundPlayer(enabled: false, musicEnabled: true);
      await level.startMusic();
      expect(SoundPlayer.debugMusicOwner, same(level),
          reason: 'pressing PLAY hands the running loop to the level');

      // The level cannot know a menu is what comes next rather than another
      // level, so it stops the music on the way out and the menu asks for it
      // back. Without that the app is silent for the rest of the session.
      await level.stopMusic();
      expect(SoundPlayer.debugMusicOwner, isNull);

      await MenuAudio.instance.start();
      expect(SoundPlayer.debugMusicOwner, isNotNull,
          reason: 'coming back to the menu takes the bed back');
    });

    test('the saved volumes are on the player before the first note',
        () async {
      // Reported from a real session: the sliders came back showing the
      // reduced levels, but the game played at full until one of them was
      // touched. The setting was being read for the display and not put on
      // the player, so the menu bed opened at full volume every launch.
      await progressStore.setSoundVolume(0.3);
      await progressStore.setMusicVolume(0.15);

      await MenuAudio.instance.start();

      expect(MenuAudio.instance.debugPlayer.soundVolume, 0.3);
      expect(MenuAudio.instance.debugPlayer.musicVolume, 0.15,
          reason: 'the bed has to start at the saved level, not drop to it '
              'when the slider is next moved');
    });

    test('a later change to the volume still reaches the player', () async {
      // The guard against fixing the above by syncing in the wrong place: the
      // change handler compares the two values to decide whether to move a
      // loop that is already playing, so a sync there would make them always
      // equal and nothing would ever move.
      await progressStore.setMusicVolume(0.9);
      await MenuAudio.instance.start();

      await progressStore.setMusicVolume(0.2);
      await Future<void>.delayed(Duration.zero);

      expect(MenuAudio.instance.debugPlayer.musicVolume, 0.2);
    });

    test('turning music off in the settings stops the menu bed', () async {
      await MenuAudio.instance.start();
      expect(SoundPlayer.debugMusicOwner, isNotNull);

      await progressStore.setMusic(false);
      // The store notifies synchronously; the stop it triggers does not.
      await Future<void>.delayed(Duration.zero);

      expect(SoundPlayer.debugMusicOwner, isNull,
          reason: 'the menu follows the same switch the run does');
    });
  });

  test('the audio folder is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/'));
  });
}
