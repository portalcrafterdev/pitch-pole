// Authoring tool. Draws the launcher icon and writes it to assets/icon.
//
//   flutter test tool/make_icon.dart
//   dart run flutter_launcher_icons        # then stamps it onto both platforms
//
// It runs under the test harness rather than `dart run` because it needs a
// real Canvas, which lives in dart:ui and is not available to plain Dart.
//
// The icon is drawn rather than painted by hand for the same reason the sounds
// and the levels are generated: it is reproducible, it is edited by changing a
// number here, and it takes its colours from the game's own palette, so it
// cannot drift away from what the game looks like.
//
// Three files come out:
//   icon.png             the whole thing, for iOS and for Android before 26
//   icon_foreground.png  just the character, for the Android adaptive layer
//   icon_background.png  just the forest, likewise
//
// The two adaptive layers are drawn on the same 1024 grid as the composed
// icon but with the character shrunk, because Android crops an adaptive icon
// hard: only the middle two thirds is guaranteed to survive the mask.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/ui/palette.dart';

/// The grid everything is laid out on. Exported at this size, which is what
/// the App Store wants and more than Android ever needs.
const double _size = 1024;

/// Where the two surfaces sit and how big the character is between them.
///
/// There are two of these because Android composites the adaptive layers and
/// then masks the result down to roughly the middle 66%, in a shape the
/// launcher chooses. Everything therefore has to be pulled towards the middle
/// for that version, and the two layers have to agree about where the floor
/// is or the character stands in mid air.
class _Layout {
  const _Layout({
    required this.ceilingBottom,
    required this.floorTop,
    required this.character,
  });

  /// The underside of the canopy and the top of the earth: the two lines the
  /// character can be standing on.
  final double ceilingBottom;
  final double floorTop;

  /// The character's box, which is square.
  final double character;

  /// Standing on the floor, exactly as it does in game: the box rests with
  /// its bottom edge on the surface line.
  Offset get standing => Offset(_size / 2, floorTop - character / 2);
}

/// The proportions the game itself uses: a 16 unit block, a 120 unit band and
/// a 220 unit canvas, so the ceiling and the floor each take a fraction under
/// a quarter of the height.
const _composed = _Layout(
  ceilingBottom: _size * 0.227,
  floorTop: _size * 0.773,
  character: 440,
);

/// Squeezed towards the middle so a circular mask cuts through the canopy and
/// the earth rather than through the character's ears and feet.
const _adaptiveBackground = _Layout(
  ceilingBottom: _size * 0.32,
  floorTop: _size * 0.68,
  character: 290,
);

/// How far flutter_launcher_icons insets the adaptive foreground layer, per
/// side, in the `mipmap-anydpi-v26` xml it writes.
///
/// It insets the foreground and not the background, so the two layers do not
/// share a coordinate system: a character drawn at the same place in both
/// ends up hanging above the floor the background painted. The foreground is
/// therefore drawn oversized and low, by exactly enough that the inset puts
/// it back. If that xml ever stops saying 16%, the test below fails.
const double _foregroundInset = 0.16;
const double _insetScale = 1 - 2 * _foregroundInset;

/// Undoes the inset for one vertical coordinate, which scales about the
/// centre of the icon.
double _preInset(double y) => _size / 2 + (y - _size / 2) / _insetScale;

/// The character's own layer, derived from the background's so that its feet
/// land on that floor once Android has shrunk it.
final _adaptiveForeground = _Layout(
  ceilingBottom: _preInset(_adaptiveBackground.ceilingBottom),
  floorTop: _preInset(_adaptiveBackground.floorTop),
  character: _adaptiveBackground.character / _insetScale,
);

