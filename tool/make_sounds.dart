// Authoring tool. Synthesises the three sounds CLAUDE.md asks for and writes
// them to assets/audio as 16 bit mono WAV.
//
//   dart run tool/make_sounds.dart
//
// These are placeholders in the sense that no one recorded them, but they are
// the real shipped assets. Everything is deterministic, so re-running produces
// byte identical files. Tweak the numbers here rather than editing binaries.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  _write('${dir.path}/jump.wav', _click());
  _write('${dir.path}/tap.wav', _tap());
  _write('${dir.path}/flip.wav', _whoosh());
  _write('${dir.path}/land.wav', _land());
  _write('${dir.path}/death.wav', _death());
  _write('${dir.path}/win.wav', _win());
  _write('${dir.path}/music.wav', _music(), loop: true);

  for (final stale in ['click.wav']) {
    final file = File('${dir.path}/$stale');
    if (file.existsSync()) {
      file.deleteSync();
      stdout.writeln('removed stale ${file.path}');
    }
  }
}

/// A short, dry click. The jump.
List<double> _click() {
  const seconds = 0.045;
  final n = (sampleRate * seconds).round();
  final rng = Random(7);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = exp(-t * 95);
    final tone =
        sin(2 * pi * 1500 * t) * 0.6 + sin(2 * pi * 2450 * t) * 0.18;
    final noise = (rng.nextDouble() * 2 - 1) * 0.22;
    return (tone + noise) * env * 0.32;
  });
}

/// A soft, round blip for a menu button.
///
/// Deliberately not the jump click, which is the closest thing already in the
/// set. That one is a dry snap with noise through it, because it fires on a
/// control the player is working during a run and has to cut through the bed.
/// A menu tap has nothing to cut through, and it is the sound a child will
/// make dozens of times over on the front page for the pleasure of it, so it
/// is a rounded tone with the edge taken off: eased in rather than struck,
/// falling slightly as it goes, and no noise at all.
List<double> _tap() {
  const seconds = 0.07;
  final n = (sampleRate * seconds).round();
  final out = <double>[];
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final progress = i / n;
    phase += 2 * pi * (880 - 200 * progress) / sampleRate;
    // The attack is what separates a blip from a click. Instant is a click.
    final env = (1 - exp(-t * 520)) * exp(-t * 26);
    out.add((sin(phase) * 0.8 + sin(phase * 2) * 0.10) * env * 0.4);
  }
  return out;
}

/// A soft thud on landing. Short, low, and quieter than death.
List<double> _land() {
  const seconds = 0.12;
  final n = (sampleRate * seconds).round();
  final rng = Random(31);
  final out = <double>[];
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    phase += 2 * pi * (190 - 70 * (i / n)) / sampleRate;
    final env = exp(-t * 34);
    final grit = (rng.nextDouble() * 2 - 1) * exp(-t * 220) * 0.25;
    out.add((sin(phase) * 0.7 + grit) * env * 0.34);
  }
  return out;
}

/// A whoosh: noise swept through a one pole lowpass, with a rising body under
/// it. The signature mechanic gets the signature sound.
List<double> _whoosh() {
  const seconds = 0.26;
  final n = (sampleRate * seconds).round();
  final rng = Random(11);
  final out = <double>[];
  var lowpass = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final progress = i / n;
    final env = sin(pi * progress) * exp(-t * 3.2);
    final noise = rng.nextDouble() * 2 - 1;
    final cutoff = 0.05 + 0.5 * sin(pi * progress);
    lowpass += (noise - lowpass) * cutoff;
    final body = sin(2 * pi * (210 + 360 * progress) * t) * 0.2;
    out.add((lowpass * 0.9 + body) * env * 0.5);
  }
  return out;
}

/// A dull thud, not a scream: a low sine dropping in pitch, with a knock on
/// the front.
List<double> _death() {
  const seconds = 0.3;
  final n = (sampleRate * seconds).round();
  final rng = Random(23);
  final out = <double>[];
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final progress = i / n;
    phase += 2 * pi * (108 - 56 * progress) / sampleRate;
    final env = exp(-t * 11);
    final knock = (rng.nextDouble() * 2 - 1) * exp(-t * 150) * 0.3;
    out.add((sin(phase) * 0.85 + knock) * env * 0.66);
  }
  return out;
}

/// The door. Three bell notes climbing, staggered so they pile into a chord
/// rather than sounding one at a time.
///
/// It is a rise, not a fanfare. The reward for finishing a level is the next
/// level, and there are ten thousand of them: a sound that celebrates hard
/// is unbearable by the fiftieth. It sits on the C of the music bed's A minor,
/// so it lands in key over whatever the loop happens to be playing.
List<double> _win() {
  const seconds = 0.42;
  const notes = <double>[523.25, 659.25, 880.00]; // C5, E5, A5
  const stagger = 0.075;

  final n = (sampleRate * seconds).round();
  final out = List<double>.filled(n, 0);

  for (var note = 0; note < notes.length; note++) {
    final start = (sampleRate * stagger * note).round();
    final hz = notes[note];
    for (var i = start; i < n; i++) {
      final t = (i - start) / sampleRate;
      // Struck, not blown: immediate attack, then a bell's long fall.
      final env = exp(-t * 7.5) * (1 - exp(-t * 400));
      out[i] += (sin(2 * pi * hz * t) * 0.6 +
              sin(2 * pi * hz * 2 * t) * 0.12 +
              sin(2 * pi * hz * 3 * t) * 0.05) *
          env *
          0.30;
    }
  }
  return out;
}

