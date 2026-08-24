// Authoring tool. Draws the 32 achievement icons for the Play Console import
// and writes them to store/achievements, plus the leaderboard icon into
// store/leaderboards.
//
//   flutter test tool/make_achievement_icons.dart
//
// It runs under the test harness rather than `dart run` for the same reason
// tool/make_icon.dart does: it needs a real Canvas, which lives in dart:ui.
//
// The icons are drawn rather than painted by hand for the same reason the
// launcher icon, the sounds and the levels are: they are reproducible, they
// are edited by changing a number here, and they take their colours from the
// game's own palette, so thirty-two of them cannot drift apart from each
// other or from what the game looks like.
//
// There is no text on any of them, and that is a constraint rather than a
// style choice: the project bundles no font, so under the test harness every
// glyph would render as a solid Ahem block. Tier is carried by an arc around
// the rim instead — nine tiers of progression fill the ring nine-ninths of
// the way round — which reads at the size Play actually shows these.
//
// The filenames written here must match AchievementsIconsMappings.csv exactly.
// A test below asserts that against the real file rather than a copy of it.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/data/leaderboards.dart';
import 'package:pitchpole/ui/menu_palette.dart';
import 'package:pitchpole/ui/palette.dart';

/// Play wants 512 square. Drawn at exactly that, so nothing is resampled.
const double _size = 512;

const String _outDir = 'store/achievements';
const String _mappingCsv = '$_outDir/AchievementsIconsMappings.csv';

/// What is drawn in the middle of the disc.
enum Glyph { character, door, star, coin, heart, bolted, pips }

/// One icon: a coloured disc, a rim arc for the tier, and a glyph.
class _Icon {
  const _Icon(
    this.id,
    this.glyph,
    this.disc, {
    required this.tier,
    required this.tiers,
    this.pips = 0,
    this.crowned = false,
  });

  final String id;
  final Glyph glyph;
  final Color disc;

  /// Which step of its group this is, and how many steps the group has. The
  /// rim arc is [tier] / [tiers] of the way round, so the last one in a group
  /// closes the ring and the first barely starts it.
  final int tier;
  final int tiers;

  /// For [Glyph.pips]: how many dots to lay round the middle. Used by the two
  /// achievements that are about *how many different things* a player has
  /// beaten rather than how many times.
  final int pips;

  /// The end of a group gets a gold rim rather than a lighter shade of its
  /// own colour, so "you have finished this line" reads instantly.
  final bool crowned;

  String get file => '$id.png';
}

/// Green for getting through the pack, amber for stars, gold for coins, blue
/// for the skill ones and violet for the stubborn ones. Same five colours the
/// menus already use, so the achievement list looks like the game.
const Color _progress = MenuPalette.play;
const Color _mastery = Color(0xFFE9A81F);
const Color _coins = Color(0xFFD9A216);
const Color _skill = MenuPalette.levels;
const Color _grit = MenuPalette.purple;

const List<_Icon> _icons = [
  // Progression: nine steps from the first level to the last.
  _Icon('first_steps', Glyph.character, _progress, tier: 1, tiers: 9),
  _Icon('taught', Glyph.door, _progress, tier: 2, tiers: 9),
  _Icon('two_dozen', Glyph.door, _progress, tier: 3, tiers: 9),
  _Icon('century', Glyph.door, _progress, tier: 4, tiers: 9),
  _Icon('past_the_ramp', Glyph.bolted, _progress, tier: 5, tiers: 9),
  _Icon('thousand', Glyph.door, _progress, tier: 6, tiers: 9),
  _Icon('quarter', Glyph.door, _progress, tier: 7, tiers: 9),
  _Icon('halfway', Glyph.door, _progress, tier: 8, tiers: 9),
  _Icon('pitchpole', Glyph.door, _progress,
      tier: 9, tiers: 9, crowned: true),

  // Mastery: eight steps of finishing cleanly.
  _Icon('untouched', Glyph.heart, _mastery, tier: 1, tiers: 8),
  _Icon('flawless_teaching', Glyph.star, _mastery, tier: 2, tiers: 8),
  _Icon('ten_clean', Glyph.star, _mastery, tier: 3, tiers: 8),
  _Icon('hundred_clean', Glyph.star, _mastery, tier: 4, tiers: 8),
  _Icon('untouchable', Glyph.star, _mastery, tier: 5, tiers: 8),
  _Icon('star_hoard', Glyph.star, _mastery, tier: 6, tiers: 8),
  _Icon('constellation', Glyph.star, _mastery, tier: 7, tiers: 8),
  _Icon('every_star', Glyph.star, _mastery, tier: 8, tiers: 8, crowned: true),

  // Coins: five steps of sweeping.
  _Icon('pocket_change', Glyph.coin, _coins, tier: 1, tiers: 5),
  _Icon('sweep', Glyph.coin, _coins, tier: 2, tiers: 5),
  _Icon('sweeper', Glyph.coin, _coins, tier: 3, tiers: 5),
  _Icon('coin_baron', Glyph.coin, _coins, tier: 4, tiers: 5),
  _Icon('all_that_glitters', Glyph.coin, _coins,
      tier: 5, tiers: 5, crowned: true),

  // Skill: the six that are about how you played, not how much.
  _Icon('featherfoot', Glyph.character, _skill, tier: 1, tiers: 6),
  _Icon('held_ground', Glyph.character, _skill, tier: 2, tiers: 6),
  _Icon('full_tilt', Glyph.character, _skill, tier: 3, tiers: 6),
  _Icon('range', Glyph.pips, _skill, tier: 4, tiers: 6, pips: 6),
  _Icon('every_flavour', Glyph.pips, _skill,
      tier: 5, tiers: 6, pips: 12, crowned: true),
  _Icon('no_retreat', Glyph.heart, _skill, tier: 6, tiers: 6),

  // Persistence.
  _Icon('every_threat', Glyph.bolted, _grit, tier: 1, tiers: 4),
  _Icon('ten_in_a_row', Glyph.character, _grit, tier: 2, tiers: 4),
  _Icon('marathon', Glyph.character, _grit, tier: 3, tiers: 4),
  _Icon('stubborn', Glyph.heart, _grit, tier: 4, tiers: 4, crowned: true),
];