void main() {
  test('draws the launcher icon', () async {
    final dir = Directory('assets/icon')..createSync(recursive: true);

    await _write('${dir.path}/icon.png', (canvas) {
      _drawForest(canvas, _composed);
      _drawCharacter(canvas, _composed);
    });

    await _write('${dir.path}/icon_background.png', (canvas) {
      _drawForest(canvas, _adaptiveBackground);
    });

    await _write('${dir.path}/icon_foreground.png', (canvas) {
      _drawCharacter(canvas, _adaptiveForeground);
    });

    for (final name in ['icon', 'icon_background', 'icon_foreground']) {
      expect(File('${dir.path}/$name.png').lengthSync(), greaterThan(0));
    }
  });

  test('the character stands on the floor and clears the ceiling', () {
    for (final layout in [_composed, _adaptiveForeground]) {
      final sole = layout.standing.dy + layout.character / 2;
      expect(sole, closeTo(layout.floorTop, 0.01),
          reason: 'it should rest on the surface, not float above it');

      // The ears reach a fifth of the box above its top edge.
      final earTip = layout.standing.dy - layout.character * 0.7;
      expect(earTip, greaterThan(layout.ceilingBottom),
          reason: 'the ears should not push up into the canopy');
    }
  });

  test('the adaptive layers line up once Android has inset the foreground',
      () {
    // The whole reason the foreground is drawn oversized. Read the inset back
    // out of the file the generator wrote rather than trusting the constant,
    // because that file is the thing the phone actually obeys.
    final xml = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    if (xml.existsSync()) {
      expect(xml.readAsStringSync(),
          contains('android:inset="${(_foregroundInset * 100).round()}%"'),
          reason: 'the generator changed its inset, so the character no '
              'longer lands on the floor; update _foregroundInset');
    }

    final soleOnScreen = _size / 2 +
        (_adaptiveForeground.standing.dy +
                _adaptiveForeground.character / 2 -
                _size / 2) *
            _insetScale;
    expect(soleOnScreen, closeTo(_adaptiveBackground.floorTop, 0.01),
        reason: 'the character must stand on the floor the background drew');

    // And all of it has to survive the mask, which keeps the middle 66%.
    final halfWidth = _adaptiveForeground.character / 2 * _insetScale;
    expect(_size / 2 - halfWidth, greaterThan(_size * 0.17),
        reason: 'a circular mask would cut the character off');
  });
}

/// The ground the character stands on: the shade under the canopy, with the
/// two surfaces the whole game is played between.
///
/// Deliberately not a screenshot. The band, the canopy and the earth are here
/// because they are what the game is about, but they are reduced to three
/// stripes: at 48 pixels, which is the size that actually matters, anything
/// more is mud.
void _drawForest(Canvas canvas, _Layout layout) {
  // Darker than the band in game. There the band shares the screen with a
  // bright sky that lifts it; an icon has nothing around it but a wallpaper,
  // and the blue of the character needs somewhere dark to sit against.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()
      ..shader = Gradient.linear(
        const Offset(0, 0),
        const Offset(0, _size),
        [const Color(0xFF2F5F4A), const Color(0xFF17352A)],
      ),
  );

  // The canopy is solid all the way to the top edge, and the earth solid to
  // the bottom. Drawn as thin bars instead they read as two stripes floating
  // in a green field, which is not a floor and a ceiling.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _size, layout.ceilingBottom),
    Paint()..color = Palette.canopy,
  );
  canvas.drawRect(
    Rect.fromLTWH(
      0,
      layout.ceilingBottom - _size * 0.010,
      _size,
      _size * 0.010,
    ),
    Paint()..color = Palette.mossDark,
  );

  canvas.drawRect(
    Rect.fromLTWH(0, layout.floorTop, _size, _size - layout.floorTop),
    Paint()..color = Palette.earth,
  );
  // Deeper soil further down, so the ground is not one flat slab. The same
  // 16 unit block the game uses, as a fraction of its 220 unit canvas.
  canvas.drawRect(
    Rect.fromLTWH(
      0,
      layout.floorTop + _size * 0.073,
      _size,
      _size - layout.floorTop - _size * 0.073,
    ),
    Paint()..color = Palette.earthDark,
  );
  // The lit moss cap: the line the character actually rests on.
  canvas.drawRect(
    Rect.fromLTWH(0, layout.floorTop, _size, _size * 0.016),
    Paint()..color = Palette.moss,
  );
}

