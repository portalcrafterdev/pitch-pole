import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchpole/game/logic/level_generator.dart';
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

/// A spread of levels across the whole pack.
///
/// Solving a level costs seconds, and there are fifteen hundred of them, so
/// the suite solves a representative sample rather than all of it. Every level
/// *is* solved before it ships — that happens in `tool/generate_levels.dart`,
/// across isolates, at authoring time. This is the regression net, not the
/// authoring gate.
List<LevelModel> sampleOf(List<LevelModel> levels, int count) {
  final generated =
      levels.where((l) => l.id >= kFirstGeneratedLevel).toList(growable: false);
  if (generated.isEmpty) return const [];
  return [
    for (var i = 0; i < count; i++)
      generated[(generated.length - 1) * i ~/ (count - 1)],
  ];
}

void main() {
  final levels = loadLevels();
  final handPlaced =
      levels.where((l) => l.id < kFirstGeneratedLevel).toList(growable: false);

  test('the level pack is not empty', () {
    expect(levels, isNotEmpty);
  });

  test('level ids are unique and consecutive from 1', () {
    expect(levels.map((l) => l.id).toList(),
        List.generate(levels.length, (i) => i + 1));
  });

  test('the pack is the full fifteen hundred', () {
    expect(levels.length, kTotalLevels);
  });

  // --- rules that hold for every level, checked without solving -------------

  test('every level obeys every structural rule', () {
    for (final level in levels) {
      final result = validateLevel(level, solve: false);
      expect(result.ok, isTrue, reason: result.toString());
    }
  });

  test('every level is 30 seconds of running', () {
    for (final level in levels) {
      expect(level.seconds, closeTo(kLevelSeconds, 0.001),
          reason: 'level ${level.id}');
    }
  });

  test('checkpoints land every 2000 units', () {
    for (final level in levels) {
      expect(level.checkpoints, isNotEmpty, reason: 'level ${level.id}');
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

  test('obstacles never stack on top of each other', () {
    for (final level in levels) {
      final xs = level.obstacleXs;
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], greaterThanOrEqualTo(kMinObstacleGap),
            reason: 'level ${level.id} stacks obstacles at ${xs[i]}');
      }
    }
  });

  test('no level leaves the player with nothing to do', () {
    for (final level in levels) {
      expect(pacingProblems(level), isEmpty,
          reason: 'level ${level.id} has dead track');
    }
  });

  test('obstacles stay readable at the level speed', () {
    // Every obstacle must be on screen for at least 1.5 seconds before it is
    // reached, so nothing is a surprise the player cannot see coming. This is
    // what caps the top speed of the pack.
    const visibleAhead = kCanvasWidth - kPlayerScreenX;
    for (final level in levels) {
      expect(visibleAhead / level.runSpeed, greaterThanOrEqualTo(1.5),
          reason: 'level ${level.id} runs too fast for its camera lead');
    }
  });

  test('moving obstacles are readable and never sprint', () {
    for (final level in levels) {
      for (final blade in level.blades) {
        expect(blade.period, greaterThanOrEqualTo(kMinBladePeriod),
            reason: 'level ${level.id} has a blade too fast to read');
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
      }
      for (final spider in level.spiders) {
        expect(spider.period,
            greaterThan(kSpiderCycleTime + kMinSpiderClearTime),
            reason: 'level ${level.id} has a spider that never lets the '
                'ceiling open');
      }
    }
  });

  test('a bat always has room to be flipped around', () {
    for (final level in levels) {
      for (final bat in level.bats) {
        for (final x in level.obstacleXs) {
          if (x == bat.x) continue;
          expect((x - bat.x).abs(), greaterThanOrEqualTo(kBatCommitGap),
              reason: 'level ${level.id}: a bat at ${bat.x} leaves no room to '
                  'commit before the obstacle at $x');
        }
      }
    }
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

  test('every level has coins to collect', () {
    for (final level in levels) {
      expect(level.coins, isNotEmpty, reason: 'level ${level.id} has none');
    }
  });

  test('coins are sorted by x', () {
    // The collection loop stops at the first coin beyond reach, which is only
    // correct if they are in order.
    for (final level in levels) {
      for (var i = 1; i < level.coins.length; i++) {
        expect(level.coins[i].x, greaterThanOrEqualTo(level.coins[i - 1].x),
            reason: 'level ${level.id} has coins out of order');
      }
    }
  });

  test('coins sit inside the level and inside the band', () {
    for (final level in levels) {
      for (final coin in level.coins) {
        expect(coin.x, greaterThan(0));
        expect(coin.x, lessThan(level.length));
        // Placed on the line the character actually ran, so they can never be
        // outside the band it is clamped to.
        expect(coin.y - kCoinSize / 2,
            greaterThanOrEqualTo(kCeilingSurfaceY - kCoinSize));
        expect(coin.y + kCoinSize / 2,
            lessThanOrEqualTo(kFloorSurfaceY + kCoinSize));
      }
    }
  });

  test('coins keep clear of obstacles', () {
    // A row of coins is a hint about where to run, so one sitting on top of a
    // blade would be actively misleading.
    for (final level in levels) {
      for (final coin in level.coins) {
        for (final x in level.obstacleXs) {
          expect((x - coin.x).abs(), greaterThanOrEqualTo(kCoinObstacleGap),
              reason: 'level ${level.id}: a coin at ${coin.x} is on top of '
                  'the obstacle at $x');
        }
      }
    }
  });

  test('coins are not counted as obstacles', () {
    // They neither block nor kill, so letting them satisfy the no dead track
    // rule would let a level fill its quiet stretches with free money.
    for (final level in levels.take(50)) {
      expect(level.obstacleXs.length, level.obstacleCount);
    }
  });

  // --- the shape of the pack ------------------------------------------------

  test('difficulty never goes backwards', () {
    var speed = 0.0;
    var hop = double.infinity;
    for (final level in levels) {
      expect(level.runSpeed, greaterThanOrEqualTo(speed),
          reason: 'level ${level.id} is slower than the one before it');
      expect(level.hopPeriod, lessThanOrEqualTo(hop),
          reason: 'level ${level.id} hops slower than the one before it');
      speed = level.runSpeed;
      hop = level.hopPeriod;
    }
  });

  test('the ramp packs more in as it goes', () {
    final first = levels[kFirstGeneratedLevel - 1];
    final last = levels[kRampEndLevel - 1];
    expect(last.obstacleCount, greaterThan(first.obstacleCount));
    expect(last.runSpeed, greaterThan(first.runSpeed));
    expect(last.hopPeriod, lessThan(first.hopPeriod));
  });

  test('difficulty holds at the ceiling once the ramp is over', () {
    // It has to stop somewhere: a 30 second level and a 60 unit minimum gap
    // put a hard cap on how much can be put in front of the player. Past the
    // ramp levels change what they ask for, not how much.
    final plateau = levels.where((l) => l.id > kRampEndLevel);
    for (final level in plateau) {
      expect(level.runSpeed, 280, reason: 'level ${level.id}');
      expect(level.hopPeriod, closeTo(1.0, 0.001), reason: 'level ${level.id}');
    }
  });

  test('the plateau keeps changing what it asks for', () {
    // Difficulty is flat past the ramp, so variety is the only thing keeping
    // levels apart. Check the archetypes actually get used.
    final used = <String>{
      for (var id = kRampEndLevel + 1; id <= kTotalLevels; id++)
        archetypeFor(id).name,
    };
    expect(used.length, kArchetypes.length,
        reason: 'every archetype should show up somewhere past the ramp');
  });

  test('no level ever drops a type the player has already met', () {
    // A level missing something already taught reads as a different, emptier
    // game than the one before it. The five originals appear everywhere; the
    // two animals appear from their own introduction onwards.
    for (final level in levels) {
      expect(level.bolted, isNotEmpty, reason: 'level ${level.id}: no bolted');
      expect(level.hoppers, isNotEmpty, reason: 'level ${level.id}: no hopper');
      expect(level.blades, isNotEmpty, reason: 'level ${level.id}: no blade');
      expect(level.stones, isNotEmpty, reason: 'level ${level.id}: no stone');
      expect(level.fires, isNotEmpty, reason: 'level ${level.id}: no fire');

      if (level.id >= kBatIntroLevel) {
        expect(level.bats, isNotEmpty, reason: 'level ${level.id}: no bat');
      }
      if (level.id >= kSpiderIntroLevel) {
        expect(level.spiders, isNotEmpty,
            reason: 'level ${level.id}: no spider');
      }
    }
  });

  test('the two animals wait until the player has learned the basics', () {
    for (final level in handPlaced) {
      expect(level.bats, isEmpty,
          reason: 'level ${level.id} teaches the original five');
      expect(level.spiders, isEmpty, reason: 'level ${level.id}');
    }
    expect(levels[kBatIntroLevel - 1].bats, isNotEmpty,
        reason: 'the bat gets a level of its own to be met in');
    expect(levels[kSpiderIntroLevel - 1].spiders, isNotEmpty);
  });

  test('generating a level twice gives exactly the same level', () {
    // The pack is committed data, so a rebuild has to be a no-op. If this ever
    // fails, `dart run tool/generate_levels.dart` would churn the asset.
    for (final id in [kFirstGeneratedLevel, 500, 1000, kTotalLevels]) {
      expect(
        jsonEncode(generateLevel(id).toJson()),
        jsonEncode(generateLevel(id).toJson()),
      );
    }
  });

  test('the committed pack matches what the generator produces', () {
    // Coins are laid in a second pass, along the route the solver finds, so
    // they are compared separately below rather than here.
    for (final id in [kFirstGeneratedLevel, 137, 742, kTotalLevels]) {
      expect(
        jsonEncode(levels[id - 1].withCoins(const []).toJson()),
        jsonEncode(generateLevel(id).toJson()),
        reason: 'level $id on disk has drifted from the generator',
      );
    }
  });

  test('the committed coins match the route the solver finds', () {
    // The expensive half of the check above: solve the level again and lay
    // coins the same way the authoring tool did. Two levels only, because
    // each one costs a full solve.
    for (final id in [kFirstGeneratedLevel, 742]) {
      final level = levels[id - 1];
      final plan = solveLevel(level.withCoins(const []));
      expect(plan, isNotNull, reason: 'level $id should still be solvable');

      expect(
        jsonEncode(coinsAlong(level, plan!).map((c) => c.toJson()).toList()),
        jsonEncode(level.coins.map((c) => c.toJson()).toList()),
        reason: 'level $id coins have drifted from the generator',
      );
    }
  });

  // --- the hand placed levels keep their stricter promises ------------------

  group('the hand placed levels', () {
    test('there are five of them, one per obstacle type', () {
      expect(handPlaced.length, kFirstGeneratedLevel - 1);
    });

    test('every one has all five of the original kinds', () {
      for (final level in handPlaced) {
        expect(level.bolted, isNotEmpty, reason: 'level ${level.id}');
        expect(level.hoppers, isNotEmpty, reason: 'level ${level.id}');
        expect(level.blades, isNotEmpty, reason: 'level ${level.id}');
        expect(level.stones, isNotEmpty, reason: 'level ${level.id}');
        expect(level.fires, isNotEmpty, reason: 'level ${level.id}');
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
        for (final level in handPlaced) {
          final count = entry.value(level);
          expect(count, greaterThanOrEqualTo(previous),
              reason: 'level ${level.id} has fewer ${entry.key} than the one '
                  'before it');
          previous = count;
        }
      }

      // Over five levels not every type has room to grow — several stay at
      // two throughout, which is the floor the dead track rule sets. What must
      // grow is the total.
      expect(handPlaced.last.obstacleCount,
          greaterThan(handPlaced.first.obstacleCount),
          reason: 'the taught levels should still get busier');
    });

    test('the hop period tightens once the pack gets going', () {
      for (final level in handPlaced) {
        expect(level.hopPeriod, level.id <= 8 ? 2.0 : 1.75,
            reason: 'level ${level.id} is off the hop period curve');
      }
    });

    test('level 1 introduces every type alone, one at a time', () {
      final first = handPlaced.first;
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
          reason: 'each type is met for the first time before anything '
              'repeats');

      // The camera shows this far ahead of the character, so a wider gap than
      // this means only one obstacle is ever on screen during introductions.
      const visibleAhead = kCanvasWidth - kPlayerScreenX;
      for (var i = 1; i < introductions.length; i++) {
        expect(
            introductions[i] - introductions[i - 1], greaterThan(visibleAhead),
            reason: 'two types would share the screen');
      }
    });

    test('bolted enemies keep their clearances', () {
      for (final level in handPlaced) {
        for (final enemy in level.bolted) {
          expect(enemy.x, greaterThanOrEqualTo(kBoltedClearance));
          expect(enemy.x, lessThanOrEqualTo(level.length - kBoltedClearance));
        }
      }
    });
  });

  // --- solving, on the twenty taught levels and a spread of the rest --------

  group('is completable', () {
    for (final level in [...handPlaced, ...sampleOf(levels, 12)]) {
      test('level ${level.id}', () {
        final result = validateLevel(level);
        expect(result.ok, isTrue, reason: result.toString());

        final end = runPlan(level, result.plan!);
        expect(end.status, RunStatus.won);
        expect(end.lives, kStartingLives,
            reason: 'the solver plan should not need to die');
      });
    }
  });
}