/// The one leaderboard, drawn the same way and in the same palette.
///
/// No tier here — a board is not a step on a ladder — so it is a full ring,
/// which reads as a complete badge rather than a part-filled one. Amber and a
/// star, so the row in the account sheet matches the star pills the rest of
/// the game already uses for the same number.
const List<_Icon> _boardIcons = [
  _Icon('stars_earned', Glyph.star, _mastery, tier: 1, tiers: 1),
];

const String _boardDir = 'store/leaderboards';

void main() {
  test('draws every leaderboard icon', () async {
    final dir = Directory(_boardDir)..createSync(recursive: true);

    for (final icon in _boardIcons) {
      await _write('${dir.path}/${icon.file}', (canvas) => _draw(canvas, icon));
    }

    for (final icon in _boardIcons) {
      final file = File('${dir.path}/${icon.file}');
      expect(file.existsSync(), isTrue, reason: 'missing ${icon.file}');
      expect(file.lengthSync(), greaterThan(0), reason: '${icon.file} is empty');
    }
  });

  test('every leaderboard the game submits to has an icon', () {
    // Play has no bulk import for leaderboards, so the board is created by
    // hand in the console and needs a 512 square icon at that moment. Missing
    // is found halfway through filling in a form.
    //
    // Read off [Lb] rather than a copy of it, so adding a board to the game
    // without drawing its icon fails here rather than in the console.
    final drawn = {for (final icon in _boardIcons) icon.id};
    for (final board in Lb.all) {
      expect(drawn, contains(board.key),
          reason: 'no icon for the ${board.name} board');
    }
    expect(drawn.length, Lb.all.length,
        reason: 'an icon is drawn for a board the game does not submit to');
  });

  test('draws every achievement icon', () async {
    final dir = Directory(_outDir)..createSync(recursive: true);

    for (final icon in _icons) {
      await _write('${dir.path}/${icon.file}', (canvas) => _draw(canvas, icon));
    }

    for (final icon in _icons) {
      final file = File('${dir.path}/${icon.file}');
      expect(file.existsSync(), isTrue, reason: 'missing ${icon.file}');
      expect(file.lengthSync(), greaterThan(0), reason: '${icon.file} is empty');
    }
  });

  test('every icon the mapping asks for is one this tool draws', () {
    // The CSV is what Play reads, so it is the authority. A filename in there
    // with no file beside it in the ZIP is an achievement with no icon, and
    // the import does not warn about that.
    //
    // Matched on the filename rather than the first column, because the first
    // column is the achievement's display name — Play joins the CSVs on the
    // name, not on the id this tool happens to use. There is no header row to
    // skip: the importer reads row one as data.
    final rows = File(_mappingCsv).readAsLinesSync()
      ..removeWhere((l) => l.trim().isEmpty);
    final wanted = {for (final row in rows) row.split(',')[1].trim()};

    expect(wanted.length, _icons.length,
        reason: 'the mapping and this tool disagree about how many there are');

    final drawn = {for (final icon in _icons) icon.file};
    for (final file in wanted) {
      expect(drawn, contains(file),
          reason: 'the mapping asks for $file, which this tool never draws');
    }
  });

  test('ids are unique and tiers fill their groups exactly', () {
    expect(_icons.map((i) => i.id).toSet().length, _icons.length);

    // Each group has to run 1..tiers with nothing missing, or the rim arc
    // stops meaning anything.
    final groups = <int, List<int>>{};
    for (final icon in _icons) {
      groups.putIfAbsent(icon.tiers, () => []).add(icon.tier);
    }
    groups.forEach((tiers, seen) {
      seen.sort();
      expect(seen, List.generate(tiers, (i) => i + 1),
          reason: 'a group of $tiers is missing a step or repeats one');
    });
  });
}

