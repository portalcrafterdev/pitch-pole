// Authoring tool. Draws the Play Store artwork and writes it to store/.
//
//   flutter test tool/make_store_art.dart
//
// It runs under the test harness rather than `dart run` for the same reason
// tool/make_icon.dart does: it needs a real Canvas, which lives in dart:ui and
// is not available to plain Dart.
//
// The feature graphic is painted by the game's own scene functions rather than
// mocked up beside them. A store graphic drawn by hand is a promise about what
// the app looks like, and the usual way that promise goes stale is that the app
// changes and the artwork does not. This one cannot: it is the menu, at a
// different size, and if the menu changes this changes with it.
//
// Two files come out:
//   store/icon-512.png        the store listing icon, 512 square
//   store/feature-graphic.png the 1024 by 500 banner at the top of the listing
//
// Screenshots are not generated here. They are captured off a real device,
// because a screenshot is supposed to be evidence.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
// Prefixed: dart:ui and painting both define TextStyle and Gradient, and the
// unprefixed pair is ambiguous.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/ui/home_scene/sky_art.dart';
import 'package:pitchpole/ui/menu_palette.dart';

/// Play's sizes, both fixed by the console rather than chosen here.
const int _iconSize = 512;
const Size _feature = Size(1024, 500);

/// The moment of the ambient loop the banner is frozen at.
///
/// Not zero. At zero every cloud is at the position it was authored at, which
/// bunches three of them into the left half; a few seconds in they have spread
/// out. Any fixed value is reproducible, which is the only property that
/// matters here.
const double _t = 6.5;

/// How much bigger the scenery is drawn than it would be on a phone.
///
/// The banner is 1024 by 500, which is much wider for its height than any
/// phone, so scenery laid out for a phone comes out small and thin in it.
const double _sceneZoom = 1.6;

