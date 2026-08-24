// Authoring tool. Runs the headless simulator over levels from the committed
// pack and reports whether each is completable, along with the input sequence
// the solver found.
//
//   dart run tool/validate_levels.dart --from 1 --to 40
//   dart run tool/validate_levels.dart --from 6000 --to 6010 --verbose
//
// This is the single threaded, readable path: one level at a time, printing
// what it found. Solving costs about a second a level, so a range is required
// rather than defaulting to the whole pack — ten thousand of them here would
// take most of a day. Checking the *whole* pack is
// `tool/generate_levels.dart`, which does the same solve across isolates and
// refuses to write a pack where a single level fails.
//
// Exits non zero if any level in the range fails.

import 'dart:convert';
import 'dart:io';

import 'package:pitchpole/game/logic/level_generator.dart';
import 'package:pitchpole/game/logic/level_model.dart';
import 'package:pitchpole/game/logic/level_pack.dart';
import 'package:pitchpole/game/logic/level_simulator.dart';
import 'package:pitchpole/game/logic/physics.dart';

/// Reads levels [from] to [to] inclusive, touching only the shards they are in.
List<LevelModel> _read(int from, int to) {
  final levels = <LevelModel>[];
  for (var start = shardStartFor(from);
      start <= shardStartFor(to);
      start += kShardSize) {
    final file = File(shardPathAt(start));
    if (!file.existsSync()) continue;
    for (final entry in jsonDecode(file.readAsStringSync()) as List<dynamic>) {
      final level = LevelModel.fromJson(entry as Map<String, dynamic>);
      if (level.id >= from && level.id <= to) levels.add(level);
    }
  }
  levels.sort((a, b) => a.id.compareTo(b.id));
  return levels;
}

int _flag(List<String> args, String name, int fallback) {
  final at = args.indexOf('--$name');
  if (at < 0 || at + 1 >= args.length) return fallback;
  return int.parse(args[at + 1]);
}

void main(List<String> args) {
  final verbose = args.contains('--verbose');
  final from = _flag(args, 'from', 1);
  // Forty levels is a couple of minutes, which is about as long as anyone
  // watches a tool print lines before they stop reading them.
  final to = _flag(args, 'to', from + 39).clamp(from, kTotalLevels);

  final levels = _read(from, to);
  if (levels.isEmpty) {
    stderr.writeln('no levels in $from to $to — is the pack generated?');
    exit(1);
  }

  var failed = 0;
  final stopwatch = Stopwatch()..start();

  for (final level in levels) {
    final result = validateLevel(level);

    if (!result.ok) {
      stderr.writeln(result);
      failed++;
      continue;
    }

    final plan = result.plan!;
    stdout.writeln('Level ${level.id.toString().padLeft(5)}  '
        '${level.length.round().toString().padLeft(4)}u  '
        '${level.runSpeed.round()}/s  '
        'hop ${level.hopPeriod.toStringAsFixed(2)}  '
        '${archetypeFor(level.id).name.padRight(13)} '
        '${level.bolted.length}B ${level.hoppers.length}H '
        '${level.blades.length}K ${level.stones.length}S '
        '${level.fires.length}F ${level.bats.length}T '
        '${level.spiders.length}P  '
        '${plan.actions.toString().padLeft(2)} inputs');
    if (verbose) stdout.writeln('    $plan');
  }

  stopwatch.stop();
  stdout.writeln('\n${levels.length} levels checked '
      '(${levels.first.id} to ${levels.last.id}) '
      'in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
  stdout.writeln('hop air time ${kHopAirTime.toStringAsFixed(3)}s, '
      'hop peak ${kHopPeak.toStringAsFixed(1)}u, '
      'jump peak ${kJumpPeak.toStringAsFixed(1)}u');

  if (failed > 0) {
    stderr.writeln('$failed level(s) failed validation.');
    exit(1);
  }
}