void _draw(Canvas canvas, _Icon icon) {
  const centre = Offset(_size / 2, _size / 2);
  const radius = _size * 0.42;

  // A soft drop under the disc, the same trick the launcher icon uses to lift
  // the character off its background.
  canvas.drawCircle(
    centre.translate(0, _size * 0.018),
    radius,
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _size * 0.03),
  );

  // The disc, lit from above so it reads as a token rather than a flat dot.
  canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..shader = Gradient.linear(
        Offset(centre.dx, centre.dy - radius),
        Offset(centre.dx, centre.dy + radius),
        [_lighten(icon.disc, 0.18), _darken(icon.disc, 0.16)],
      ),
  );

  _drawRim(canvas, centre, radius, icon);

  switch (icon.glyph) {
    case Glyph.character:
      _drawCharacter(canvas, centre, _size * 0.30);
    case Glyph.door:
      _drawDoor(canvas, centre, _size * 0.30);
    case Glyph.star:
      _drawStar(canvas, centre, _size * 0.20, Palette.star);
    case Glyph.coin:
      _drawCoin(canvas, centre, _size * 0.19);
    case Glyph.heart:
      _drawHeart(canvas, centre, _size * 0.20);
    case Glyph.bolted:
      _drawBolted(canvas, centre, _size * 0.28);
    case Glyph.pips:
      _drawPips(canvas, centre, _size * 0.24, icon.pips);
  }
}

/// The tier arc: a full track, then [tier]/[tiers] of it drawn over in white,
/// starting at the top and going clockwise like a clock hand.
void _drawRim(Canvas canvas, Offset centre, double radius, _Icon icon) {
  final inset = radius - _size * 0.035;
  final rect = Rect.fromCircle(center: centre, radius: inset);
  const start = -math.pi / 2;

  canvas.drawArc(
    rect,
    0,
    math.pi * 2,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _size * 0.045
      ..color = const Color(0x33000000),
  );

  canvas.drawArc(
    rect,
    start,
    math.pi * 2 * icon.tier / icon.tiers,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _size * 0.045
      ..color = icon.crowned ? Palette.star : _white(0.92),
  );
}

/// The player, simplified to what survives at this size: body, ears, eyes.
/// The ears are kept because in a game about being upside down they are the
/// thing that says which way up you are.
void _drawCharacter(Canvas canvas, Offset centre, double size) {
  final body = Paint()..color = Palette.player;
  final limb = Paint()..color = Palette.playerDark;
  final bodyHeight = size * 0.78;

  canvas.save();
  canvas.translate(centre.dx, centre.dy + size * 0.04);

  // Ears first, so the body covers the joins.
  for (final side in [-1.0, 1.0]) {
    final root = side * size * 0.24;
    canvas.drawPath(
      Path()
        ..moveTo(root - size * 0.10, -bodyHeight / 2 + size * 0.02)
        ..lineTo(root + size * 0.10, -bodyHeight / 2 + size * 0.02)
        ..lineTo(root - side * size * 0.16, -bodyHeight / 2 - size * 0.22)
        ..close(),
      limb,
    );
  }

  // Legs.
  for (final side in [-1.0, 1.0]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          side * size * 0.20 - size * 0.09,
          bodyHeight / 2 - size * 0.04,
          size * 0.18,
          size * 0.20,
        ),
        Radius.circular(size * 0.09),
      ),
      limb,
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-size / 2, -bodyHeight / 2, size, bodyHeight),
      Radius.circular(size * 0.34),
    ),
    body,
  );

  for (final side in [-1.0, 1.0]) {
    final eye = Offset(side * size * 0.17, -size * 0.06);
    canvas.drawCircle(eye, size * 0.13, Paint()..color = Palette.eyeWhite);
    canvas.drawCircle(
      eye.translate(side * size * 0.02, size * 0.01),
      size * 0.065,
      Paint()..color = Palette.eyePupil,
    );
  }
  canvas.restore();
}

