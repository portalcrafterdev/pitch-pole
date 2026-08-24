import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/scene_theme.dart';
import 'package:pitchpole/ui/palette.dart';

/// The cast, and the two things that help. Every one of these has to stay
/// findable against every background the game can put behind it.
const _cast = <String, Color>{
  'player': Palette.player,
  'bolted': Palette.bolted,
  'hopper': Palette.hopper,
  'blade': Palette.blade,
  'stone': Palette.stone,
  'fire': Palette.fireMid,
  'bat': Palette.bat,
  'spider': Palette.spider,
  'door': Palette.door,
  'coin': Palette.coin,
};

double _saturation(Color c) => HSLColor.fromColor(c).saturation;
double _lightness(Color c) => HSLColor.fromColor(c).lightness;

/// Straight line distance in RGB. Crude next to a proper colour difference,
/// but the thing being caught here is "these two are nearly the same paint",
/// and for that it is enough.
double _distance(Color a, Color b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return (dr * dr + dg * dg + db * db) / 3;
}

void main() {
  test('every level gets a theme, and always the same one', () {
    for (final id in [1, 7, 10, 11, 250, 999, kTotalLevels]) {
      expect(SceneTheme.forLevel(id), same(SceneTheme.forLevel(id)));
    }

    // The first block is the forest the game has always opened in.
    expect(SceneTheme.forLevel(1), same(SceneTheme.forest));
    expect(SceneTheme.forLevel(SceneTheme.levelsPerTheme), same(SceneTheme.forest));
    expect(
      SceneTheme.forLevel(SceneTheme.levelsPerTheme + 1),
      isNot(same(SceneTheme.forest)),
      reason: 'the place has to change at some point, or there is one theme',
    );
  });

  test('the whole pack is covered without falling off the end', () {
    for (var id = 1; id <= kTotalLevels; id++) {
      expect(SceneTheme.all, contains(SceneTheme.forLevel(id)));
    }
  });

  test('every theme is actually used somewhere in the pack', () {
    final seen = {
      for (var id = 1; id <= kTotalLevels; id++) SceneTheme.forLevel(id),
    };
    expect(seen.length, SceneTheme.all.length,
        reason: 'a theme nobody ever sees is dead code with a colour scheme');
  });

  group('no scenery competes with the cast', () {
    // This is the game's one hard rule, and the reason the themes are
    // variations in temperature rather than a free choice of colour. A
    // background that drifts towards a killer's own shade does not look
    // slightly worse, it makes that killer invisible at 280 units a second.
    for (final theme in SceneTheme.all) {
      test('${theme.name} stays out of the cast\'s way', () {
        for (final colour in theme.inBand) {
          expect(_saturation(colour), lessThanOrEqualTo(0.5),
              reason: '${theme.name} has a scenery colour more saturated than '
                  'the rule allows; the world is meant to be muted and the '
                  'cast is not');

          for (final entry in _cast.entries) {
            expect(_distance(colour, entry.value), greaterThan(0.02),
                reason: '${theme.name} has scenery within touching distance '
                    'of the ${entry.key}');
          }
        }
      });

      test('${theme.name} keeps the band a mid tone', () {
        // Pale loses the blade, which is near white steel. Too dark loses
        // everything that is drawn dark, and makes the sky look like a hole.
        for (final band in [theme.bandHigh, theme.bandLow]) {
          expect(_lightness(band), inInclusiveRange(0.15, 0.6),
              reason: '${theme.name} band is too light or too dark to read '
                  'the cast against');
        }
      });
    }
  });
}