/// Roboto, out of the Flutter SDK's own cache.
///
/// The test harness draws every glyph as a box unless a real font is loaded,
/// which would be a strange thing to discover on the Play listing. Roboto is
/// Apache 2.0, ships with Flutter, and is what the game already renders in on
/// Android, so the banner is set in the same face as the app it advertises.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  expect(root, isNotNull,
      reason: 'FLUTTER_ROOT is unset, so run this through `flutter test`');

  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  expect(dir.existsSync(), isTrue,
      reason: 'no material_fonts in the Flutter cache at ${dir.path}');

  for (final font in const {
    'PitchpoleDisplay': 'Roboto-Black.ttf',
    'PitchpoleBody': 'Roboto-Medium.ttf',
  }.entries) {
    final file = File('${dir.path}/${font.value}');
    expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

    final bytes = file.readAsBytesSync();
    await (FontLoader(font.key)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
}

void main() {
  setUpAll(_loadFonts);

  test('draws the store icon', () async {
    Directory('store').createSync(recursive: true);

    // Resampled from the launcher icon rather than drawn again, so the icon on
    // the listing is provably the icon on the home screen. Two generators
    // drawing "the same" icon is two icons.
    final source = File('assets/icon/icon.png');
    expect(source.existsSync(), isTrue,
        reason: 'run tool/make_icon.dart first');

    final codec = await ui.instantiateImageCodec(
      source.readAsBytesSync(),
      targetWidth: _iconSize,
      targetHeight: _iconSize,
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    File('store/icon-512.png').writeAsBytesSync(png!.buffer.asUint8List());
    stdout.writeln('store/icon-512.png  $_iconSize x $_iconSize  '
        '${png.lengthInBytes} bytes');
  });

  test('draws the feature graphic', () async {
    Directory('store').createSync(recursive: true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & _feature);

    // The menu, at banner proportions: sky, sun, clouds, birds, hills, coins,
    // the mascot on the grass and the sparkles over the top.
    //
    // Drawn into a smaller space and scaled up. Every part of the scene is
    // placed as a fraction of the size it is handed, so a smaller size with a
    // matching scale still fills the banner exactly while making everything in
    // it bigger. At 1:1 a phone's worth of scenery stretched across a graphic
    // twice as wide leaves the mascot a thumbnail in a lot of empty sky.
    canvas.save();
    canvas.scale(_sceneZoom);
    paintScene(canvas, _feature / _sceneZoom, _t);
    canvas.restore();

    _drawSign(canvas, _feature);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(_feature.width.round(), _feature.height.round());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    File('store/feature-graphic.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    stdout.writeln('store/feature-graphic.png  '
        '${_feature.width.round()} x ${_feature.height.round()}  '
        '${png.lengthInBytes} bytes');
  });

  test('the artwork is the size Play asks for', () async {
    // Play rejects the upload rather than resizing, and it is a long way round
    // to find that out in a browser.
    expect(_iconSize, 512);
    expect(_feature, const Size(1024, 500));

    for (final name in ['icon-512.png', 'feature-graphic.png']) {
      final file = File('store/$name');
      expect(file.existsSync(), isTrue, reason: '$name was not written');
      // Play's ceiling for both is 1 MB.
      expect(file.lengthSync(), lessThan(1024 * 1024),
          reason: '$name is over Play\'s 1 MB limit');
    }
  });
}

/// The title, on the same painted sign the home screen uses.
///
/// Kept well inside the edges on purpose: Play crops this graphic to different
/// shapes depending on where it appears, and only the middle is safe.
void _drawSign(Canvas canvas, Size size) {
  // Measured before it is styled, because the rainbow has to be stretched
  // across the glyphs where they actually land. A shader is positioned in the
  // canvas, not in the text, so one built over a guessed rectangle paints the
  // wrong slice of the gradient: the first attempt ran green to purple with
  // the pink, orange and gold entirely off the left of the word.
  const titleStyle = (family: 'PitchpoleDisplay', size: 68.0, spacing: 10.0);
  final measured = _painter(
    'PITCHPOLE',
    fontFamily: titleStyle.family,
    fontSize: titleStyle.size,
    letterSpacing: titleStyle.spacing,
    color: const Color(0xFF000000),
  );

  final tagline = _painter(
    'Run, flip and jump to the door!',
    fontFamily: 'PitchpoleBody',
    fontSize: 26,
    letterSpacing: 0.4,
    color: MenuPalette.inkSoft,
  );

  const padX = 46.0;
  const padY = 26.0;
  const gap = 10.0;

  final width = math.max(measured.width, tagline.width) + padX * 2;
  final height = measured.height + gap + tagline.height + padY * 2;
  final rect = Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.37),
    width: width,
    height: height,
  );
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(34));

  // The sign's own drop edge, hard rather than blurred, exactly as the app
  // draws it.
  canvas.drawRRect(
    rrect.shift(const Offset(0, 7)),
    Paint()..color = MenuPalette.goldDark.withValues(alpha: 0.55),
  );
  canvas.drawRRect(
    rrect,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.94),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = MenuPalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5,
  );

  // Now that the word's position is known, the rainbow can be laid across
  // exactly the box it occupies.
  final titleAt =
      Offset(rect.center.dx - measured.width / 2, rect.top + padY);
  _painter(
    'PITCHPOLE',
    fontFamily: titleStyle.family,
    fontSize: titleStyle.size,
    letterSpacing: titleStyle.spacing,
    shader: const LinearGradient(colors: MenuPalette.rainbow).createShader(
      Rect.fromLTWH(titleAt.dx, titleAt.dy, measured.width, measured.height),
    ),
  ).paint(canvas, titleAt);

  tagline.paint(
    canvas,
    Offset(
      rect.center.dx - tagline.width / 2,
      rect.top + padY + measured.height + gap,
    ),
  );
}

TextPainter _painter(
  String text, {
  required String fontFamily,
  required double fontSize,
  double letterSpacing = 0,
  Color? color,
  Shader? shader,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        color: color,
        foreground: shader == null ? null : (Paint()..shader = shader),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}
