import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/sound.dart';

String _ascii(ByteData data, int offset, int length) => String.fromCharCodes([
      for (var i = 0; i < length; i++) data.getUint8(offset + i),
    ]);

void main() {
  test('every sound the game asks for exists', () {
    expect(Sfx.all, ['land.wav', 'flip.wav', 'jump.wav', 'death.wav']);

    for (final name in Sfx.all) {
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

  test('the sounds are short enough to fire on every press', () {
    for (final name in Sfx.all) {
      final data = ByteData.sublistView(File('assets/audio/$name').readAsBytesSync());
      final rate = data.getUint32(24, Endian.little);
      final millis = data.getUint32(40, Endian.little) / 2 / rate * 1000;

      expect(millis, lessThan(500), reason: '$name runs $millis ms, too long');
    }
  });

  test('the audio folder is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/'));
  });
}