/// The character, at [size] square, centred on [centre].
///
/// The proportions are lifted from `PlayerComponent` so the icon and the
/// sprite are the same creature: a body that is three quarters of the box
/// with the legs owning the rest, ears swept back, and eyes big enough to
/// carry the whole face. What is dropped is everything that only exists in
/// motion — the run cycle, the blink, the pupils leaning into the fall — so
/// this is that character standing still.
void _drawCharacter(Canvas canvas, _Layout layout) {
  final body = Paint()..color = Palette.player;
  final limb = Paint()..color = Palette.playerDark;
  final white = Paint()..color = Palette.eyeWhite;
  final pupil = Paint()..color = Palette.eyePupil;

  final size = layout.character;
  final width = size;
  final height = size;
  final bodyHeight = height * 0.76;

  canvas.save();
  canvas.translate(layout.standing.dx, layout.standing.dy);

  // A soft drop, so the character lifts off the background instead of lying
  // flat on it. The only thing here that the sprite does not have.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -width / 2,
        -height / 2 + height * 0.04,
        width,
        bodyHeight,
      ),
      Radius.circular(width * 0.34),
    ),
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.05),
  );

  // Behind the body, so the body covers every joint.
  _drawEars(canvas, width, height, limb);
  _drawLegs(canvas, width, height, bodyHeight, limb);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-width / 2, -height / 2, width, bodyHeight),
      Radius.circular(width * 0.34),
    ),
    body,
  );

  _drawFace(canvas, width, height, bodyHeight, white, pupil);
  canvas.restore();
}

/// Two ears, swept back. They are what says which way up the character is,
/// which in a game about being upside down is the thing worth keeping.
void _drawEars(Canvas canvas, double width, double height, Paint limb) {
  final top = -height / 2;
  for (final side in [-1.0, 1.0]) {
    final root = side * width * 0.24;
    canvas.drawPath(
      Path()
        ..moveTo(root - width * 0.10, top + height * 0.02)
        ..lineTo(root + width * 0.10, top + height * 0.02)
        ..lineTo(root - width * 0.16, top - height * 0.20)
        ..close(),
      limb,
    );
  }
}

/// Two legs, both planted. In game they cycle through a stride; here they are
/// symmetrical, because a raised trailing foot at 48 pixels is not a stride,
/// it is a character standing lopsided on one leg.
void _drawLegs(
  Canvas canvas,
  double width,
  double height,
  double bodyHeight,
  Paint limb,
) {
  final hip = -height / 2 + bodyHeight - height * 0.05;
  final length = height / 2 - hip;
  final thickness = width * 0.17;

  for (final side in [-1.0, 1.0]) {
    final x = width * 0.19 * side;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - thickness / 2, hip, thickness, length),
        Radius.circular(thickness / 2),
      ),
      limb,
    );
    canvas.drawCircle(Offset(x, hip + length), thickness * 0.58, limb);
  }
}

void _drawFace(
  Canvas canvas,
  double width,
  double height,
  double bodyHeight,
  Paint white,
  Paint pupil,
) {
  final bodyCentre = -height / 2 + bodyHeight / 2;
  final eyeRadius = width * 0.21;
  final eyeY = bodyCentre - bodyHeight * 0.04;
  final eyeX = width * 0.21;

  for (final side in [-1.0, 1.0]) {
    final eye = Offset(side * eyeX, eyeY);
    canvas.drawCircle(eye, eyeRadius, white);
    canvas.drawCircle(
      eye.translate(eyeRadius * 0.28, 0),
      eyeRadius * 0.46,
      pupil,
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(width * 0.04, bodyCentre + bodyHeight * 0.30),
        width: width * 0.24,
        height: width * 0.07,
      ),
      Radius.circular(width * 0.05),
    ),
    pupil,
  );
}

Future<void> _write(String path, void Function(Canvas) draw) async {
  final recorder = PictureRecorder();
  draw(Canvas(recorder, const Rect.fromLTWH(0, 0, _size, _size)));

  final picture = recorder.endRecording();
  final image = await picture.toImage(_size.round(), _size.round());
  final data = await image.toByteData(format: ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  stdout.writeln('$path  ${_size.round()}x${_size.round()}  '
      '${data.lengthInBytes} bytes');
}
