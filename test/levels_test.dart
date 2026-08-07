import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';
import 'package:pitchpole/game/logic/physics.dart';
import 'package:pitchpole/game/logic/run_state.dart';

List<LevelModel> loadLevels() {
  final raw = jsonDecode(File('assets/levels/levels.json').readAsStringSync());
  return (raw as List<dynamic>)
      .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  final levels = loadLevels();

  test('the level pack is not empty', () {
    expect(levels, isNotEmpty);
  });

  test('level ids are unique and consecutive from 1', () {
    expect(levels.map((l) => l.id).toList(),
        List.generate(levels.length, (i) => i + 1));
  });

  group('every level', () {
    for (final level in levels) {
      test('level ${level.id} is valid and completable', () {
        final result = validateLevel(level);
        expect(result.ok, isTrue, reason: result.toString());

        final end = runPlan(level, result.plan!);
        expect(end.status, RunStatus.won);
        expect(end.lives, kStartingLives,
            reason: 'the solver plan should not need to die');
      });

      test('level ${level.id} is 30 seconds of running', () {
        expect(level.seconds, closeTo(kLevelSeconds, 0.001));
      });

      test('level ${level.id} keeps its clearances', () {
        for (final enemy in level.bolted) {
          expect(enemy.x, greaterThanOrEqualTo(kBoltedClearance));
          expect(enemy.x, lessThanOrEqualTo(level.length - kBoltedClearance));
        }
      });

      test('level ${level.id} has room to flip between opposite enemies', () {
        for (var i = 0; i < level.bolted.length; i++) {
          for (var j = i + 1; j < level.bolted.length; j++) {
            final a = level.bolted[i];
            final b = level.bolted[j];
            if (a.surface == b.surface) continue;
            expect((a.x - b.x).abs(), greaterThanOrEqualTo(kOppositeBoltedGap),
                reason: 'bolted at ${a.x} and ${b.x} are impassable');
          }
        }
      });
    }
  });

  test('checkpoints land every 2000 units', () {
    for (final level in levels) {
      expect(level.checkpoints, isNotEmpty);
      for (final checkpoint in level.checkpoints) {
        expect(checkpoint % 2000, 0);
        expect(checkpoint, greaterThan(0));
        expect(checkpoint, lessThan(level.length));
      }
    }
  });

  test('a hop always fits inside its period', () {
    for (final level in levels) {
      expect(level.hopPeriod, greaterThan(kHopAirTime),
          reason: 'level ${level.id} would launch before it landed');
    }
  });

  test('every level has all five kinds of obstacle', () {
    for (final level in levels) {
      expect(level.bolted, isNotEmpty, reason: 'level ${level.id}: no bolted');
      expect(level.hoppers, isNotEmpty, reason: 'level ${level.id}: no hoppers');
      expect(level.blades, isNotEmpty, reason: 'level ${level.id}: no blades');
      expect(level.stones, isNotEmpty, reason: 'level ${level.id}: no stones');
      expect(level.fires, isNotEmpty, reason: 'level ${level.id}: no fires');
    }
  });

  test('every obstacle count only ever grows', () {
    final counts = <String, int Function(LevelModel)>{
      'bolted': (l) => l.bolted.length,
      'hoppers': (l) => l.hoppers.length,
      'blades': (l) => l.blades.length,
      'stones': (l) => l.stones.length,
      'fires': (l) => l.fires.length,
      'total': (l) => l.obstacleCount,
    };

    for (final entry in counts.entries) {
      var previous = 0;
      for (final level in levels) {
        final count = entry.value(level);
        expect(count, greaterThanOrEqualTo(previous),
            reason: 'level ${level.id} has fewer ${entry.key} than the one '
                'before it');
        previous = count;
      }
      expect(entry.value(levels.last), greaterThan(entry.value(levels.first)),
          reason: '${entry.key} never grows across the pack');
    }
  });

  test('level 1 introduces every type alone, one at a time', () {
    final first = levels.first;
    for (final kind in [
      first.bolted,
      first.hoppers,
      first.blades,
      first.stones,
      first.fires,
    ]) {
      expect(kind.length, 2, reason: 'level 1 shows each type twice, no more');
    }

    final introductions = <double>[
      first.bolted.first.x,
      first.hoppers.first.x,
      first.blades.first.x,
      first.stones.first.x,
      first.fires.first.x,
    ];

    expect(introductions, orderedEquals(first.obstacleXs.take(5)),
        reason: 'each type is met for the first time before anything repeats');

    // The camera shows this far ahead of the character, so a wider gap than
    // this means only one obstacle is ever on screen during the introductions.
    const visibleAhead = kCanvasWidth - kPlayerScreenX;
    for (var i = 1; i < introductions.length; i++) {
      expect(introductions[i] - introductions[i - 1], greaterThan(visibleAhead),
          reason: 'two types would share the screen');
    }
  });

  test('no level leaves the player with nothing to do', () {
    for (final level in levels) {
      expect(pacingProblems(level), isEmpty,
          reason: 'level ${level.id} has dead track');
    }
  });

  test('moving obstacles are readable and never sprint', () {
    for (final level in levels) {
      for (final blade in level.blades) {
        expect(blade.period, greaterThanOrEqualTo(kMinBladePeriod),
            reason: 'level ${level.id} has a blade too fast to read');
        expect(blade.x, greaterThan(kBladeClearance));
        expect(blade.x, lessThan(level.length - kBladeClearance));
      }
      for (final stone in level.stones) {
        expect(stone.period, greaterThan(kStoneCycleTime),
            reason: 'level ${level.id} has a stone that slams before it is '
                'back up');
      }
      for (final fire in level.fires) {
        expect(fire.period, greaterThan(kFireCycleTime + kMinFireDarkTime),
            reason: 'level ${level.id} has a fire that is lit so often it is '
                'really a bolted enemy');
        expect(fire.x, greaterThan(kFireClearance));
        expect(fire.x, lessThan(level.length - kFireClearance));
      }
    }
  });

  test('a fire is taller than a jump and shorter than the band', () {
    // Both halves matter. Higher than the jump peak means the only answer is
    // the other surface; well under the band means the other surface is
    // actually clear.
    expect(kFireReach, greaterThan(kJumpPeak));
    expect(kFireReach + kPlayerSize, lessThan(kBandHeight));
  });

  test('no two fires close together face each other', () {
    for (final level in levels) {
      for (var i = 0; i < level.fires.length; i++) {
        for (var j = i + 1; j < level.fires.length; j++) {
          final a = level.fires[i];
          final b = level.fires[j];
          if (a.surface == b.surface) continue;
          expect((a.x - b.x).abs(), greaterThanOrEqualTo(kOppositeFireGap),
              reason: 'level ${level.id} could light both surfaces at once '
                  'around ${a.x}');
        }
      }
    }
  });

  test('obstacles never stack on top of each other', () {
    for (final level in levels) {
      final positions = <double>[
        ...level.bolted.map((e) => e.x),
        ...level.hoppers.map((e) => e.x),
        ...level.blades.map((e) => e.x),
        ...level.stones.map((e) => e.x),
        ...level.fires.map((e) => e.x),
      ]..sort();

      for (var i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1], greaterThanOrEqualTo(60),
            reason: 'level ${level.id} stacks obstacles at ${positions[i]}');
      }
    }
  });

  test('the hop period tightens once the pack gets going', () {
    for (final level in levels) {
      expect(level.hopPeriod, level.id <= 8 ? 2.0 : 1.75,
          reason: 'level ${level.id} is off the hop period curve');
    }
  });

  test('obstacles stay readable at the level speed', () {
    // Every obstacle must be on screen for at least 1.5 seconds before it is
    // reached, so nothing is a surprise the player cannot see coming.
    const visibleAhead = kCanvasWidth - kPlayerScreenX;
    for (final level in levels) {
      final lead = visibleAhead / level.runSpeed;
      expect(lead, greaterThanOrEqualTo(1.5),
          reason: 'level ${level.id} runs too fast for its camera lead');
    }
  });
}