/// A slow, dark bed for the background. Four bars of A minor at 120 BPM, so it
/// comes round every 8 seconds. It has no melody on purpose: it fills the
/// quiet stretches without pulling attention off the obstacles.
List<double> _music() {
  const bpm = 120.0;
  const beat = 60 / bpm;
  const beatsPerBar = 4;
  const bars = 4;
  const seconds = bars * beatsPerBar * beat;
  final n = (sampleRate * seconds).round();
  final rng = Random(101);

  // One root a bar. It never resolves, so it never asks to be listened to.
  const roots = <double>[55.00, 43.65, 65.41, 49.00];

  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final bar = (t / (beatsPerBar * beat)).floor() % bars;
    final root = roots[bar];

    // Bass: one pulse a beat, dropping away fast, so it reads as a heartbeat
    // rather than a drone.
    final intoBeat = t % beat;
    final bassEnv = exp(-intoBeat * 9);
    final bass = (sin(2 * pi * root * t) * 0.7 +
            sin(2 * pi * root * 2 * t) * 0.16) *
        bassEnv;

    // Pad: the root and its fifth two octaves up, quantised to whole cycles
    // of the loop so the seam is silent, breathing across the whole loop.
    final breath = 0.5 + 0.5 * sin(2 * pi * t / seconds);
    final pad = (sin(2 * pi * _loopLocked(root * 4, seconds) * t) * 0.5 +
            sin(2 * pi * _loopLocked(root * 6, seconds) * t) * 0.3) *
        (0.11 + 0.05 * breath);

    // Tick: a whisper of noise on the offbeat, for the pulse.
    final tick = intoBeat < beat / 2
        ? 0.0
        : (rng.nextDouble() * 2 - 1) * exp(-(intoBeat - beat / 2) * 150) * 0.05;

    out[i] = (bass * 0.40 + pad + tick) * 0.5;
  }
  return out;
}

/// Nudges [hz] to the nearest frequency that completes a whole number of
/// cycles in [seconds], so a looped tone never clicks at the seam.
double _loopLocked(double hz, double seconds) =>
    (hz * seconds).round() / seconds;

/// [loop] keeps the tail intact and instead crossfades the seam, so the file
/// can be played end to end forever without a gap or a click.
void _write(
  String path,
  List<double> samples, {
  bool loop = false,
  double peak = 0.92,
}) {
  // Before anything else, because every synth function above was written by
  // ear with a hand picked output multiplier and they do not agree with each
  // other. Normalising here is what stops the mix being decided by whichever
  // number happened to get typed into each generator.
  final gain = _normalise(samples, peak);

  if (loop) {
    _seamFade(samples);
  } else {
    _fadeOut(samples);
  }

  const headerBytes = 44;
  final dataBytes = samples.length * 2;
  final out = ByteData(headerBytes + dataBytes);

  _ascii(out, 0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  _ascii(out, 8, 'WAVE');
  _ascii(out, 12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // subchunk size
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  out.setUint16(32, 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample
  _ascii(out, 36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    out.setInt16(headerBytes + i * 2, (clamped * 32767).round(), Endian.little);
  }

  File(path).writeAsBytesSync(out.buffer.asUint8List());
  stdout.writeln('$path  ${samples.length} samples  '
      '${(samples.length / sampleRate * 1000).round()} ms  '
      '${headerBytes + dataBytes} bytes  '
      'x${gain.toStringAsFixed(2)}');
}

/// Scales [samples] so the loudest one lands exactly on [peak].
///
/// A phone speaker is small and the game is played in a room with other noise
/// in it, so a file that peaks at a third of full scale is inaudible however
/// high the playback volume is set — the volume is a multiplier, and a third
/// of not very much is still not very much. Every file leaves the same
/// headroom, and the balance between them is then set once, in [SoundPlayer],
/// where it can be read in one place.
double _normalise(List<double> samples, double peak) {
  var loudest = 0.0;
  for (final sample in samples) {
    final level = sample.abs();
    if (level > loudest) loudest = level;
  }
  if (loudest == 0) return 1;

  final gain = peak / loudest;
  for (var i = 0; i < samples.length; i++) {
    samples[i] *= gain;
  }
  return gain;
}

/// Crossfades the head of a loop into its own tail, so playing the file back
/// to back is seamless. Only the percussive envelopes need this; the sustained
/// tones are already locked to whole cycles of the loop.
void _seamFade(List<double> samples) {
  final fade = min(samples.length ~/ 2, (sampleRate * 0.03).round());
  for (var i = 0; i < fade; i++) {
    final blend = i / fade;
    final index = samples.length - fade + i;
    samples[index] = samples[index] * (1 - blend) + samples[i] * blend;
  }
}

/// Ramps the tail to silence so the file does not end on a step.
void _fadeOut(List<double> samples) {
  final fade = min(samples.length, (sampleRate * 0.004).round());
  for (var i = 0; i < fade; i++) {
    final index = samples.length - fade + i;
    samples[index] *= 1 - i / fade;
  }
}

void _ascii(ByteData out, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    out.setUint8(offset + i, value.codeUnitAt(i));
  }
}