/// The door at the end of a level, which is what every progression
/// achievement is really counting.
void _drawDoor(Canvas canvas, Offset centre, double size) {
  final w = size * 0.72;
  final h = size * 0.96;
  final rect = Rect.fromCenter(center: centre, width: w, height: h);

  canvas.drawRRect(
    RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(w * 0.46),
      topRight: Radius.circular(w * 0.46),
    ),
    Paint()..color = Palette.door,
  );
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      rect.deflate(w * 0.11),
      topLeft: Radius.circular(w * 0.36),
      topRight: Radius.circular(w * 0.36),
    ),
    Paint()..color = _darken(Palette.door, 0.28),
  );
  canvas.drawCircle(
    Offset(centre.dx + w * 0.22, centre.dy + h * 0.06),
    w * 0.07,
    Paint()..color = Palette.star,
  );
}

void _drawStar(Canvas canvas, Offset centre, double radius, Color color) {
  canvas.drawPath(
    _starPath(centre, radius, radius * 0.46),
    Paint()..color = color,
  );
  canvas.drawPath(
    _starPath(centre, radius, radius * 0.46),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14
      ..strokeJoin = StrokeJoin.round
      ..color = _darken(color, 0.30),
  );
}

Path _starPath(Offset centre, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(centre.dx + math.cos(a) * r, centre.dy + math.sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

void _drawCoin(Canvas canvas, Offset centre, double radius) {
  canvas.drawCircle(centre, radius, Paint()..color = Palette.coinEdge);
  canvas.drawCircle(centre, radius * 0.86, Paint()..color = Palette.coin);
  canvas.drawCircle(
    centre.translate(-radius * 0.22, -radius * 0.22),
    radius * 0.30,
    Paint()..color = Palette.coinCore,
  );
}

void _drawHeart(Canvas canvas, Offset centre, double size) {
  final path = Path()
    ..moveTo(centre.dx, centre.dy + size * 0.86)
    ..cubicTo(
      centre.dx - size * 1.36, centre.dy - size * 0.10,
      centre.dx - size * 0.52, centre.dy - size * 1.14,
      centre.dx, centre.dy - size * 0.34,
    )
    ..cubicTo(
      centre.dx + size * 0.52, centre.dy - size * 1.14,
      centre.dx + size * 1.36, centre.dy - size * 0.10,
      centre.dx, centre.dy + size * 0.86,
    )
    ..close();

  canvas.drawPath(path, Paint()..color = const Color(0xFFEE4B6A));
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.14
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFB82946),
  );
}

/// The bolted enemy: the first thing in the game that forces a flip, and the
/// one obstacle a player will recognise from a thumbnail.
void _drawBolted(Canvas canvas, Offset centre, double size) {
  final w = size * 0.86;
  final h = size * 0.80;
  final rect = Rect.fromCenter(center: centre, width: w, height: h);

  // Spikes along the top.
  for (var i = -1; i <= 1; i++) {
    final x = centre.dx + i * w * 0.30;
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 0.11, rect.top + h * 0.02)
        ..lineTo(x + w * 0.11, rect.top + h * 0.02)
        ..lineTo(x, rect.top - h * 0.24)
        ..close(),
      Paint()..color = Palette.boltedDark,
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(w * 0.20)),
    Paint()..color = Palette.bolted,
  );

  for (final side in [-1.0, 1.0]) {
    final eye = Offset(centre.dx + side * w * 0.20, centre.dy - h * 0.04);
    canvas.drawCircle(eye, w * 0.13, Paint()..color = Palette.eyeWhite);
    canvas.drawCircle(eye, w * 0.065, Paint()..color = Palette.eyePupil);
  }
}

/// A ring of dots, one per thing there is to beat. Six for the six mixes
/// `range` asks for, twelve for all of them.
void _drawPips(Canvas canvas, Offset centre, double radius, int count) {
  final dot = radius * (count > 8 ? 0.20 : 0.26);
  for (var i = 0; i < count; i++) {
    final a = -math.pi / 2 + i * math.pi * 2 / count;
    canvas.drawCircle(
      Offset(centre.dx + math.cos(a) * radius, centre.dy + math.sin(a) * radius),
      dot,
      Paint()..color = _white(0.95),
    );
  }
  canvas.drawCircle(centre, radius * 0.34, Paint()..color = Palette.star);
}

/// White at a given opacity, since dart:ui has no Colors class.
Color _white(double opacity) =>
    Color.fromRGBO(255, 255, 255, opacity);

Color _lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;
Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;

Future<void> _write(String path, void Function(Canvas) paint) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas);

  final image = await recorder
      .endRecording()
      .toImage(_size.round(), _size.round());
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}
